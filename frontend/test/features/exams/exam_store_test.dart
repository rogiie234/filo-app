import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';

import 'exam_test_support.dart';

void main() {
  test('version seven upgrade preserves pending answers and persists submission intent', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-submit-upgrade',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/exam.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    var store = ExamStore(db);
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await store.write(
      'session',
      const ExamAnswer(questionId: 'bool', boolean: false),
      examEpoch,
    );
    await db.customStatement('DROP TABLE exam_submission_intent');
    await db.customStatement('PRAGMA user_version=7');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    store = ExamStore(db);
    expect((await store.answers('session')).single.answer.boolean, isFalse);
    await store.requestSubmission('session');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    store = ExamStore(db);
    expect(await store.submissionRequested('session'), isTrue);
    await store.clear('session');
    expect(await store.submissionRequested('session'), isFalse);
    expect(await store.answers('session'), isEmpty);
  });

  test('batch acknowledgements are transactional and leave newer revisions pending', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = ExamStore(db);
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await store.write(
      'session',
      const ExamAnswer(questionId: 'q', text: 'Old'),
      examEpoch,
    );
    await store.write(
      'session',
      const ExamAnswer(questionId: 'bool', boolean: false),
      examEpoch,
    );
    final batch = await store.answers('session', pendingOnly: true);
    await store.write(
      'session',
      const ExamAnswer(questionId: 'q', text: 'New'),
      examEpoch,
    );
    await store.acknowledgeBatch('session', batch);
    final pending = await store.answers('session', pendingOnly: true);
    expect(pending.single.answer.questionId, 'q');
    expect(pending.single.answer.text, 'New');
    expect(
      (await store.answers('session'))
          .firstWhere((a) => a.answer.questionId == 'bool')
          .sent,
      isTrue,
    );
  });

  test('fresh storage preserves false, empty text, option and revision acknowledgements', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = ExamStore(db);
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await store.write(
      'session',
      const ExamAnswer(questionId: 'bool', boolean: false),
      examEpoch,
    );
    await store.write(
      'session',
      const ExamAnswer(questionId: 'q', text: ''),
      examEpoch,
    );
    await store.write(
      'session',
      const ExamAnswer(questionId: 'choice', optionId: 'option'),
      examEpoch,
    );
    final first = (await store.answers('session'))
        .firstWhere((a) => a.answer.questionId == 'q');
    await store.write(
      'session',
      const ExamAnswer(questionId: 'q', text: 'New'),
      examEpoch,
    );
    await store.acknowledge('session', first);
    final answers = await store.answers('session');
    expect(
      answers.firstWhere((a) => a.answer.questionId == 'bool').answer.boolean,
      isFalse,
    );
    expect(
      answers
          .firstWhere((a) => a.answer.questionId == 'choice')
          .answer
          .optionId,
      'option',
    );
    expect(answers.firstWhere((a) => a.answer.questionId == 'q').sent, isFalse);
    expect((await store.attempts()).single.attempt.questions.map((q) => q.id), [
      'q',
      'bool',
      'choice',
      'essay',
    ]);
    await store.clear('session');
    expect(await store.attempts(), isEmpty);
    expect(await store.answers('session'), isEmpty);
  });
  test(
    'server refresh retains pending text and replaces confirmed answers',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ExamStore(db);
      await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
      await store.write(
        'session',
        const ExamAnswer(questionId: 'q', text: 'Local'),
        examEpoch,
      );
      await store.cache(
        ExamAttempt(
          examPayload(
            saved: [
              {'question_id': 'q', 'text_answer': 'Server'},
              {'question_id': 'bool', 'bool_answer': false},
            ],
          ),
        ),
        examEpoch,
        examEpoch,
      );
      final answers = await store.answers('session');
      expect(
        answers.firstWhere((a) => a.answer.questionId == 'q').answer.text,
        'Local',
      );
      expect(
        answers.firstWhere((a) => a.answer.questionId == 'bool').sent,
        isTrue,
      );
    },
  );
  test(
    'version five file upgrade preserves unrelated data and survives reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'filo-exam-upgrade',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/exam.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        "INSERT INTO cache_profiles(id,role,display_name) VALUES ('student','student','Name')",
      );
      await db.customStatement('DROP TABLE exam_local_answers');
      await db.customStatement('DROP TABLE exam_active_attempt');
      await db.customStatement('PRAGMA user_version=5');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect((await db.readProfile('student'))!.displayName, 'Name');
      final store = ExamStore(db);
      await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
      await store.write(
        'session',
        const ExamAnswer(questionId: 'q', text: ''),
        examEpoch,
      );
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect((await ExamStore(db).answers('session')).single.answer.text, '');
      expect(
        (await ExamStore(db).attempts()).single.deviceAtReceipt,
        examEpoch,
      );
    },
  );
}
