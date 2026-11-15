import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/assessment_form_screen.dart';
import 'package:filo/features/exams/presentation/student_quiz_detail_screen.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_screen.dart';
import 'package:filo/features/classes/presentation/classwork_list.dart';
import 'package:filo/features/classes/presentation/class_stream_assessments.dart';
import 'package:filo/features/exams/application/exam_providers.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/posts/application/post_providers.dart';
import 'package:filo/features/submissions/application/submission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(
  String id, {
  String status = 'published',
  String classId = 'class',
  String? published,
}) => {
  'id': id,
  'class_id': classId,
  'title': 'Assessment $id',
  'type': 'exam',
  'status': status,
  'total_points': 5,
  'time_limit_minutes': 10,
  'published_at': published ?? '2026-11-13T01:00:00Z',
  'created_at': '2026-11-10T00:00:00Z',
  'updated_at': '2026-11-14T00:00:00Z',
  'opens_at': '2026-11-13T02:00:00Z',
  'closes_at': '2026-11-13T03:00:00Z',
};
const room = ClassRoom(
  id: 'class',
  section: 'A',
  course: 'Course',
  instructor: 'Owner',
  color: 0,
);

class _RouteCapture extends NavigatorObserver {
  Route<dynamic>? pushed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed = route;
}

void main() {
  test('feed deduplicates namespaced IDs, hides drafts/deleted/foreign records and sorts by publication', () {
    final post = ClassPost(
      id: 'same',
      classId: 'class',
      title: 'Post',
      message: 'Body',
      createdAt: DateTime.utc(2026, 11, 12),
    );
    final items = classStreamItems(
      [post, post],
      [
        StreamAssessment(row('same')),
        StreamAssessment(row('same')),
        StreamAssessment(row('new', published: '2026-11-13T02:00:00Z')),
        StreamAssessment(row('draft', status: 'draft')),
        StreamAssessment({
          ...row('deleted'),
          'deleted_at': '2026-11-13T00:00:00Z',
        }),
        StreamAssessment(row('foreign', classId: 'other')),
      ],
      'class',
    );
    expect(items.map((e) => e.id), [
      'assessment:new',
      'assessment:same',
      'post:same',
    ]);
    final edited = StreamAssessment({
      ...row('same'),
      'updated_at': '2030-01-01T00:00:00Z',
      'title': 'Edited',
    });
    expect(
      classStreamItems(
        [post],
        [
          edited,
          StreamAssessment(row('new', published: '2026-11-13T02:00:00Z')),
        ],
        'class',
      ).first.id,
      'assessment:new',
    );
    expect(
      classStreamItems(
        [post],
        [edited],
        'class',
        filter: 'assessment',
      ).single.id,
      'assessment:same',
    );
    expect(
      classStreamItems([post], [edited], 'class', filter: 'material'),
      isEmpty,
    );
  });

  test(
    'status changes at schedule boundaries without exposing grading data',
    () {
      final assessment = StreamAssessment({
        ...row('q'),
        'answer_keys': 'PRIVATE',
        'total_score': 5,
      });
      expect(
        assessment.displayStatus(DateTime.utc(2026, 11, 13, 1)),
        'Scheduled',
      );
      expect(assessment.displayStatus(DateTime.utc(2026, 11, 13, 2)), 'Open');
      expect(assessment.displayStatus(DateTime.utc(2026, 11, 13, 3)), 'Closed');
    },
  );

  test('instructor cache remains available when refresh fails', () async {
    final container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        instructorQuizzesProvider('class').overrideWith(
          (ref) => Stream.value([InstructorQuizSummary(row('q'))]),
        ),
        instructorQuizListRefreshProvider('class')
            .overrideWith((ref) async => throw StateError('refresh failed')),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      assessmentStreamProvider((classId: 'class', student: false)),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(connectivityProvider.future);
    await container.read(instructorQuizzesProvider('class').future);
    await container.pump();
    await container.pump();
    final data = container.read(
      assessmentStreamProvider((classId: 'class', student: false)),
    );
    expect(data.items.map((e) => e.id), ['q']);
    expect(data.loaded, isTrue);
    expect(data.failed, isTrue);
  });

  for (final student in [true, false]) {
    testWidgets(
      'Stream links pass assessment identity to the existing role destination: student=$student',
      (tester) async {
        final observer = _RouteCapture();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: Scaffold(
              body: StreamAssessmentCard(
                assessment: StreamAssessment(row('q')),
                student: student,
                archived: !student,
              ),
            ),
          ),
        );
        await tester.tap(find.byType(ListTile));
        final route = observer.pushed! as MaterialPageRoute<void>;
        final destination = route.builder(
          tester.element(find.byType(StreamAssessmentCard)),
        );
        if (student) {
          expect(destination, isA<StudentQuizDetailScreen>());
          final detail = destination as StudentQuizDetailScreen;
          expect(detail.quizId, 'q');
          expect(detail.classId, 'class');
        } else {
          expect(destination, isA<AssessmentFormScreen>());
          final form = destination as AssessmentFormScreen;
          expect(form.quizId, 'q');
          expect(form.classId, 'class');
          expect(form.readOnly, isTrue);
        }
        // Inspect the route before mounting exam/grading network consumers.
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final student in [true, false]) {
    testWidgets(
      'assessment-only Stream is populated for student=$student and retains cards on refresh failure',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var feed = AssessmentStreamData([
          StreamAssessment({
            ...row('q'),
            'answer_keys': 'PRIVATE',
            'total_score': 5,
          }),
        ], loaded: true);
        final key = (classId: 'class', student: student);
        final container = ProviderContainer(
          overrides: [
            classSyncLifecycleProvider.overrideWith((ref) {}),
            classFileSnapshotsProvider.overrideWith((ref) => {}),
            classFilesProvider('class').overrideWith((ref) => Stream.value([])),
            postSyncLifecycleProvider('class').overrideWith((ref) {}),
            postSyncProvider('class').overrideWith((ref) async {}),
            streamLoadedProvider('class')
                .overrideWith((ref) => Stream.value(true)),
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
            classCardsProvider.overrideWith((ref) => Stream.value([room])),
            streamPostsProvider('class')
                .overrideWith((ref) => Stream.value([])),
            assessmentStreamProvider(key).overrideWith((ref) => feed),
            studentQuizCatalogProvider.overrideWith(
              (ref) => Stream.value(const StudentQuizCatalog([], loaded: true)),
            ),
            studentQuizNowProvider.overrideWith(
              (ref) => Stream.value(DateTime.utc(2026, 11, 13)),
            ),
            classworkLoadedProvider('submissions:class')
                .overrideWith((ref) => Stream.value(true)),
            classworkLoadedProvider('instructor_classwork_posts:class')
                .overrideWith((ref) => Stream.value(true)),
            submissionSyncLifecycleProvider('class').overrideWith((ref) {}),
            submissionSyncProvider('class').overrideWith((ref) async {}),
            classSubmissionsProvider('class')
                .overrideWith((ref) => Stream.value([])),
            returnedGradesProvider('class')
                .overrideWith((ref) => Stream.value([])),
            pendingClassRequestsProvider.overrideWith(
              (ref) => Stream.value({}),
            ),
            instructorQuizzesProvider('class')
                .overrideWith((ref) => Stream.value([])),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: FiloMotionScope(
                enabled: false,
                child: ClassScreen(
                  classId: 'class',
                  profile: AccountProfile.fromJson({
                    'id': 'user',
                    'role': student ? 'student' : 'instructor',
                    'display_name': 'User',
                  }),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StreamAssessmentCard), findsOneWidget);
        expect(find.text('No class updates yet'), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(find.text('Assessment q'), findsOneWidget);
        feed = AssessmentStreamData(feed.items, loaded: true, failed: true);
        container.invalidate(assessmentStreamProvider(key));
        await tester.pumpAndSettle();
        expect(find.byType(StreamAssessmentCard), findsOneWidget);
        expect(find.text('Class updates could not refresh'), findsOneWidget);
        final retry = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Retry').first,
        );
        expect(retry.onPressed, isNull);
        feed = const AssessmentStreamData([], loading: true);
        container.invalidate(assessmentStreamProvider(key));
        await tester.pumpAndSettle();
        expect(find.text('No class updates yet'), findsNothing);
        feed = AssessmentStreamData([StreamAssessment(row('q'))], loaded: true);
        container.invalidate(assessmentStreamProvider(key));
        await tester.pumpAndSettle();
        expect(find.byType(StreamAssessmentCard), findsOneWidget);
        expect(find.text('Class updates could not refresh'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
