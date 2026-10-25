import 'package:flutter_test/flutter_test.dart';
import 'package:filo/features/results/domain/results.dart';
import 'package:filo/features/results/data/results_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

ResultSession attempt({
  String id = 's',
  String student = 'student',
  String name = 'Ada',
  String status = 'submitted',
  bool graded = false,
  int? score = 7,
  int leaves = 0,
}) => ResultSession({
  'id': id,
  'student_id': student,
  'profile': {'display_name': name},
  'status': status,
  'grading_complete': graded,
  'total_score': score,
  'leave_count': leaves,
  'attempt_no': 1,
});

void main() {
  test('documented server refusals use friendly results copy', () {
    const messages = {
      'Some students are still taking this quiz':
          'Some students are still taking this quiz.',
      'Grade all essay answers first': 'Grade all essay answers first.',
      'This quiz has not opened yet': 'This quiz has not opened yet.',
      'This attempt is not submitted yet': 'This attempt is not submitted yet.',
      'Points must be between 0 and 5': 'Points must be between 0 and 5',
      'Please give a reason of at least 10 characters':
          'Please give a reason of at least 10 characters.',
      'This student has no attempt to reset':
          'This student has no attempt to reset.',
      'Extend the closing time first so the student can retake it':
          'Extend the closing time first so the student can retake it.',
      'Results are already released. Create a new quiz instead.':
          'Results are already released. Create a new quiz instead.',
    };
    for (final entry in messages.entries) {
      expect(
        resultsFailure(
          PostgrestException(message: entry.key),
          ResultsAction.grade,
        ).message,
        entry.value,
      );
    }
  });
  test('status precedence includes voided and auto-submitted attempts', () {
    expect(
      quizResultStatus(null, hasEssay: false),
      QuizResultStatus.notStarted,
    );
    expect(
      quizResultStatus(attempt(status: 'voided', graded: true), hasEssay: true),
      QuizResultStatus.notStarted,
    );
    expect(
      quizResultStatus(
        attempt(status: 'in_progress', graded: true),
        hasEssay: true,
      ),
      QuizResultStatus.inProgress,
    );
    for (final status in ['submitted', 'auto_submitted']) {
      expect(
        quizResultStatus(attempt(status: status), hasEssay: false),
        QuizResultStatus.submitted,
      );
      expect(
        quizResultStatus(attempt(status: status), hasEssay: true),
        QuizResultStatus.essayToGrade,
      );
      expect(
        quizResultStatus(attempt(status: status, graded: true), hasEssay: true),
        QuizResultStatus.graded,
      );
      expect(
        quizResultStatus(
          attempt(status: status, graded: true),
          hasEssay: false,
        ),
        QuizResultStatus.graded,
      );
    }
  });

  test('percentage matches SQL rounding and pass includes exact equality', () {
    expect(resultPercent(0, 0), 0);
    expect(resultPercent(0, 10), 0);
    expect(resultPercent(10, 10), 100);
    expect(resultPercent(1, 8), 13);
    expect(resultPercent(149, 200), 75);
    expect(resultPassed(resultPercent(149, 200), 75), isTrue);
    expect(resultPassed(resultPercent(148, 200), 75), isFalse);
    expect(resultPassed(resultPercent(150, 200), 75), isTrue);
    expect(resultPassed(75, 75), isTrue);
    expect(resultPassed(74, 75), isFalse);
    expect(resultPassed(76, 75), isTrue);
    expect(resultPassed(0, 0), isTrue);
    expect(resultPassed(100, null), isNull);
  });

  test(
    'student result preserves server percentage, pass, and hidden review',
    () {
      final result = ReleasedResult.fromJson({
        'score': 7,
        'total_points': 10,
        'percent': 70,
        'passed': null,
        'review': null,
      });
      expect(result.percent, 70);
      expect(result.passed, isNull);
      expect(result.review, isNull);
    },
  );

  test(
    'average excludes history and in-progress and includes confirmed zero',
    () {
      final average = submittedAverage([
        attempt(score: 0, graded: true),
        attempt(score: 10, status: 'auto_submitted'),
        attempt(score: 100, status: 'voided'),
        attempt(score: 100, status: 'in_progress'),
      ]);
      expect(average.points, 5);
      expect(average.provisional, isTrue);
      expect(submittedAverage([]).points, isNull);
      expect(submittedAverage([attempt(score: null)]).points, isNull);
      expect(submittedAverage([attempt(graded: true)]).provisional, isFalse);
    },
  );

  test('pending essays follow server awarded points and exclude blank or missing rows', () {
    final detail = AttemptDetail({
      'session': attempt().json,
      'quiz': {},
      'questions': [
        {'type': 'essay', 'answer': null},
        {
          'type': 'essay',
          'answer': {
            'points_awarded': 0,
            'graded_by': 'teacher',
            'is_correct': null,
          },
        },
        {
          'type': 'essay',
          'answer': {
            'text_answer': 'Answer',
            'points_awarded': null,
            'graded_by': null,
          },
        },
        {'type': 'multiple_choice', 'answer': null},
      ],
    });
    expect(detail.pendingEssays, 1);
    detail.json['session'] = attempt(graded: true).json;
    expect(detail.pendingEssays, 0);
  });

  test('most leaves first uses name then student ID for ties', () {
    final rows = [
      attempt(student: 'z', name: 'Zoe', leaves: 2),
      attempt(student: 'b', name: 'Ada', leaves: 2),
      attempt(student: 'a', name: 'Ada', leaves: 2),
      attempt(student: 'c', leaves: 3),
      attempt(student: 'd'),
    ];
    rows.sort(mostLeavesFirst);
    expect(rows.map((r) => r.studentId), ['c', 'a', 'b', 'z', 'd']);
  });

  test('roster summaries exclude voided and departed students', () {
    final data = QuizMonitoring({
      'quiz': {},
      'members': [
        {'student_id': 'active'},
        {'student_id': 'not-started'},
      ],
      'second_chances': [],
      'sessions': [
        attempt(student: 'active', score: 8).json,
        attempt(student: 'not-started', status: 'voided').json,
        attempt(student: 'departed', score: 100).json,
      ],
    });
    expect(data.notStarted.single['student_id'], 'not-started');
    expect(data.submittedCount, 1);
    expect(data.average.points, 8);
    expect(data.history.length, 1);
  });
}
