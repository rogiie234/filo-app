import 'dart:async';

import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/instructor_classwork_list.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_screen.dart';
import 'package:filo/features/classes/presentation/classwork_list.dart';
import 'package:filo/features/exams/application/exam_providers.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/posts/application/post_providers.dart';
import 'package:filo/features/posts/presentation/stream_post_card.dart';
import 'package:filo/features/submissions/application/submission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reload extends Notifier<int> {
  @override
  int build() => 0;
  void reload() => state++;
}

final _reload = NotifierProvider<_Reload, int>(_Reload.new);
const _room = ClassRoom(
  id: 'class',
  section: 'Section',
  course: 'Course',
  instructor: 'Teacher',
  color: 0xFF236B57,
);
final _date = DateTime.utc(2026, 10, 23, 8);
final _posts = [
  for (var i = 1; i <= 10; i++)
    ClassPost(
      id: 'post$i',
      classId: 'class',
      title: 'Assignment $i',
      message: 'Instructions',
      assignment: true,
      createdAt: _date.subtract(Duration(days: i)),
      dueAt: _date.add(Duration(days: i)),
    ),
];
final _quizJson = <String, dynamic>{
  'id': 'quiz',
  'class_id': 'class',
  'title': 'Published quiz',
  'type': 'quiz',
  'status': 'published',
  'time_limit_minutes': 10,
  'total_points': 4,
  'created_at': _date.toIso8601String(),
  'opens_at': _date.toIso8601String(),
  'closes_at': _date.add(const Duration(hours: 1)).toIso8601String(),
};

void main() {
  for (final student in [true, false]) {
    testWidgets(
      '${student ? 'student' : 'instructor'} combined list waits for quizzes and retains rows across reload/error',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final firstQuiz = Completer<void>();
        final reloadGate = Completer<void>();
        final posts = StreamController<List<ClassPost>>.broadcast();
        addTearDown(posts.close);
        final gradeEvents = StreamController<List<CacheGrade>>.broadcast();
        addTearDown(gradeEvents.close);
        final container = ProviderContainer(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            streamPostsProvider('class').overrideWith((ref) async* {
              if (ref.watch(_reload) > 0) await reloadGate.future;
              yield _posts;
              yield* posts.stream;
            }),
            classworkLoadedProvider(
              '${student ? 'submissions' : 'instructor_classwork_posts'}:class',
            ).overrideWith((ref) => Stream.value(true)),
            postSyncProvider('class').overrideWith((ref) async {}),
            instructorAssignmentsRefreshProvider('class')
                .overrideWith((ref) async {}),
            instructorQuizListRefreshProvider('class')
                .overrideWith((ref) async {}),
            instructorQuizzesProvider('class').overrideWith((ref) async* {
              final generation = ref.watch(_reload);
              await (generation == 0 ? firstQuiz.future : reloadGate.future);
              yield [InstructorQuizSummary(_quizJson)];
            }),
            studentQuizCatalogProvider.overrideWith((ref) async* {
              final generation = ref.watch(_reload);
              await (generation == 0 ? firstQuiz.future : reloadGate.future);
              yield StudentQuizCatalog([
                StudentQuiz(_quizJson, null),
              ], loaded: true);
            }),
            studentQuizNowProvider.overrideWith((ref) => Stream.value(_date)),
            submissionSyncLifecycleProvider('class').overrideWith((ref) {}),
            submissionSyncProvider('class').overrideWith((ref) async {}),
            classSubmissionsProvider('class')
                .overrideWith((ref) => Stream.value([])),
            returnedGradesProvider('class').overrideWith((ref) async* {
              yield <CacheGrade>[];
              yield* gradeEvents.stream;
            }),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: student
                    ? ClassworkList(
                        classId: 'class',
                        instructor: false,
                        live: true,
                        previewPosts: const [],
                        onOpen: (_) {},
                      )
                    : const InstructorClassworkList(
                        classId: 'class',
                        archived: false,
                        active: true,
                      ),
              ),
            ),
          ),
        );
        // The deliberately pending source keeps the skeleton animating.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Assignment 1'), findsNothing);
        expect(find.byType(StreamPostSkeleton), findsWidgets);
        // An assignment-only filter must not wait for quiz hydration.
        if (!student) {
          await tester.tap(find.widgetWithText(ChoiceChip, 'Assignments'));
          await tester.pumpAndSettle();
          expect(find.text('Assignment 1'), findsOneWidget);
          await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('Assignment 1'), findsNothing);
        }
        firstQuiz.complete();
        await tester.pumpAndSettle();
        if (student) {
          await tester.tap(find.widgetWithText(ChoiceChip, 'To do'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Published quiz'), findsOneWidget);
        expect(find.text('Assignment 1'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        final before = position.pixels;
        expect(before, greaterThan(0));
        container.read(_reload.notifier).reload();
        await tester.pump();
        await tester.pump();
        expect(find.text('Published quiz'), findsOneWidget);
        expect(find.text('Assignment 1'), findsOneWidget);
        expect(position.pixels, before);
        reloadGate.complete();
        await tester.pumpAndSettle();
        if (student) gradeEvents.addError(StateError('status refresh failed'));
        posts.addError(StateError('refresh failed'));
        await tester.pumpAndSettle();
        expect(find.text('Published quiz'), findsOneWidget);
        expect(find.text('Assignment 1'), findsOneWidget);
        posts.add(_posts.where((p) => p.id != 'post1').toList());
        await tester.pumpAndSettle();
        expect(find.text('Assignment 1'), findsNothing);
        expect(find.text('Published quiz'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Stream retains posts during reload and removes content after confirmed class access loss',
    (tester) async {
      final reloadGate = Completer<void>();
      final cards = StreamController<List<ClassRoom>>.broadcast();
      addTearDown(cards.close);
      final container = ProviderContainer(
        overrides: [
          classSyncLifecycleProvider.overrideWith((ref) {}),
          classFilesProvider('class').overrideWith((ref) => Stream.value([])),
          postSyncLifecycleProvider('class').overrideWith((ref) {}),
          postSyncProvider('class').overrideWith((ref) async {}),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          classCardsProvider.overrideWith((ref) async* {
            yield [_room];
            yield* cards.stream;
          }),
          streamPostsProvider('class').overrideWith((ref) async* {
            if (ref.watch(_reload) > 0) await reloadGate.future;
            yield _posts;
          }),
          studentQuizCatalogProvider.overrideWith(
            (ref) => Stream.value(const StudentQuizCatalog([], loaded: true)),
          ),
          studentQuizNowProvider.overrideWith((ref) => Stream.value(_date)),
          classworkLoadedProvider('submissions:class')
              .overrideWith((ref) => Stream.value(true)),
          submissionSyncLifecycleProvider('class').overrideWith((ref) {}),
          submissionSyncProvider('class').overrideWith((ref) async {}),
          classSubmissionsProvider('class')
              .overrideWith((ref) => Stream.value([])),
          returnedGradesProvider('class')
              .overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: ClassScreen(
              classId: 'class',
              profile: AccountProfile.fromJson({
                'id': 'student',
                'role': 'student',
                'display_name': 'Student',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assignment 1'), findsOneWidget);
      container.read(_reload.notifier).reload();
      await tester.pump();
      await tester.pump();
      expect(find.text('Assignment 1'), findsOneWidget);
      expect(find.text('No posts yet'), findsNothing);
      reloadGate.complete();
      await tester.pumpAndSettle();
      cards.add([]);
      await tester.pumpAndSettle();
      expect(container.read(classCardsProvider).value, isEmpty);
      expect(find.text('Class unavailable'), findsOneWidget);
      expect(find.text('Assignment 1'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
