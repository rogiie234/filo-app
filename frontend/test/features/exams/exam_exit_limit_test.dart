import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/exams/domain/exam_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exam_test_support.dart';

void main() {
  test('acknowledged IDs form a union; legacy stays logging-only', () {
    var state = const ExamIntegrity().merge({
      'leave_event_ids': ['1', '2', '3', '4', '5'],
    });
    expect(state.atLimit, isFalse);
    state = const ExamIntegrity(limit: 5).merge({
      'leave_event_ids': ['1', '2', '3', '4'],
    });
    expect(state.needsWarning, isTrue);
    state = state.merge({'warning_shown': true}).merge({
      'leave_event_ids': ['2', '3'],
    });
    expect(state.count, 4);
    expect(state.needsWarning, isFalse);
    state = state.merge({'leave_event_ids': ['5', '5']});
    expect(state.atLimit, isTrue);
    expect(state.merge({'leave_event_ids': [], 'forced': false}).atLimit, isTrue);
  });

  test('version 14 upgrades without losing answers; intent and warning survive restart', () async {
    final dir = await Directory.systemTemp.createTemp('filo-exit-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/exam.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    var store = ExamStore(db);
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await store.write('session', const ExamAnswer(questionId: 'q', text: 'Kept'), examEpoch);
    await db.customStatement('DROP TABLE exam_integrity_state');
    await db.customStatement('PRAGMA user_version=14');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    store = ExamStore(db);
    expect((await store.answers('session')).single.answer.text, 'Kept');
    expect((await store.integrity('session')).limit, isNull);
    await store.mergeIntegrity('session', {'leave_limit': 5});
    for (var i = 1; i <= 5; i++) {
      await store.queueLeave('$i', 'session', examEpoch.toIso8601String());
    }
    await store.queueLeave('5', 'session', examEpoch.toIso8601String());
    await store.mergeIntegrity('session', {'warning_shown': true});
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    store = ExamStore(db);
    final state = await store.integrity('session');
    expect(state.count, 5);
    expect(state.atLimit, isTrue);
    expect(state.warningShown, isTrue);
    expect(state.ready, isFalse);
    expect(await store.submissionRequested('session'), isTrue);
    expect((await db.select(db.outbox).get()).length, 5);
    await store.confirmSession('quiz', ExamSession({...sessionPayload(), 'leave_limit': 5, 'leave_event_ids': ['1', '3']}));
    expect((await store.integrity('session')).count, 5);
    expect((await store.answers('session')).single.answer.text, 'Kept');
  });

  for (final policy in [null, 5]) {
    test('policy $policy preserves legacy or locks at five and flushes answers first', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ExamStore(db);
      final remote = FakeExamRemote()..payload = {...examPayload(), 'leave_limit': policy};
      final time = FakeExamTime();
      var online = false;
      var blocked = false;
      var flushed = false;
      final repo = StudentExamRepository(
        store: store, remote: remote, isCurrent: () => true,
        online: () => online, clock: time.clock,
        isWindowBlocked: () => blocked,
        flushLeaveEvents: () async {
          expect(await store.answers('session', pendingOnly: true), isEmpty);
          expect((await store.integrity('session')).ready, isTrue);
          flushed = true;
          remote.currentSession = {...sessionPayload('auto_submitted'), 'auto_submit_reason': 'leave_limit', 'leave_limit': 5};
        },
      );
      addTearDown(repo.dispose);
      online = true;
      await repo.load('session');
      online = false;
      blocked = true;
      await expectLater(repo.answer(const ExamAnswer(questionId: 'q', text: 'Blocked')), throwsA(isA<ExamFailure>()));
      blocked = false;
      await repo.answer(const ExamAnswer(questionId: 'q', text: 'Keep this'));
      for (var i = 1; i <= 4; i++) { await repo.captureLeave()!(); }
      expect(repo.integrity.needsWarning, policy == 5);
      if (policy == 5) await repo.acknowledgeExitWarning();
      await repo.captureLeave()!();
      expect(repo.forcedSubmission, policy == 5);
      if (policy == null) {
        await repo.answer(const ExamAnswer(questionId: 'q', text: 'Still editable'));
        return;
      }
      expect(repo.captureLeave(), isNull);
      await expectLater(repo.answer(const ExamAnswer(questionId: 'q', text: 'Changed')), throwsA(isA<ExamFailure>()));
      await expectLater(repo.submit(), throwsA(isA<ExamFailure>()));
      expect(await store.submissionRequested('session'), isTrue);
      expect((await store.answers('session')).single.answer.text, 'Keep this');
      online = true;
      remote.saveError = const ExamFailure('Invalid answer');
      await expectLater(repo.submit(), throwsA(isA<ExamFailure>()));
      expect(repo.forcedSubmission, isTrue);
      expect(repo.submissionRequested, isTrue);
      expect(flushed, isFalse);
      remote.saveError = null;
      await repo.submit();
      expect(flushed, isTrue);
      expect(remote.calls, isNot(contains('submit:session')));
      expect(repo.active, isNull);
      expect(repo.completionExitLimit, isTrue);
      expect(repo.completionTimedOut, isFalse);
      expect(repo.completion, 'Submitted after 5 exits.');
    });
  }
}
