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
  test('submission awaits a local write already in progress and drains text debounce', () async {
    online = true;
    await repository.recover();
    final writing = repository.answer(
      const ExamAnswer(questionId: 'q', text: 'Last edit'),
    );
    final submitting = repository.submit();
    await Future.wait([writing, submitting]);
    expect(remote.saves.single.text, 'Last edit');
    expect(
      remote.calls.indexOf('save:q'),
      lessThan(remote.calls.indexOf('submit:session')),
    );
    expect(await store.answers('session'), isEmpty);
    expect(await store.submissionRequested('session'), isFalse);
  });

  test(
    'offline submission intent survives repository recreation and reconnect',
    () async {
      online = true;
      await repository.recover();
      online = false;
      await repository.answer(
        const ExamAnswer(questionId: 'bool', boolean: false),
      );
      await expectLater(repository.submit(), throwsA(isA<ExamFailure>()));
      expect(
        repository.error!.message,
        "You're offline. Stay on this screen and reconnect to submit. The timer keeps running.",
      );
      expect(await store.submissionRequested('session'), isTrue);
      repository.dispose();
      repository = StudentExamRepository(
        store: store,
        remote: remote,
        clock: time.clock,
        isCurrent: () => current,
        online: () => online,
      );
      await repository.recover();
      expect(repository.submissionRequested, isTrue);
      online = true;
      await repository.recover();
      expect(remote.saves.single.boolean, isFalse);
      expect(remote.calls.where((c) => c == 'submit:session'), hasLength(1));
      expect(await store.attempts(), isEmpty);
      expect(await store.submissionRequested('session'), isFalse);
    },
  );

  test('timeout drains existing answers within grace and accepts server automatic status', () async {
    online = true;
    await repository.recover();
    online = false;
    await repository.answer(
      const ExamAnswer(questionId: 'q', text: 'Before zero'),
    );
    time.elapsed = const Duration(minutes: 10, seconds: 1);
    remote.currentSession = sessionPayload()
      ..['server_now'] = examEpoch.add(time.elapsed).toIso8601String();
    remote.onSubmit = () async {
      remote.currentSession = sessionPayload('auto_submitted');
      return {'status': 'auto_submitted'};
    };
    online = true;
    await repository.submit();
    expect(remote.saves.single.text, 'Before zero');
    expect(
      remote.calls.indexOf('save:q'),
      lessThan(remote.calls.indexOf('submit:session')),
    );
    expect(repository.completionTimedOut, isTrue);
    expect(await store.answers('session'), isEmpty);
    await repository.submit();
    expect(remote.calls.where((c) => c == 'submit:session'), hasLength(1));
  });

  test(
    'after save cutoff an open server session finalizes without replay',
    () async {
      online = true;
      await repository.recover();
      online = false;
      await repository.answer(
        const ExamAnswer(questionId: 'q', text: 'Too late'),
      );
      time.elapsed = const Duration(minutes: 10, seconds: 14);
      remote.currentSession = sessionPayload()
        ..['server_now'] = examEpoch.add(time.elapsed).toIso8601String();
      remote.onSubmit = () async => {'status': 'auto_submitted'};
      online = true;
      await repository.submit();
      expect(remote.saves, isEmpty);
      expect(remote.calls.where((c) => c == 'submit:session'), hasLength(1));
      expect(repository.completionTimedOut, isTrue);
      expect(await store.answers('session'), isEmpty);
    },
  );

  test('reconnect beyond grace never replays pending answers', () async {
    online = true;
    await repository.recover();
    online = false;
    await repository.answer(
      const ExamAnswer(questionId: 'q', text: 'Never received'),
    );
    time.elapsed = const Duration(minutes: 10, seconds: 16);
    await expectLater(repository.submit(), throwsA(isA<ExamFailure>()));
    expect(
      repository.error!.message,
      "Time's up. Reconnect to check your submission.",
    );
    remote.currentSession = sessionPayload('auto_submitted');
    online = true;
    await repository.recover();
    expect(remote.saves, isEmpty);
    expect(remote.calls.where((c) => c == 'submit:session'), isEmpty);
    expect(repository.completionTimedOut, isTrue);
    expect(await store.attempts(), isEmpty);
  });

  test('concurrent submit and timeout share one request and keep content until receipt', () async {
    online = true;
    await repository.recover();
    final entered = Completer<void>(), receipt = Completer<ExamJson>();
    remote.onSubmit = () {
      entered.complete();
      return receipt.future;
    };
    final first = repository.submit();
    await entered.future;
    final second = repository.submit();
    expect(repository.submitting, isTrue);
    expect(await store.attempts(), hasLength(1));
    expect(repository.completion, isNull);
    receipt.complete({'status': 'submitted'});
    await Future.wait([first, second]);
    expect(remote.calls.where((c) => c == 'submit:session'), hasLength(1));
    expect(repository.active, isNull);
  });

  test('validation refusal remains editable and cannot silently discard the answer', () async {
    online = true;
    await repository.recover();
    await expectLater(
      repository.answer(ExamAnswer(questionId: 'q', text: 'x' * 10001)),
      throwsA(isA<ExamFailure>()),
    );
    await expectLater(repository.submit(), throwsA(isA<ExamFailure>()));
    expect(remote.calls, isNot(contains('submit:session')));
    expect(repository.submissionRequested, isFalse);
    expect(
      repository.error!.message,
      'Keep your answer within 10,000 characters.',
    );
    await repository.answer(
      const ExamAnswer(questionId: 'q', text: 'Corrected'),
    );
    await repository.submit();
    expect(remote.saves.last.text, 'Corrected');
    expect(repository.active, isNull);
  });

  test(
    'failed pending save prevents premature submission and retries safely',
    () async {
      online = true;
      await repository.recover();
      online = false;
      await repository.answer(
        const ExamAnswer(questionId: 'q', text: 'Retry me'),
      );
      online = true;
      remote.saveError = TimeoutException('Save response lost');
      await expectLater(repository.submit(), throwsA(isA<ExamFailure>()));
      expect(remote.calls, isNot(contains('submit:session')));
      expect(repository.active, isNotNull);
      expect(await store.submissionRequested('session'), isTrue);
      remote.saveError = null;
      await repository.submit();
      expect(repository.active, isNull);
    },
  );

  test(
    'submission drains one queued four-type batch before finalizing',
    () async {
      online = true;
      await repository.recover();
      await repository.saver!.flush();
      online = false;
      for (final answer in [
        const ExamAnswer(questionId: 'q', text: 'Identification'),
        const ExamAnswer(questionId: 'bool', boolean: false),
        const ExamAnswer(questionId: 'choice', optionId: 'option'),
        const ExamAnswer(questionId: 'essay', text: 'Essay draft'),
      ]) {
        await repository.answer(answer);
      }
      expect(remote.batches, isEmpty);
      online = true;
      await repository.submit();
      expect(remote.batches.single, hasLength(4));
      expect(remote.saves, hasLength(4));
      expect(
        remote.calls.indexOf('submit:session'),
        greaterThan(remote.calls.indexOf('save:q')),
      );
      expect(repository.active, isNull);
      expect(repository.completion, 'Your answers were submitted.');
    },
  );

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
