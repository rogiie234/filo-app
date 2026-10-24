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
import 'package:flutter/services.dart';
import 'package:filo/features/exams/presentation/exam_question_card.dart';
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
    Stream<Duration>? countdown,
    ThemeData? theme,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (countdown != null)
            examCountdownProvider.overrideWith((ref) => countdown),
          studentExamRepositoryProvider.overrideWith((ref) async {
            ref.onDispose(repository.dispose);
            return repository;
          }),
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
          theme: theme ?? AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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

  testWidgets(
    'rapid answer callbacks leave Saving only after latest revisions are confirmed',
    (tester) async {
      remote.currentSession = sessionPayload();
      remote.payload = examPayload()
        ..['questions'] = List.generate(
          50,
          (i) => {
            'id': 'rapid-$i',
            'type': 'true_false',
            'prompt': 'Rapid $i',
            'points': 1,
            'options': null,
          },
        );
      final entered = Completer<void>(), release = Completer<void>();
      remote.onSave = (_) async {
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
      };
      await mount(tester, sessionId: 'session');
      final answer = tester
          .widget<ExamQuestionCard>(find.byType(ExamQuestionCard).first)
          .onChanged;
      answer(const ExamAnswer(questionId: 'rapid-0', boolean: true));
      await tester.pumpAndSettle();
      expect(entered.isCompleted, isTrue);
      for (var i = 1; i < 50; i++) {
        answer(ExamAnswer(questionId: 'rapid-$i', boolean: true));
      }
      answer(const ExamAnswer(questionId: 'rapid-0', boolean: false));
      await tester.pumpAndSettle();
      expect(find.text('Saving...'), findsOneWidget);
      release.complete();
      await repository.saver!.flush();
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('50 of 50 answered'), findsOneWidget);
      expect(await repository.saver!.allSent(), isTrue);
      await unmount(tester);
    },
  );

  testWidgets('all four question types retain answers in server order', (
    tester,
  ) async {
    remote.currentSession = sessionPayload();
    await mount(tester, sessionId: 'session');
    Finder card(String id) => find.byKey(ValueKey('session:$id'));
    Finder field(String id) =>
        find.descendant(of: card(id), matching: find.byType(TextField));
    await tester.enterText(field('q'), 'Identification');
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('False'));
    await tester.tap(find.text('False'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('One'));
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    await _reveal(tester, field('essay'));
    await tester.enterText(field('essay'), 'First line\nSecond line');
    await tester.pumpAndSettle();
    expect(find.text('4 of 4 answered'), findsOneWidget);
    final answers = {
      for (final saved in await repository.answers())
        saved.answer.questionId: saved.answer,
    };
    expect(answers['q']!.text, 'Identification');
    expect(answers['bool']!.boolean, isFalse);
    expect(answers['choice']!.optionId, 'other');
    expect(answers['essay']!.text, 'First line\nSecond line');
    expect(repository.active!.questions.map((q) => q.id), [
      'q',
      'bool',
      'choice',
      'essay',
    ]);
    expect(
      tester.widget<TextField>(field('essay')).enableInteractiveSelection,
      isFalse,
    );
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(Mascot), findsNothing);
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'timer thresholds announce once without rebuilding questions, dark=$dark',
      (tester) async {
        remote.currentSession = sessionPayload();
        final countdown = StreamController<Duration>();
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              (message) async {
                if (message['type'] == 'announce') {
                  announcements.add(message['data']['message'] as String);
                }
                return null;
              },
            );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<dynamic>(
                SystemChannels.accessibility,
                null,
              );
        });
        await mount(
          tester,
          sessionId: 'session',
          countdown: countdown.stream,
          theme: dark
              ? ThemeData(brightness: Brightness.dark, fontFamily: 'Nunito')
              : null,
          textScale: 1.3,
        );
        final original = tester.widget<ExamQuestionCard>(
          find.byType(ExamQuestionCard).first,
        );
        countdown.add(const Duration(minutes: 4, seconds: 59));
        await tester.pumpAndSettle();
        expect(find.text('Less than 5 minutes left'), findsOneWidget);
        final amber = tester
            .widget<ColoredBox>(find.byKey(const ValueKey('exam-status-bar')))
            .color;
        countdown.add(const Duration(minutes: 4, seconds: 58));
        await tester.pumpAndSettle();
        expect(
          identical(
            original,
            tester.widget<ExamQuestionCard>(
              find.byType(ExamQuestionCard).first,
            ),
          ),
          isTrue,
        );
        countdown.add(const Duration(seconds: 59));
        await tester.pumpAndSettle();
        expect(find.text('Less than 1 minute left'), findsOneWidget);
        expect(
          tester
              .widget<ColoredBox>(find.byKey(const ValueKey('exam-status-bar')))
              .color,
          isNot(amber),
        );
        countdown.add(const Duration(seconds: 58));
        await tester.pumpAndSettle();
        countdown.add(const Duration(minutes: 2));
        await tester.pumpAndSettle();
        expect(announcements, [
          'Less than 5 minutes left',
          'Less than 1 minute left',
        ]);
        expect(find.byType(Mascot), findsNothing);
        expect(tester.takeException(), isNull);
        // Deliver done while the provider subscription is still active.
        final closed = countdown.close();
        await tester.pumpAndSettle();
        await closed;
        await unmount(tester);
      },
    );
  }

  testWidgets(
    '50 questions build lazily and preserve text and focus at 130 percent',
    (tester) async {
      remote.currentSession = sessionPayload();
      remote.payload = examPayload()
        ..['questions'] = List.generate(
          50,
          (index) => {
            'id': 'long-$index',
            'type': index.isEven ? 'identification' : 'essay',
            'prompt': 'Prompt $index',
            'points': 1,
            'options': null,
          },
        );
      await mount(tester, sessionId: 'session', textScale: 1.3);
      expect(find.byType(ExamQuestionCard).evaluate().length, lessThan(50));
      final first = find.descendant(
        of: find.byKey(const ValueKey('session:long-0')),
        matching: find.byType(TextField),
      );
      await tester.enterText(first, 'Keep this draft');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.descendant(of: first, matching: find.byType(EditableText)),
      );
      final focus = editable.focusNode;
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('exam-questions-session')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final last = find.byKey(const ValueKey('session:long-49'));
      // Drive the outer list; answer fields can consume synthetic drag gestures.
      for (var step = 0; step < 100 && last.evaluate().isEmpty; step++) {
        position.jumpTo(
          (position.pixels + position.viewportDimension * 0.8)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(last, findsOneWidget);
      expect(position.pixels, greaterThan(0));
      await tester.ensureVisible(last);
      expect(focus.hasFocus, isTrue);
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(first).controller!.text,
        'Keep this draft',
      );
      expect(
        (await repository.answers()).single.answer.text,
        'Keep this draft',
      );
      expect(tester.takeException(), isNull);
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
