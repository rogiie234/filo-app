import 'package:flutter_test/flutter_test.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/exams/domain/student_quiz_status.dart';

import 'exam_test_support.dart';

StudentQuiz quizFixture({
  ExamSession? session,
  bool known = true,
  DateTime? opens,
  DateTime? closes,
}) => StudentQuiz(
  {
    'id': 'quiz',
    'class_id': 'class',
    'title': 'Quiz',
    'type': 'quiz',
    'instructions': 'Read carefully.',
    'time_limit_minutes': 10,
    'total_points': 4,
    'opens_at': (opens ?? examEpoch).toIso8601String(),
    'closes_at': (closes ?? examEpoch.add(const Duration(hours: 1)))
        .toIso8601String(),
  },
  session,
  sessionKnown: known,
);

void main() {
  test(
    'opening is inclusive, closing exclusive; unknown history is never missed',
    () {
      final quiz = quizFixture();
      expect(
        studentQuizState(
          quiz,
          examEpoch.subtract(const Duration(microseconds: 1)),
        ).status,
        StudentQuizStatus.upcoming,
      );
      expect(studentQuizState(quiz, examEpoch).status, StudentQuizStatus.open);
      final close = quiz.closesAt!;
      expect(studentQuizState(quiz, close).status, StudentQuizStatus.missed);
      expect(
        studentQuizState(quizFixture(known: false), close).status,
        StudentQuizStatus.closed,
      );
      expect(
        studentQuizDisabledReason(
          quizFixture(known: false),
          examEpoch,
          archived: false,
          online: true,
        ),
        'Refresh to check your exam status.',
      );
    },
  );

  test('submission wins over closing; expired unfinished attempt requires reconciliation', () {
    for (final status in ['submitted', 'auto_submitted']) {
      final quiz = quizFixture(session: ExamSession(sessionPayload(status)));
      expect(
        studentQuizState(quiz, examEpoch.add(const Duration(days: 1))).status,
        StudentQuizStatus.submitted,
      );
      expect(studentQuizGroup(quiz, examEpoch), 'Done');
    }
    final quiz = quizFixture(session: ExamSession(sessionPayload()));
    expect(studentQuizState(quiz, examEpoch).action, 'Continue');
    final expired = studentQuizState(quiz, quiz.session!.deadline);
    expect(expired.status, StudentQuizStatus.inProgress);
    expect(expired.pending, isTrue);
    expect(studentQuizGroup(quiz, examEpoch), isNot('Done'));
  });

  test('disabled reason precedence and offline Continue', () {
    final submitted = quizFixture(
      session: ExamSession(sessionPayload('submitted')),
    );
    final later = examEpoch.add(const Duration(days: 1));
    expect(
      studentQuizDisabledReason(
        submitted,
        later,
        archived: true,
        online: false,
      ),
      'This class is archived.',
    );
    expect(
      studentQuizDisabledReason(
        submitted,
        later,
        archived: false,
        online: false,
      ),
      'You have already taken this quiz.',
    );
    expect(
      studentQuizDisabledReason(
        quizFixture(),
        later,
        archived: false,
        online: false,
      ),
      'This quiz has closed.',
    );
    expect(
      studentQuizDisabledReason(
        quizFixture(),
        examEpoch.subtract(const Duration(days: 1)),
        archived: false,
        online: false,
      ),
      startsWith('This quiz opens on '),
    );
    expect(
      studentQuizDisabledReason(
        quizFixture(),
        examEpoch,
        archived: false,
        online: false,
      ),
      'Connect to the internet to start.',
    );
    expect(
      studentQuizDisabledReason(
        quizFixture(session: ExamSession(sessionPayload())),
        examEpoch,
        archived: false,
        online: false,
      ),
      'Connect to the internet to continue.',
    );
    expect(
      studentQuizDisabledReason(
        quizFixture(),
        examEpoch,
        archived: false,
        online: true,
      ),
      isNull,
    );
  });

  test('PHT conversion crosses dates and preserves the actual instant', () {
    expect(
      philippineQuizDate(DateTime.parse('2026-10-23T18:05:00Z')),
      '24 Oct 2026 at 2:05 AM',
    );
    expect(
      philippineQuizDate(DateTime.parse('2026-10-24T02:05:00+08:00')),
      philippineQuizDate(DateTime.parse('2026-10-23T18:05:00Z')),
    );
  });

  test('mixed deadlines sort with undated last and stable identity ties', () {
    final items = <({DateTime? date, String id})>[
      (date: null, id: 'post:none'),
      (date: examEpoch, id: 'quiz:b'),
      (date: examEpoch, id: 'post:a'),
    ]..sort((a, b) => compareStudentWork(a.date, a.id, b.date, b.id));
    expect(items.map((e) => e.id), ['post:a', 'quiz:b', 'post:none']);
  });

  test('unfinished quizzes use the assignment queue groups', () {
    final now = DateTime(2026, 10, 23, 12);
    expect(
      studentQuizGroup(
        quizFixture(closes: now.subtract(const Duration(seconds: 1))),
        now,
      ),
      'Overdue',
    );
    expect(
      studentQuizGroup(
        quizFixture(closes: now.add(const Duration(hours: 1))),
        now,
      ),
      'Today',
    );
    expect(
      studentQuizGroup(
        quizFixture(closes: now.add(const Duration(days: 1))),
        now,
      ),
      'This week',
    );
    expect(
      studentQuizGroup(
        quizFixture(closes: now.add(const Duration(days: 10))),
        now,
      ),
      'Later',
    );
  });
}
