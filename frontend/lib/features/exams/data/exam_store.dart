import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import '../domain/exam.dart';

class StoredAttempt {
  const StoredAttempt(this.attempt, this.serverAtReceipt, this.deviceAtReceipt);
  final ExamAttempt attempt;
  final DateTime serverAtReceipt, deviceAtReceipt;
}

class StoredAnswer {
  const StoredAnswer(this.answer, this.revision, this.sent);
  final ExamAnswer answer;
  final int revision;
  final bool sent;
}

class ExamStore {
  ExamStore(this.db);
  final AppDatabase db;
  Future<StudentQuizCatalog> catalog() async {
    final rows = await db
        .customSelect('SELECT payload FROM student_quiz_catalog')
        .get();
    final state = await db
        .customSelect('SELECT id FROM student_quiz_catalog_state')
        .get();
    return StudentQuizCatalog(
      rows.map((row) {
        final value = ExamJson.from(
          jsonDecode(row.read<String>('payload')) as Map,
        );
        return StudentQuiz(
          ExamJson.from(value['quiz'] as Map),
          value['session'] == null
              ? null
              : ExamSession(ExamJson.from(value['session'] as Map)),
          sessionKnown: value['known'] == true,
        );
      }).toList(),
      loaded: state.isNotEmpty,
    );
  }

  Future<void> saveCatalog(List<StudentQuiz> quizzes) =>
      db.transaction(() async {
        await db.customStatement('DELETE FROM student_quiz_catalog');
        for (final quiz in quizzes) {
          await db.customStatement(
            '''
        INSERT INTO student_quiz_catalog(id,class_id,payload)
        SELECT ?,id,? FROM cache_classes WHERE id=? AND deleted_at IS NULL
      ''',
            [
              quiz.id,
              jsonEncode({
                'quiz': quiz.json,
                'session': quiz.session?.json,
                'known': quiz.sessionKnown,
              }),
              quiz.classId,
            ],
          );
        }
        await db.customStatement(
          'INSERT OR IGNORE INTO student_quiz_catalog_state(id) VALUES (1)',
        );
      });
  Future<List<StoredAttempt>> attempts() async {
    final rows = await db
        .customSelect(
          'SELECT * FROM exam_active_attempt ORDER BY saved_at DESC',
        )
        .get();
    return rows
        .map(
          (row) => StoredAttempt(
            ExamAttempt({
              'session_id': row.read<String>('session_id'),
              'quiz_id': row.read<String>('quiz_id'),
              'started_at': row.read<String>('started_at'),
              'deadline_at': row.read<String>('deadline_at'),
              'server_now': row.read<String>('server_now'),
              'questions': jsonDecode(row.read<String>('questions')),
            }),
            DateTime.parse(row.read<String>('server_now')),
            DateTime.parse(row.read<String>('device_fetch_at')),
          ),
        )
        .toList();
  }

  Future<void> cache(
    ExamAttempt attempt,
    DateTime serverAtReceipt,
    DateTime deviceAtReceipt,
  ) => db.transaction(() async {
    await db.customStatement(
      '''
      INSERT INTO exam_active_attempt(session_id,quiz_id,started_at,deadline_at,server_now,questions,saved_at,device_fetch_at)
      VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(session_id) DO UPDATE SET
      deadline_at=excluded.deadline_at,server_now=excluded.server_now,questions=excluded.questions,
      saved_at=excluded.saved_at,device_fetch_at=excluded.device_fetch_at
    ''',
      [
        attempt.sessionId,
        attempt.quizId,
        attempt.startedAt.toIso8601String(),
        attempt.deadline.toIso8601String(),
        serverAtReceipt.toIso8601String(),
        jsonEncode(attempt.json['questions']),
        deviceAtReceipt.toIso8601String(),
        deviceAtReceipt.toIso8601String(),
      ],
    );
    for (final answer in attempt.savedAnswers) {
      // Pending local edits win over older server answers during reconciliation.
      await db.customStatement(
        '''
        INSERT INTO exam_local_answers(session_id,question_id,option_id,bool_answer,text_answer,updated_at,sent)
        VALUES (?,?,?,?,?,?,1) ON CONFLICT(session_id,question_id) DO UPDATE SET
        option_id=excluded.option_id,bool_answer=excluded.bool_answer,text_answer=excluded.text_answer
        WHERE exam_local_answers.sent=1
      ''',
        [
          attempt.sessionId,
          answer.questionId,
          answer.optionId,
          answer.boolean == null ? null : (answer.boolean! ? 1 : 0),
          answer.text,
          deviceAtReceipt.toIso8601String(),
        ],
      );
    }
  });

  Future<List<StoredAnswer>> answers(String sessionId) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM exam_local_answers WHERE session_id=?',
          variables: [Variable(sessionId)],
        )
        .get();
    return rows
        .map(
          (row) => StoredAnswer(
            ExamAnswer(
              questionId: row.read<String>('question_id'),
              optionId: row.readNullable<String>('option_id'),
              boolean: row.readNullable<int>('bool_answer') == null
                  ? null
                  : row.read<int>('bool_answer') == 1,
              text: row.readNullable<String>('text_answer'),
            ),
            row.read<int>('revision'),
            row.read<int>('sent') == 1,
          ),
        )
        .toList();
  }

  Future<void> write(String sessionId, ExamAnswer answer, DateTime now) =>
      db.customStatement(
        '''
    INSERT INTO exam_local_answers(session_id,question_id,option_id,bool_answer,text_answer,updated_at,sent)
    VALUES (?,?,?,?,?,?,0) ON CONFLICT(session_id,question_id) DO UPDATE SET
    option_id=excluded.option_id,bool_answer=excluded.bool_answer,text_answer=excluded.text_answer,
    updated_at=excluded.updated_at,sent=0,revision=exam_local_answers.revision+1
  ''',
        [
          sessionId,
          answer.questionId,
          answer.optionId,
          answer.boolean == null ? null : (answer.boolean! ? 1 : 0),
          answer.text,
          now.toUtc().toIso8601String(),
        ],
      );

  Future<void> acknowledge(String sessionId, StoredAnswer answer) =>
      db.customStatement(
        'UPDATE exam_local_answers SET sent=1 WHERE session_id=? AND question_id=? AND revision=?',
        [sessionId, answer.answer.questionId, answer.revision],
      );

  Future<void> clear(String sessionId) => db.transaction(() async {
    await db.customStatement(
      'DELETE FROM exam_local_answers WHERE session_id=?',
      [sessionId],
    );
    await db.customStatement(
      'DELETE FROM exam_active_attempt WHERE session_id=?',
      [sessionId],
    );
  });
}
