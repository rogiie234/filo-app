import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/application/exam_answer_saver.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';

import 'exam_test_support.dart';

void main() {
  late AppDatabase db;
  late ExamStore store;
  late FakeExamRemote remote;
  late FakeExamTime time;
  late ExamAnswerSaver saver;
  late List<({Duration delay, void Function() action})> scheduled;
  late bool online, current;
  late int reconciles;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = ExamStore(db);
    remote = FakeExamRemote();
    time = FakeExamTime()..synchronize();
    online = false;
    current = true;
    reconciles = 0;
    scheduled = [];
    await store.cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    saver = ExamAnswerSaver(
      store: store,
      remote: remote,
      clock: time.clock,
      sessionId: 'session',
      isCurrent: () => current,
      online: () => online,
      onChanged: () {},
      onReconcile: () async {
        reconciles++;
      },
      schedule: (delay, action) =>
          scheduled.add((delay: delay, action: action)),
    );
  });
  tearDown(() async {
    saver.dispose();
    await db.close();
  });
  test(
    'oversized text remains durable without retrying until shortened',
    () async {
      online = true;
      await expectLater(
        saver.change(ExamAnswer(questionId: 'q', text: 'x' * 10001)),
        throwsA(isA<ExamFailure>()),
      );
      expect(
        (await store.answers('session')).single.answer.text!.length,
        10001,
      );
      await saver.flush();
      expect(remote.saves, isEmpty);
      online = false;
      await saver.change(const ExamAnswer(questionId: 'q', text: 'Short'));
      online = true;
      await saver.flush();
      expect(remote.saves.single.text, 'Short');
    },
  );
  test('a failed local write never reaches the server', () async {
    saver.dispose();
    saver = ExamAnswerSaver(
      store: FailingExamStore(db),
      remote: remote,
      clock: time.clock,
      sessionId: 'session',
      isCurrent: () => true,
      online: () => true,
      onChanged: () {},
      onReconcile: () async {},
    );
    await expectLater(
      saver.change(const ExamAnswer(questionId: 'q', text: 'Answer')),
      throwsStateError,
    );
    expect(remote.saves, isEmpty);
    expect(await store.answers('session'), isEmpty);
  });
  test(
    'offline edits persist first; reconnect sends only latest once',
    () async {
      await saver.change(const ExamAnswer(questionId: 'q', text: 'First'));
      await saver.change(const ExamAnswer(questionId: 'q', text: 'Latest'));
      expect(remote.saves, isEmpty);
      expect((await store.answers('session')).single.answer.text, 'Latest');
      online = true;
      remote.onSave = (answer) async {
        expect((await store.answers('session')).single.sent, isFalse);
      };
      await saver.flush();
      await saver.flush();
      expect(remote.saves.map((a) => a.text), ['Latest']);
      expect(await saver.allSent(), isTrue);
    },
  );
  test(
    'edit during flight stays pending until its own acknowledgement',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      await saver.change(const ExamAnswer(questionId: 'q', text: 'Old'));
      online = true;
      remote.onSave = (answer) async {
        if (answer.text == 'Old') {
          entered.complete();
          await release.future;
        }
      };
      final flushing = saver.flush();
      await entered.future;
      await saver.change(const ExamAnswer(questionId: 'q', text: 'New'));
      expect((await store.answers('session')).single.sent, isFalse);
      release.complete();
      await flushing;
      expect(remote.saves.map((a) => a.text), ['Old', 'New']);
      expect(await saver.allSent(), isTrue);
    },
  );
  test(
    'transient retries grow to eight seconds and cutoff cancels dispatch',
    () async {
      await saver.change(const ExamAnswer(questionId: 'q', text: 'Answer'));
      online = true;
      remote.saveError = const ExamFailure('Offline', retryable: true);
      for (final delay in [1, 2, 4, 8, 8]) {
        await saver.flush();
        expect(scheduled.last.delay, Duration(seconds: delay));
      }
      time.elapsed = const Duration(minutes: 10, seconds: 14);
      remote.saveError = null;
      scheduled.last.action();
      await saver.flush();
      expect(remote.saves.length, 5);
      expect(await saver.allSent(), isFalse);
    },
  );
  test('terminal validation stops repeated sends until edited', () async {
    await saver.change(const ExamAnswer(questionId: 'q', text: 'Invalid'));
    online = true;
    remote.saveError = const ExamFailure('Invalid option');
    await saver.flush();
    await saver.flush();
    expect(remote.saves.length, 1);
    expect(scheduled, isEmpty);
    online = false;
    await saver.change(const ExamAnswer(questionId: 'q', text: 'Corrected'));
    remote.saveError = null;
    online = true;
    await saver.flush();
    expect(await saver.allSent(), isTrue);
  });
  test(
    'attempt closed reconciles and never resends; disposal ignores late ack',
    () async {
      await saver.change(const ExamAnswer(questionId: 'q', text: 'Answer'));
      online = true;
      remote.saveError = const ExamFailure('Closed', reconcile: true);
      await saver.flush();
      scheduled.single.action();
      await Future<void>.value();
      expect(reconciles, 1);
      await saver.flush();
      expect(remote.saves.length, 1);
    },
  );
  test('account change during RPC does not acknowledge or send more', () async {
    await saver.change(const ExamAnswer(questionId: 'q', text: 'Answer'));
    online = true;
    remote.onSave = (_) async {
      current = false;
    };
    await saver.flush();
    expect(await saver.allSent(), isFalse);
    await saver.flush();
    expect(remote.saves.length, 1);
  });
  test('unverified restart clock never dispatches', () async {
    time.clock.restore(
      serverAtReceipt: examEpoch,
      deviceAtReceipt: examEpoch,
      deadline: examEpoch.add(const Duration(minutes: 10)),
    );
    await saver.change(
      const ExamAnswer(questionId: 'q', text: 'Offline restart'),
    );
    online = true;
    await saver.flush();
    expect(remote.saves, isEmpty);
  });
}

class FailingExamStore extends ExamStore {
  FailingExamStore(super.db);
  @override
  Future<void> write(String sessionId, ExamAnswer answer, DateTime now) async {
    throw StateError('Disk full');
  }
}
