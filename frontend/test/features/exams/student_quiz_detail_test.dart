import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_button.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/exams/application/exam_providers.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/exams/presentation/student_exam_screen.dart';
import 'package:filo/features/exams/presentation/student_quiz_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is FiloButton && w.label == label);
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
  late FakeExamTime time;
  late StudentQuiz quiz;
  late _Routes routes;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedQuizClass(db);
    time = FakeExamTime();
    final now = DateTime.now().toUtc();
    quiz = quizFixture(
      opens: now.subtract(const Duration(minutes: 1)),
      closes: now.add(const Duration(hours: 1)),
    );
    remote = FakeExamRemote()..currentSession = null;
    repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      clock: time.clock,
      isCurrent: () => true,
      online: () => true,
    );
    routes = _Routes();
  });
  tearDown(() async {
    repository.dispose();
    await db.close();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool online = true,
    bool archived = false,
    bool failed = false,
  }) async {
    remote.rows = [quiz.json];
    remote.currentSession = quiz.session?.json;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentExamRepositoryProvider.overrideWith((ref) async => repository),
          studentQuizCatalogProvider.overrideWith(
            (ref) => Stream.value(
              StudentQuizCatalog([quiz], loaded: true, failed: failed),
            ),
          ),
          studentQuizNowProvider.overrideWith(
            (ref) => Stream.value(DateTime.now().toUtc()),
          ),
          classCardsProvider.overrideWith(
            (ref) => Stream.value([
              ClassRoom(
                id: 'class',
                section: 'Section',
                course: 'Course',
                instructor: 'Teacher',
                color: 0xFF236B57,
                archived: archived,
              ),
            ]),
          ),
          classSyncProvider.overrideWith(_ClassSync.new),
          connectivityProvider.overrideWith((ref) => Stream.value(online)),
          connectivityMonitorProvider.overrideWithValue(_Connected()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          navigatorObservers: [routes],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StudentQuizDetailScreen(
                        classId: 'class',
                        quizId: 'quiz',
                      ),
                    ),
                  ),
                  child: const Text('Open quiz'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open quiz'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets(
    'quiz opens details and confirmation together and back creates no attempt',
    (tester) async {
      await mount(tester);
      expect(find.text('Quiz details'), findsOneWidget);
      expect(find.text('Read carefully.'), findsOneWidget);
      expect(find.text('10 minutes'), findsOneWidget);
      expect(remote.calls, isEmpty);
      await _reveal(tester, _button('Start now'));
      expect(find.text('Before you start'), findsOneWidget);
      expect(tester.widget<FiloButton>(_button('Start now')).onPressed, isNull);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Leaving the app is recorded.'), findsNothing);
      expect(
        find.text('Screenshots and screen recording are blocked.'),
        findsNothing,
      );
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Open quiz'), findsOneWidget);
      expect(remote.calls, isEmpty);
      await unmount(tester);
    },
  );

  testWidgets('Start now opens questions in the same route after consent', (
    tester,
  ) async {
    await mount(tester);
    await _reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    await _reveal(tester, _button('Start now'));
    final before = routes.pushes;
    await tester.tap(_button('Start now'));
    await tester.pumpAndSettle();
    expect(routes.pushes, before);
    expect(find.byType(StudentExamScreen), findsOneWidget);
    expect(find.text('Time left: 10:00'), findsOneWidget);
    expect(find.text('Name').hitTestable(), findsOneWidget);
    expect(remote.calls.where((c) => c == 'start:quiz'), hasLength(1));
    expect(find.text('Before you start'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
    'Continue uses existing session without consent or another route',
    (tester) async {
      final now = DateTime.now().toUtc();
      final session = ExamSession(
        sessionPayload()
          ..['deadline_at'] = now
              .add(const Duration(minutes: 10))
              .toIso8601String(),
      );
      quiz = StudentQuiz(quiz.json, session);
      await mount(tester);
      expect(find.text('I understand'), findsNothing);
      await _reveal(tester, _button('Continue'));
      final before = routes.pushes;
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(routes.pushes, before);
      expect(remote.calls, isNot(contains('start:quiz')));
      expect(remote.calls, contains('exam:session'));
      expect(find.text('Time left: 10:00'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'offline overview keeps cached details and disables Continue without idle retry',
    (tester) async {
      final now = DateTime.now().toUtc();
      quiz = StudentQuiz(
        quiz.json,
        ExamSession(
          sessionPayload()
            ..['deadline_at'] = now
                .add(const Duration(minutes: 10))
                .toIso8601String(),
        ),
      );
      await mount(tester, online: false);
      expect(find.text('Read carefully.'), findsOneWidget);
      await _reveal(tester, _button('Continue'));
      expect(find.text('Connect to the internet to continue.'), findsOneWidget);
      expect(tester.widget<FiloButton>(_button('Continue')).onPressed, isNull);
      expect(find.text('Try again'), findsNothing);
      expect(remote.calls, isEmpty);
      await unmount(tester);
    },
  );

  testWidgets('archived details keep disabled Start without consent', (
    tester,
  ) async {
    await mount(tester, archived: true);
    await _reveal(tester, find.text('This class is archived.'));
    expect(find.text('I understand'), findsNothing);
    await _reveal(tester, _button('Start now'));
    expect(tester.widget<FiloButton>(_button('Start now')).onPressed, isNull);
    expect(find.text('Try again'), findsNothing);
    expect(remote.calls, isEmpty);
    await unmount(tester);
  });

  for (final state in ['upcoming', 'closed', 'submitted', 'offline']) {
    testWidgets('$state overview keeps disabled Start and reason', (
      tester,
    ) async {
      final now = DateTime.now().toUtc();
      if (state == 'upcoming') {
        quiz = quizFixture(
          opens: now.add(const Duration(hours: 1)),
          closes: now.add(const Duration(hours: 2)),
        );
      } else if (state == 'closed') {
        quiz = quizFixture(
          opens: now.subtract(const Duration(hours: 2)),
          closes: now.subtract(const Duration(hours: 1)),
        );
      } else if (state == 'submitted') {
        quiz = StudentQuiz(quiz.json, ExamSession(sessionPayload('submitted')));
      }
      await mount(tester, online: state != 'offline');
      await _reveal(tester, _button('Start now'));
      expect(tester.widget<FiloButton>(_button('Start now')).onPressed, isNull);
      expect(
        find.textContaining(switch (state) {
          'upcoming' => 'This quiz opens on',
          'closed' => 'This quiz has closed.',
          'submitted' => 'You have already taken this quiz.',
          _ => 'Connect to the internet to start.',
        }),
        findsOneWidget,
      );
      expect(remote.calls, isEmpty);
      await unmount(tester);
    });
  }

  testWidgets('failed metadata refresh retains a relevant recovery action', (
    tester,
  ) async {
    await mount(tester, failed: true);
    await _reveal(tester, find.text('Try again'));
    expect(find.text('Refresh to check your exam status.'), findsOneWidget);
    expect(tester.widget<FiloButton>(_button('Start now')).onPressed, isNull);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(remote.calls, isNot(contains('start:quiz')));
    await unmount(tester);
  });
}
