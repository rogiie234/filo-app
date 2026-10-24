import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/core/sync/sqlite_outbox.dart';
import 'package:filo/features/exams/application/exam_leave_tracker.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/presentation/exam_question_card.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exam_test_support.dart';

void main() {
  testWidgets('debounces short departures and coalesces hidden/paused', (
    tester,
  ) async {
    var captures = 0, writes = 0, flushes = 0;
    final tracker = ExamLeaveTracker(
      capture: () {
        captures++;
        return () async {
          writes++;
        };
      },
      onQueued: () async {
        flushes++;
      },
    );
    tracker.background();
    await tester.pump(const Duration(milliseconds: 999));
    await tracker.resume();
    await tester.pump(const Duration(seconds: 1));
    expect(writes, 0);
    tracker.background();
    tracker.background();
    await tester.pump(const Duration(seconds: 1));
    expect(writes, 1);
    expect(flushes, 0);
    await tracker.resume();
    tracker.background();
    await tester.pump(const Duration(seconds: 1));
    expect(writes, 2);
    expect(captures, 3);
    tracker.dispose();
  });

  testWidgets(
    'retries the captured write and flushes a late enqueue on return',
    (tester) async {
      final gate = Completer<void>();
      var captures = 0, calls = 0, flushes = 0;
      final tracker = ExamLeaveTracker(
        capture: () {
          captures++;
          return () async {
            calls++;
            if (calls == 1) throw StateError('disk busy');
            await gate.future;
          };
        },
        onQueued: () async {
          flushes++;
        },
      );
      tracker.background();
      await tester.pump(const Duration(seconds: 1));
      final returning = tracker.resume();
      await tester.pump();
      gate.complete();
      await returning;
      expect(captures, 1);
      expect(calls, 2);
      expect(flushes, 1);
      tracker.dispose();
    },
  );

  test(
    'stable event uses server clock, account guard and foreground queue filter',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      var current = true;
      final time = FakeExamTime();
      final repository = StudentExamRepository(
        store: ExamStore(db),
        remote: FakeExamRemote(),
        isCurrent: () => current,
        online: () => true,
        clock: time.clock,
      );
      try {
        await repository.load('session');
        final write = repository.captureLeave()!;
        time.wall = time.wall.add(const Duration(days: 5));
        time.elapsed += const Duration(seconds: 10);
        await write();
        await write();
        final rows = await db.select(db.outbox).get();
        expect(rows, hasLength(1));
        expect(
          jsonDecode(rows.single.payload)['left_at'],
          examEpoch.toIso8601String(),
        );
        expect(
          await SqliteOutbox(
            db,
            includeLeaveEvents: false,
          ).claim(DateTime.now().toUtc()),
          isNull,
        );
        await SqliteOutbox(db).enqueue('read', 'notification_read', {
          'notification_id': 'notification',
        });
        final other = await SqliteOutbox(
          db,
          includeLeaveEvents: false,
        ).claim(DateTime.now().toUtc());
        expect(other?.type, 'notification_read');
        expect(await SqliteOutbox(db).claim(DateTime.now().toUtc()), isNotNull);
        current = false;
        await write();
        expect(await db.select(db.outbox).get(), hasLength(2));
      } finally {
        repository.dispose();
        await db.close();
      }
    },
  );

  test(
    'rejected start releases protection; confirmed completion releases it too',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final remote = FakeExamRemote()..currentSession = null;
      final protection = <bool>[];
      final repository = StudentExamRepository(
        store: ExamStore(db),
        remote: remote,
        isCurrent: () => true,
        online: () => true,
        clock: FakeExamTime().clock,
        protectScreen: (enabled) async {
          protection.add(enabled);
        },
      );
      try {
        remote.onStart = () async =>
            throw const ExamFailure('This class is archived.');
        await expectLater(
          repository.start('quiz'),
          throwsA(isA<ExamFailure>()),
        );
        expect(protection.last, false);
        remote.onStart = null;
        await repository.start('quiz');
        expect(protection.last, true);
        remote.currentSession = sessionPayload('submitted');
        await repository.reconcile();
        expect(repository.engaged, false);
        expect(protection.last, false);
      } finally {
        repository.dispose();
        await db.close();
      }
    },
  );

  test('unresolved start retains protection until account disposal', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final remote = FakeExamRemote()..currentSession = null;
    final protection = <bool>[];
    final repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      isCurrent: () => true,
      online: () => true,
      clock: FakeExamTime().clock,
      protectScreen: (enabled) async {
        protection.add(enabled);
      },
    );
    remote.onStart = () async {
      remote.sessionError = TimeoutException('status unavailable');
      throw TimeoutException('start response lost');
    };
    await expectLater(repository.start('quiz'), throwsA(isA<ExamFailure>()));
    expect(repository.engaged, true);
    expect(protection, [true]);
    repository.dispose();
    expect(protection.last, false);
    await db.close();
  });

  testWidgets('disposing during local persistence cancels callbacks safely', (
    tester,
  ) async {
    final gate = Completer<void>();
    var flushes = 0;
    final tracker = ExamLeaveTracker(
      capture: () =>
          () => gate.future,
      onQueued: () async {
        flushes++;
      },
    );
    tracker.background();
    await tester.pump(const Duration(seconds: 1));
    tracker.dispose();
    gate.complete();
    await tester.pump();
    expect(flushes, 0);
  });

  testWidgets(
    'answer input suppresses selection and context menu but accepts typing',
    (tester) async {
      String? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExamQuestionCard(
              question: ExamQuestion(examPayload()['questions'][0]),
              number: 1,
              answer: null,
              enabled: true,
              onChanged: (value) => answer = value.text,
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enableInteractiveSelection, false);
      expect(field.contextMenuBuilder, isNotNull);
      await tester.enterText(find.byType(TextField), 'Typed answer');
      await tester.longPress(find.byType(TextField));
      await tester.pump();
      expect(answer, 'Typed answer');
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    },
  );
}
