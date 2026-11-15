import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/grading/domain/grading_models.dart';
import 'package:filo/features/grading/presentation/work_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const room = ClassRoom(
  id: 'math',
  section: 'A',
  course: 'Math',
  instructor: 'Owner',
  color: 0,
  schoolYear: '2026',
);
const other = ClassRoom(
  id: 'science',
  section: 'A',
  course: 'Science',
  instructor: 'Owner',
  color: 0,
);
final now = DateTime.utc(2026, 11, 13, 12);
Map<String, dynamic> quiz(
  String id, {
  String status = 'published',
  Object? released,
  String? opens,
}) => {
  'id': id,
  'title': 'Activity 1',
  'type': 'exam',
  'status': status,
  'opens_at': opens ?? '2026-11-13T00:00:00Z',
  'results_released_at': released,
};
Map<String, dynamic> attempt(
  String id,
  String quizId, {
  String status = 'submitted',
  bool graded = true,
}) => {
  'id': id,
  'quiz_id': quizId,
  'student_id': id,
  'status': status,
  'attempt_no': 1,
  'leave_count': 0,
  'grading_complete': graded,
  'total_score': graded ? 5 : null,
  'submitted_at': '2026-11-13T01:00:00Z',
};

void main() {
  test(
    'only pending submissions survive; release blockers never count as ready',
    () {
      final data = GradingData(
        userId: 'owner',
        quizzes: [
          quiz('ready'),
          quiz('essay'),
          quiz('active'),
          quiz('future', opens: '2026-11-14T00:00:00Z'),
          quiz('released', released: '2026-11-13T02:00:00Z'),
          quiz('draft', status: 'draft'),
          {...quiz('deleted'), 'deleted_at': '2026-11-13T02:00:00Z'},
        ],
        quizAttempts: [
          attempt('one', 'ready'),
          attempt('void', 'ready', status: 'voided'),
          attempt('two', 'essay', graded: false),
          attempt('three', 'essay'),
          attempt('four', 'active'),
          attempt('five', 'active', status: 'in_progress'),
          attempt('six', 'future'),
          attempt('seven', 'released'),
          attempt('eight', 'draft'),
          attempt('nine', 'deleted'),
        ],
      );
      final rows = instructorReviewEntries(room, data, now);
      expect(rows, hasLength(5));
      expect(
        rows
            .where((e) => e.group == 'Ready to release')
            .map((e) => e.studentId),
        ['one'],
      );
      expect(rows.where((e) => e.group == 'To grade').map((e) => e.studentId), [
        'two',
      ]);
      final folders = reviewActivities(rows);
      expect(folders.singleWhere((f) => f.first.postId == 'essay').ready, 0);
      expect(
        folders.singleWhere((f) => f.first.postId == 'active').awaiting,
        1,
      );
      expect(
        folders.singleWhere((f) => f.first.postId == 'future').awaiting,
        1,
      );
    },
  );

  test('same titles, sections and assignment/quiz IDs remain separate; oldest work sorts first', () {
    final rows = [
      WorkQueueEntry(
        room,
        'same',
        'Activity 1',
        'To grade',
        'Turned in',
        time: now,
      ),
      WorkQueueEntry(
        room,
        'same',
        'Activity 1',
        'Graded, not returned',
        'Turned in',
        time: now,
      ),
      WorkQueueEntry(
        other,
        'same',
        'Activity 1',
        'To grade',
        'Turned in',
        time: now.subtract(const Duration(hours: 1)),
      ),
      WorkQueueEntry(
        room,
        'same',
        'Activity 1',
        'Ready to release',
        'Ready',
        type: WorkQueueItemType.quiz,
        time: now,
      ),
    ];
    final folders = reviewActivities(rows);
    expect(folders, hasLength(3));
    expect(folders.map((f) => f.id).toSet(), hasLength(3));
    expect(folders.first.first.room.id, 'science');
    final assignment = folders.singleWhere(
      (f) =>
          f.first.room.id == 'math' &&
          f.first.type == WorkQueueItemType.assignment,
    );
    expect(assignment.toGrade, 1);
    expect(assignment.ready, 1);
  });

  test(
    'returned assignment work and released attempts remove their folders',
    () {
      final data = GradingData(
        userId: 'owner',
        assignments: [
          {'id': 'post', 'title': 'Activity 1'},
        ],
        submissions: [
          {
            'id': 'sub',
            'post_id': 'post',
            'student_id': 'student',
            'status': 'turned_in',
            'submitted_at': now.toIso8601String(),
          },
        ],
        grades: [
          {'submission_id': 'sub', 'returned_at': now.toIso8601String()},
        ],
        quizzes: [quiz('q', released: now.toIso8601String())],
        quizAttempts: [attempt('attempt', 'q')],
      );
      expect(
        reviewActivities(instructorReviewEntries(room, data, now)),
        isEmpty,
      );
    },
  );

  testWidgets(
    'separate class folders, activity counts and badge reconcile together',
    (tester) async {
      var rows = [
        const WorkQueueEntry(
          room,
          'post',
          'Activity 1',
          'To grade',
          'Turned in',
        ),
        const WorkQueueEntry(
          room,
          'post',
          'Activity 1',
          'Graded, not returned',
          'Turned in',
        ),
        const WorkQueueEntry(
          other,
          'post',
          'Activity 1',
          'To grade',
          'Turned in',
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          workQueueProvider(false)
              .overrideWith((ref) => WorkQueueData(rows, false, false, true)),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const FiloMotionScope(
              enabled: false,
              child: Scaffold(
                body: WorkQueueScreen(student: false, embedded: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(reviewQueueCountProvider), 3);
      expect(find.text('Math / A'), findsOneWidget);
      expect(find.text('Science / A'), findsOneWidget);
      await tester.tap(find.text('Math / A'));
      await tester.pumpAndSettle();
      expect(find.text('Activity 1 / Assignment'), findsOneWidget);
      expect(find.text('1 to grade / 1 ready to return'), findsOneWidget);
      rows = [];
      container.invalidate(workQueueProvider(false));
      await tester.pumpAndSettle();
      expect(container.read(reviewQueueCountProvider), 0);
      expect(find.text('Math / A'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
