import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/results/application/results_providers.dart';
import 'package:filo/features/results/domain/results.dart';
import 'package:filo/features/results/presentation/student_results_screen.dart';
import 'package:filo/features/results/presentation/instructor_results_screen.dart';
import 'package:filo/features/results/presentation/results_widgets.dart';
import 'package:filo/features/grading/domain/grading_models.dart';

ResultJson quizFixture() => {
  'id': 'quiz',
  'title': 'Quiz results',
  'class_id': 'class',
  'total_points': 10,
  'has_essay': false,
  'passing_percent': 70,
  'opens_at': '2020-01-01T00:00:00Z',
  'closes_at': '2099-01-01T00:00:00Z',
  'results_released_at': null,
};
ResultJson sessionFixture(
  String student,
  String status, {
  int score = 8,
  bool complete = true,
  int leaves = 0,
}) => {
  'id': 'session-$student',
  'quiz_id': 'quiz',
  'student_id': student,
  'profile': {'display_name': student},
  'status': status,
  'total_score': score,
  'grading_complete': complete,
  'attempt_no': 1,
  'leave_count': leaves,
};

void main() {
  testWidgets('blank essays show zero and graded essays show feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const ResultQuestionCard(
                  number: 1,
                  question: {
                    'type': 'essay',
                    'prompt': 'Blank',
                    'points': 5,
                    'your_answer': '   ',
                  },
                ),
                const ResultQuestionCard(
                  number: 2,
                  question: {
                    'type': 'essay',
                    'prompt': 'Answered',
                    'points': 5,
                    'your_answer': 'My explanation',
                    'points_awarded': 3,
                    'is_correct': null,
                    'feedback': 'Explain the last step.',
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('No answer'), findsOneWidget);
    expect(find.text('Points: 0/5'), findsOneWidget);
    expect(find.text('Not graded yet'), findsNothing);
    expect(find.text('Explain the last step.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'mixed totals exclude provisional, voided and unreleased student results',
    () {
      GradingData data({
        bool released = false,
        bool complete = true,
        String status = 'submitted',
      }) => GradingData(
        userId: 'student',
        assignments: [
          {'id': 'assignment', 'points': 10},
        ],
        submissions: [
          {
            'id': 'submission',
            'post_id': 'assignment',
            'student_id': 'student',
          },
        ],
        grades: [
          {
            'submission_id': 'submission',
            'score': 7,
            'returned_at': '2026-01-01T00:00:00Z',
          },
        ],
        quizzes: [
          {
            ...quizFixture(),
            'results_released_at': released ? '2026-01-01T00:00:00Z' : null,
          },
        ],
        quizAttempts: [sessionFixture('student', status, complete: complete)],
      );
      expect(data().total('student').earned, 15);
      expect(data().total('student').percent, 75);
      expect(data().total('student', returnedOnly: true).percent, 70);
      expect(
        data(released: true).total('student', returnedOnly: true).possible,
        20,
      );
      expect(data(complete: false).total('student').earned, 7);
      expect(data(status: 'voided').total('student').possible, 10);
    },
  );
  test(
    'monitor filters/sorts keep summaries and pending blank essay rules exact',
    () {
      final data = QuizMonitoring({
        'quiz': quizFixture(),
        'members': [
          for (final name in ['Ada', 'Ben', 'Cam'])
            {
              'student_id': name,
              'profile': {'display_name': name},
            },
        ],
        'sessions': [
          sessionFixture('Ada', 'submitted', leaves: 2),
          sessionFixture('Ben', 'in_progress', leaves: 5),
        ],
        'second_chances': [],
        'essay_answers': [
          {
            'session_id': 'session-Ada',
            'text_answer': '   ',
            'points_awarded': null,
          },
        ],
      });
      expect(data.submittedCount, 1);
      expect(data.inProgressCount, 1);
      expect(data.notStarted.length, 1);
      expect(data.average.points, 8);
      expect(data.pendingEssays, 0);
      expect(
        monitoringStudents(data, sort: 'Most leaves first').first['student_id'],
        'Ben',
      );
      expect(
        monitoringStudents(data, filter: 'Submitted').single['student_id'],
        'Ada',
      );
      expect(
        monitoringStudents(data, search: 'CAM').single['student_id'],
        'Cam',
      );
      expect(monitoringStudents(data, sort: 'Score').last['student_id'], 'Cam');
      expect(
        data.releaseBlocked(DateTime.now()),
        'Some students are still taking this quiz.',
      );
      expect(
        essayNeedsGrade({'text_answer': 'Answer', 'points_awarded': 0}),
        isFalse,
      );
      expect(
        essayNeedsGrade({'text_answer': 'Answer', 'points_awarded': null}),
        isTrue,
      );
      expect(
        overriddenMark({'graded_by': 'teacher', 'is_correct': false}),
        isTrue,
      );
    },
  );
  test('a failed or unavailable read is not a missed quiz', () {
    final missed = StudentResultData(
      {...quizFixture(), 'closes_at': '2020-01-01T00:00:00Z'},
      null,
      null,
    );
    expect(studentResultMessage(missed), 'You did not take this quiz.');
    expect(
      studentResultMessage(StudentResultData(quizFixture(), null, null)),
      resultsWaiting,
    );
    expect(
      const ResultsState<StudentResultData>(
        error: 'This item is no longer available.',
      ).data,
      isNull,
    );
  });

  testWidgets('released score-only result is readable offline at 130 percent', (
    tester,
  ) async {
    final data = StudentResultData(
      {...quizFixture(), 'results_released_at': '2026-01-01T00:00:00Z'},
      ResultSession({
        'session_id': 's',
        'status': 'submitted',
        'results_released': true,
      }),
      ReleasedResult(
        score: 7,
        totalPoints: 10,
        percent: 70,
        passed: true,
        review: null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
          studentResultProvider('quiz').overrideWith(
            (ref) => Stream.value(ResultsState(data: data, cached: true)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const StudentResultsScreen(quizId: 'quiz'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('7 of 10 points'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text(resultsScoreOnly), findsOneWidget);
    expect(find.text('Correct answer'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'instructor mixed roster shows summary and offline read-only rows',
    (tester) async {
      final data = QuizMonitoring({
        'quiz': quizFixture(),
        'members': [
          for (final name in ['Ada', 'Ben', 'Cam'])
            {
              'student_id': name,
              'profile': {'display_name': name},
            },
        ],
        'sessions': [
          sessionFixture('Ada', 'submitted'),
          sessionFixture('Ben', 'in_progress'),
        ],
        'second_chances': [],
        'essay_answers': [],
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
            quizMonitoringProvider('quiz').overrideWith(
              (ref) => Stream.value(
                ResultsState(data: data, cached: true, readOnly: true),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const InstructorResultsScreen(quizId: 'quiz'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('8 points'), findsOneWidget);
      expect(find.text('Results not released'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cam'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cam'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
