import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';

import 'exam_test_support.dart';

void main() {
  late AppDatabase db;
  late ExamStore store;
  late FakeExamRemote remote;
  late FakeExamTime time;
  late StudentExamRepository repository;
  late bool online, current;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = ExamStore(db);
    remote = FakeExamRemote();
    time = FakeExamTime();
    online = false;
    current = true;
    repository = StudentExamRepository(
      store: store,
      remote: remote,
      clock: time.clock,
      isCurrent: () => current,
      online: () => online,
    );
  });
  tearDown(() async {
    repository.dispose();
    await db.close();
  });
  test(
    'a late snapshot cannot resurrect a confirmed completed attempt',
    () async {
      online = true;
      await repository.recover();
      await repository.saver!.flush();
      final entered = Completer<void>(), response = Completer<ExamJson>();
      remote.onExam = () {
        entered.complete();
        return response.future;
      };
      final loading = repository.load('session');
      await entered.future;
      remote.currentSession = sessionPayload('submitted');
      await repository.reconcile();
      response.complete(examPayload());
      await loading;
      expect(repository.active, isNull);
      expect(await store.attempts(), isEmpty);
    },
  );
  test('uncertain submission retains the attempt and local answers', () async {
    online = true;
    await repository.recover();
    await repository.saver!.flush();
    await repository.answer(const ExamAnswer(questionId: 'q', text: 'Keep'));
    await repository.saver!.flush();
    remote.onSubmit = () async {
      remote.sessionError = TimeoutException('Cannot reconcile');
      throw TimeoutException('Response lost');
    };
    await expectLater(repository.submit(), throwsA(isA<ExamFailure>()));
    expect(repository.active, isNotNull);
    expect(repository.completion, isNull);
    expect((await store.answers('session')).single.answer.text, 'Keep');
  });
  test(
    'local attempt loads offline first and merges unsent work on reconnect',
    () async {
      await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
      await store.write(
        'session',
        const ExamAnswer(questionId: 'q', text: 'Local'),
        examEpoch,
      );
      await repository.recover();
      expect(repository.active!.sessionId, 'session');
      expect(repository.clock.verified, isFalse);
      expect(remote.calls, isEmpty);
      expect((await repository.answers()).single.answer.text, 'Local');
      online = true;
      remote.payload = examPayload(
        saved: [
          {'question_id': 'q', 'text_answer': 'Old server'},
        ],
      );
      await repository.recover();
      await repository.saver!.flush();
      expect(remote.calls.first, 'session:quiz');
      expect(remote.calls, isNot(contains('quizzes')));
      expect(remote.calls, isNot(contains('start:quiz')));
      expect(remote.saves.single.text, 'Local');
      expect(repository.clock.verified, isTrue);
    },
  );
  test(
    'empty local storage discovers open quizzes and resumes without start',
    () async {
      online = true;
      await repository.recover();
      await repository.saver!.flush();
      expect(remote.calls.take(3), ['quizzes', 'session:quiz', 'exam:session']);
      expect(repository.active!.sessionId, 'session');
      expect(remote.calls, isNot(contains('start:quiz')));
    },
  );
  test('failed discovery is an error and retry can recover', () async {
    online = true;
    remote.sessionError = const ExamFailure('Connection lost', retryable: true);
    await repository.recover();
    expect(repository.active, isNull);
    expect(repository.error!.retryable, isTrue);
    remote.sessionError = null;
    await repository.recover();
    await repository.saver!.flush();
    expect(repository.active, isNotNull);
    expect(repository.error, isNull);
  });
  test('submitted and voided/null sessions clear local rows only after status confirmation', () async {
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await repository.recover();
    online = true;
    remote.sessionError = const ExamFailure('Connection lost', retryable: true);
    await repository.recover();
    expect(await store.attempts(), hasLength(1));
    remote.sessionError = null;
    remote.currentSession = sessionPayload('auto_submitted');
    await repository.recover();
    expect(repository.active, isNull);
    expect(await store.attempts(), isEmpty);
    expect(repository.completion, 'Your answers were submitted.');
    online = false;
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await repository.recover();
    remote.currentSession = null;
    online = true;
    await repository.recover();
    expect(await store.attempts(), isEmpty);
    expect(repository.completion, 'This attempt has ended.');
  });
  test(
    'late fetch after account change cannot persist another account payload',
    () async {
      online = true;
      final entered = Completer<void>(), response = Completer<ExamJson>();
      remote.onExam = () {
        entered.complete();
        return response.future;
      };
      final recovery = repository.recover();
      await entered.future;
      current = false;
      response.complete(examPayload());
      await recovery;
      expect(await store.attempts(), isEmpty);
      expect(repository.active, isNull);
    },
  );
  test(
    'lost submit response reconciles confirmed completion and clears answers',
    () async {
      online = true;
      await repository.recover();
      await repository.saver!.flush();
      await repository.answer(
        const ExamAnswer(questionId: 'bool', boolean: false),
      );
      remote.onSubmit = () async {
        remote.currentSession = sessionPayload('submitted');
        throw TimeoutException('lost response');
      };
      await repository.submit();
      expect(repository.active, isNull);
      expect(await store.answers('session'), isEmpty);
      expect(remote.saves.single.boolean, isFalse);
    },
  );
  test(
    'expired offline attempt remains stored without claiming submission',
    () async {
      await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
      time.wall = examEpoch.add(const Duration(minutes: 11));
      await repository.recover();
      expect(repository.clock.canEdit, isFalse);
      expect(repository.completion, isNull);
      expect(await store.attempts(), hasLength(1));
    },
  );
}
