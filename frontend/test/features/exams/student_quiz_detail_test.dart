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

const _room = ClassRoom(
  id: 'class',
  section: 'Section',
  course: 'Course',
  instructor: 'Teacher',
  color: 0xFF236B57,
);

void main() {
  for (final mode in ['start', 'continue', 'unconnected']) {
    testWidgets('$mode handoff never creates or loads an attempt', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedQuizClass(db);
      final now = DateTime.now().toUtc();
      final session = mode == 'continue'
          ? ExamSession(
              sessionPayload()
                ..['deadline_at'] = now
                    .add(const Duration(minutes: 10))
                    .toIso8601String(),
            )
          : null;
      final quiz = quizFixture(
        session: session,
        opens: now.subtract(const Duration(minutes: 1)),
        closes: now.add(const Duration(hours: 1)),
      );
      final remote = FakeExamRemote()
        ..rows = [quiz.json]
        ..currentSession = session?.json;
      final repository = StudentExamRepository(
        store: ExamStore(db),
        remote: remote,
        isCurrent: () => true,
        online: () => true,
      );
      addTearDown(() async {
        repository.dispose();
        await db.close();
      });
      StudentExamHandoff? received;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentExamRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            studentQuizCatalogProvider.overrideWith(
              (ref) => Stream.value(StudentQuizCatalog([quiz], loaded: true)),
            ),
            studentQuizNowProvider.overrideWith((ref) => Stream.value(now)),
            classCardsProvider.overrideWith((ref) => Stream.value([_room])),
            classSyncProvider.overrideWith(_ClassSync.new),
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            connectivityMonitorProvider.overrideWithValue(_Connected()),
            if (mode != 'unconnected')
              studentExamHandoffProvider.overrideWithValue((request) async {
                received = request;
              }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const StudentQuizDetailScreen(
              classId: 'class',
              quizId: 'quiz',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(remote.calls, isEmpty);
      await tester.tap(find.byType(FiloButton));
      await tester.pumpAndSettle();
      if (mode == 'unconnected') {
        expect(received, isNull);
        expect(
          find.text(
            'The exam-taking screen is not available yet. No attempt was started.',
          ),
          findsOneWidget,
        );
      } else {
        expect(received?.quizId, 'quiz');
        expect(received?.sessionId, mode == 'continue' ? 'session' : null);
      }
      expect(
        remote.calls.any(
          (c) => c.startsWith('start:') || c.startsWith('exam:'),
        ),
        isFalse,
      );
      expect(await ExamStore(db).attempts(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('cached offline detail keeps information and disables Continue', (
    tester,
  ) async {
    final quiz = quizFixture(session: ExamSession(sessionPayload()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentQuizCatalogProvider.overrideWith(
            (ref) => Stream.value(StudentQuizCatalog([quiz], loaded: true)),
          ),
          studentQuizNowProvider.overrideWith((ref) => Stream.value(examEpoch)),
          classCardsProvider.overrideWith((ref) => Stream.value([_room])),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const StudentQuizDetailScreen(classId: 'class', quizId: 'quiz'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Read carefully.'), findsOneWidget);
    expect(find.text('Connect to the internet to continue.'), findsOneWidget);
    expect(
      tester.widget<FiloButton>(find.byType(FiloButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<FiloButton>(find.byType(FiloButton)).label,
      'Continue',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
