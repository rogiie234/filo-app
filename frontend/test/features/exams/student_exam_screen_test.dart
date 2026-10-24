import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/sync/sync_providers.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/drive_backup/data/drive_backup_service.dart';
import 'package:filo/features/home/presentation/home_screen.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/exams/application/exam_providers.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/exams/presentation/student_exam_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exam_test_support.dart';
import 'student_quiz_catalog_test.dart' show seedQuizClass;
import 'student_quiz_status_test.dart' show quizFixture;

class _Connected extends Fake implements ConnectivityMonitor {
  @override
  Future<bool> recheck() async => true;
}

class _ClassSync extends ClassSync {
  @override
  Future<void> refresh() async {}
}

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is FiloButton && widget.label == label,
);

final _examPopScope = find.byWidgetPredicate((widget) => widget is PopScope);
Future<void> _reveal(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void main() {
  late AppDatabase db;
  late FakeExamRemote remote;
  late StudentExamRepository repository;
  late StudentQuiz quiz;
  late FakeExamTime time;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedQuizClass(db);
    final now = DateTime.now().toUtc();
    quiz = quizFixture(
      opens: now.subtract(const Duration(minutes: 1)),
      closes: now.add(const Duration(hours: 1)),
    );
    remote = FakeExamRemote()
      ..currentSession = null
      ..rows = [quiz.json];
    time = FakeExamTime();
    repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      isCurrent: () => true,
      online: () => true,
      clock: time.clock,
    );
  });
  tearDown(() async {
    repository.dispose();
    await db.close();
  });

  Future<void> mount(
    WidgetTester tester, {
    String? sessionId,
    bool home = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentExamRepositoryProvider.overrideWith((ref) async => repository),
          studentQuizCatalogProvider.overrideWith(
            (ref) => Stream.value(StudentQuizCatalog([quiz], loaded: true)),
          ),
          studentQuizNowProvider.overrideWith(
            (ref) => Stream.value(DateTime.now().toUtc()),
          ),
          classCardsProvider.overrideWith(
            (ref) => Stream.value([
              const ClassRoom(
                id: 'class',
                section: 'Section',
                course: 'Course',
                instructor: 'Teacher',
                color: 0xFF236B57,
              ),
            ]),
          ),
          classSyncProvider.overrideWith(_ClassSync.new),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          connectivityMonitorProvider.overrideWithValue(_Connected()),
          if (home) classSyncLifecycleProvider.overrideWith((ref) {}),
          if (home) syncLifecycleProvider.overrideWith((ref) {}),
          if (home) driveBackupProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: home
              ? HomeScreen(
                  profile: AccountProfile.fromJson({
                    'id': 'student',
                    'role': 'student',
                    'display_name': 'Student',
                  }),
                )
              : StudentExamScreen(
                  request: StudentExamHandoff(
                    quizId: 'quiz',
                    sessionId: sessionId,
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets(
    'combined overview gates Start now, keeps three rules and hides irrelevant retry',
    (tester) async {
      await mount(tester);
      final button = _button('Start now');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<FiloButton>(button).onPressed, isNull);
      for (final rule in [
        'You have one attempt only.',
        "You can't go back to other screens during the exam.",
        'Have enough battery and mobile data or Wi-Fi.',
      ]) {
        expect(find.text(rule), findsOneWidget);
      }
      expect(find.byType(Mascot), findsNothing);
      expect(find.text('Leaving the app is recorded.'), findsNothing);
      expect(
        find.text('Screenshots and screen recording are blocked.'),
        findsNothing,
      );
      expect(find.text('Try again'), findsNothing);
      await _reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(tester.widget<FiloButton>(button).onPressed, isNotNull);
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(tester.widget<FiloButton>(button).onPressed, isNull);
      expect(remote.calls, isEmpty);
      await unmount(tester);
    },
  );

  testWidgets('duplicate taps share one start, show loading and block back', (
    tester,
  ) async {
    final response = Completer<ExamJson>();
    remote.onStart = () => response.future;
    await mount(tester);
    await _reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    final start = tester.widget<FiloButton>(_button('Start now')).onPressed!;
    start();
    start();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(remote.calls.where((c) => c == 'start:quiz'), hasLength(1));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<PopScope>(_examPopScope).canPop, isFalse);
    remote.currentSession = sessionPayload();
    response.complete({'id': 'session'});
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsNothing);
    expect(find.text('Time left: 10:00'), findsOneWidget);
    expect(
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop(),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(find.text("You can't leave an exam in progress."), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'Continue restores answers, skips warning, preserves draft on refresh',
    (tester) async {
      remote.currentSession = sessionPayload();
      remote.payload = examPayload(
        saved: [
          {'question_id': 'q', 'text_answer': 'Saved answer'},
        ],
      );
      await mount(tester, sessionId: 'session');
      expect(find.text('I understand'), findsNothing);
      expect(remote.calls, isNot(contains('start:quiz')));
      expect(
        find.text('Your exam has resumed with the time left.'),
        findsOneWidget,
      );
      final field = find.byType(TextField).first;
      expect(tester.widget<TextField>(field).controller!.text, 'Saved answer');
      await tester.enterText(field, 'My newest answer');
      await tester.pumpAndSettle();
      await repository.reconcile();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'My newest answer',
      );
      await unmount(tester);
    },
  );

  for (final error in {
    'This quiz has not opened yet': 'This quiz opens on ',
    'This quiz has closed': 'This quiz has closed.',
    'You have already taken this quiz': 'You have already taken this quiz.',
    'This class is archived': 'This class is archived.',
    'offline': 'Connect to the internet to start.',
  }.entries) {
    testWidgets('start refusal displays friendly ${error.key} copy', (
      tester,
    ) async {
      remote.onStart = () async {
        if (error.key == 'offline') throw const SocketException('network lost');
        throw PostgrestException(message: error.key, code: 'P0001');
      };
      await mount(tester);
      await _reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      final start = _button('Start now');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.textContaining(error.value), findsOneWidget);
      expect(repository.active, isNull);
      expect(remote.calls.where((c) => c == 'start:quiz'), hasLength(1));
      await unmount(tester);
    });
  }

  testWidgets(
    'blank-answer confirmation keeps answering primary and submits only after confirmation',
    (tester) async {
      remote.currentSession = sessionPayload();
      await mount(tester, sessionId: 'session');
      final submit = _button('Submit');
      await tester.scrollUntilVisible(
        submit,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text('You have 4 unanswered questions. Submit anyway?'),
        findsOneWidget,
      );
      expect(
        tester.widget<FiloButton>(_button('Keep answering')).secondary,
        isFalse,
      );
      expect(remote.calls, isNot(contains('submit:session')));
      await tester.tap(find.text('Keep answering'));
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit anyway'));
      await tester.pumpAndSettle();
      expect(remote.calls.where((c) => c == 'submit:session'), hasLength(1));
      expect(
        find.textContaining(
          'Your answers were submitted. Results will be available',
        ),
        findsOneWidget,
      );
      await unmount(tester);
    },
  );

  testWidgets(
    'deadline stops editing and never claims submission without confirmation',
    (tester) async {
      remote.currentSession = sessionPayload();
      await mount(tester, sessionId: 'session');
      remote.payload = examPayload()
        ..['server_now'] = examEpoch
            .add(const Duration(minutes: 11))
            .toIso8601String();
      time.elapsed = const Duration(minutes: 11);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.text("Time's up. Reconnect to check your submission."),
        findsOneWidget,
      );
      final answerField = find.descendant(
        of: find.byKey(const ValueKey('session:q')),
        matching: find.byType(TextField),
      );
      await tester.scrollUntilVisible(
        answerField,
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<TextField>(answerField).enabled, isFalse);
      expect(find.textContaining('Results will be available'), findsNothing);
      remote.currentSession = sessionPayload('auto_submitted');
      await repository.reconcile();
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Time's up. Your answers were submitted."),
        findsOneWidget,
      );
      expect(tester.widget<PopScope>(_examPopScope).canPop, isTrue);
      await unmount(tester);
    },
  );

  test('false is answered; whitespace and null are unanswered', () {
    expect(
      examAnswerPresent(const ExamAnswer(questionId: 'b', boolean: false)),
      isTrue,
    );
    expect(
      examAnswerPresent(const ExamAnswer(questionId: 'q', text: '   ')),
      isFalse,
    );
    expect(examAnswerPresent(null), isFalse);
  });

  testWidgets(
    'home recovery opens exactly one exam route without warning or start',
    (tester) async {
      remote.currentSession = sessionPayload();
      await mount(tester, home: true);
      expect(find.byType(StudentExamScreen), findsOneWidget);
      expect(find.text('I understand'), findsNothing);
      repository.notify();
      repository.notify();
      await tester.pumpAndSettle();
      expect(find.byType(StudentExamScreen), findsOneWidget);
      expect(remote.calls, isNot(contains('start:quiz')));
      await unmount(tester);
    },
  );
}
