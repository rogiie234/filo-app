import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exam_test_support.dart';

void main() {
  late AppDatabase db;
  late FakeExamRemote remote;
  late FakeExamTime time;
  late StudentExamRepository repository;
  late bool online;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeExamRemote()..currentSession = null;
    time = FakeExamTime();
    online = true;
    repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      isCurrent: () => true,
      online: () => online,
      clock: time.clock,
    );
  });
  tearDown(() async {
    repository.dispose();
    await db.close();
  });

  test('start coalesces duplicate requests and protects before RPC', () async {
    final protection = <bool>[];
    repository.dispose();
    repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      isCurrent: () => true,
      online: () => online,
      clock: time.clock,
      protectScreen: (enabled) async {
        if (enabled && protection.isEmpty) {
          expect(remote.calls, isNot(contains('start:quiz')));
        }
        protection.add(enabled);
      },
    );
    // Only the first protection precedes start; loading protects again.
    remote.onStart = () async {
      expect(protection, [true]);
      remote.currentSession = sessionPayload();
      return {'id': 'session'};
    };
    final first = repository.start('quiz');
    final second = repository.start('quiz');
    expect(identical(first, second), isTrue);
    await first;
    expect(remote.calls.where((c) => c == 'start:quiz'), hasLength(1));
    expect(repository.active!.sessionId, 'session');
  });

  test(
    'confirmed start survives get_exam failure and process recovery',
    () async {
      remote.onExam = () async => throw TimeoutException('questions lost');
      await expectLater(repository.start('quiz'), throwsA(isA<ExamFailure>()));
      expect(repository.pendingSessionId, 'session');
      expect(repository.engaged, isTrue);
      expect(
        (await repository.store.attempts()).single.attempt.questions,
        isEmpty,
      );
      repository.dispose();
      remote.onExam = null;
      repository = StudentExamRepository(
        store: ExamStore(db),
        remote: remote,
        isCurrent: () => true,
        online: () => online,
        clock: time.clock,
      );
      await repository.recover();
      expect(repository.active!.questions, hasLength(4));
      expect(remote.calls.where((c) => c == 'start:quiz'), hasLength(1));
    },
  );

  test(
    'lost start and status responses keep navigation locked until reconciled',
    () async {
      remote.onStart = () async {
        remote.currentSession = sessionPayload();
        remote.sessionError = TimeoutException('status lost');
        throw TimeoutException('start lost');
      };
      await expectLater(repository.start('quiz'), throwsA(isA<ExamFailure>()));
      expect(repository.startUncertain, isTrue);
      expect(repository.engaged, isTrue);
      remote.sessionError = null;
      await repository.recover();
      expect(repository.active!.sessionId, 'session');
      expect(repository.startUncertain, isFalse);
      expect(remote.calls.where((c) => c == 'start:quiz'), hasLength(1));
    },
  );

  test('protection failure never calls start or fetches questions', () async {
    repository.dispose();
    repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      isCurrent: () => true,
      online: () => true,
      clock: time.clock,
      protectScreen: (_) async => throw const ExamFailure('Protection failed'),
    );
    await expectLater(repository.start('quiz'), throwsA(isA<ExamFailure>()));
    expect(remote.calls, isEmpty);
  });

  test('offline new start uses start wording and sends nothing', () async {
    online = false;
    await expectLater(
      repository.start('quiz'),
      throwsA(
        isA<ExamFailure>().having(
          (e) => e.message,
          'message',
          'Connect to the internet to start.',
        ),
      ),
    );
    expect(remote.calls, isEmpty);
  });

  test(
    'known refusal remains friendly even if reconciliation also fails',
    () async {
      remote.onStart = () async {
        remote.sessionError = TimeoutException('status lost');
        throw const PostgrestException(
          message: 'This class is archived',
          code: 'P0001',
        );
      };
      await expectLater(
        repository.start('quiz'),
        throwsA(
          isA<ExamFailure>().having(
            (e) => e.message,
            'message',
            'This class is archived.',
          ),
        ),
      );
      expect(repository.engaged, isFalse);
    },
  );

  test(
    'start maps every documented refusal, offline and Philippine opening time',
    () {
      const expected = {
        'Not signed in': 'Sign in to continue.',
        'OTP verification required': 'Verify your account to continue.',
        'Quiz not found': 'This quiz is unavailable.',
        'This class is archived': 'This class is archived.',
        'This quiz has not opened yet':
            'This quiz opens on 23 Oct 2026 at 4:00 PM.',
        'This quiz has closed': 'This quiz has closed.',
        'You have already taken this quiz': 'You have already taken this quiz.',
        'unrecognized': "We couldn't complete that request. Try again.",
      };
      for (final item in expected.entries) {
        expect(
          examStartMessage(
            PostgrestException(message: item.key, code: 'P0001'),
            opensAt: examEpoch,
          ),
          item.value,
        );
      }
      expect(
        examStartMessage(TimeoutException('lost')),
        'Connect to the internet to start.',
      );
      expect(
        examStartMessage(
          const PostgrestException(message: 'This quiz has not opened yet'),
        ),
        'This quiz has not opened yet.',
      );
      expect(
        examStartMessage(
          const PostgrestException(message: 'other', code: '42501'),
        ),
        "You can't access this exam right now.",
      );
    },
  );
}
