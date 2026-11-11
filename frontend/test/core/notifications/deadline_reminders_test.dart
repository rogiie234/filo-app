import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/core/notifications/push_events.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class ReminderBridgeFixture extends DeadlineBridge {
  bool fail = false;
  int calls = 0;
  @override
  bool get supported => true;
  @override
  Future<void> reconcile(String account, String lease) async {
    calls++;
    if (fail) throw StateError('fixture scheduling failure');
  }
}

Future<void> seedDeadline(AppDatabase db, DateTime due) async {
  for (final role in ['student', 'instructor']) {
    await db.saveProfile(
      CacheProfilesCompanion.insert(id: role, role: role, displayName: role),
    );
  }
  await db
      .into(db.cacheClasses)
      .insert(
        CacheClassesCompanion.insert(
          id: 'class',
          ownerId: 'instructor',
          course: 'Course',
          section: 'Section',
          schoolYear: '2026',
          joinCode: 'CODE',
        ),
      );
  await db
      .into(db.cacheClassMembers)
      .insert(
        CacheClassMembersCompanion.insert(
          id: 'membership',
          classId: 'class',
          studentId: 'student',
          status: const Value('active'),
        ),
      );
  await db
      .into(db.cachePosts)
      .insert(
        CachePostsCompanion.insert(
          id: 'post',
          classId: 'class',
          authorId: 'instructor',
          kind: 'assignment',
          title: 'Assignment',
          points: const Value(10),
          dueAt: Value(due),
        ),
      );
  await db.customStatement(
    "INSERT INTO file_settings(key,value) VALUES('deadline_lease','session')",
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 1);
  test('offsets are UTC, skip passed and exact-now times', () {
    expect(deadlineTimes(now.add(const Duration(hours: 25)), now), [
      now.add(const Duration(hours: 1)),
      now.add(const Duration(hours: 24)),
    ]);
    expect(deadlineTimes(now.add(const Duration(hours: 24)), now), [
      now.add(const Duration(hours: 23)),
    ]);
    expect(deadlineTimes(now.add(const Duration(hours: 1)), now), isEmpty);
  });
  test(
    'complete baseline schedules two stable IDs; changed due replaces them',
    () async {
      final db = AppDatabase(NativeDatabase.memory(), now: () => now);
      addTearDown(db.close);
      await seedDeadline(db, now.add(const Duration(hours: 25)));
      final bridge = ReminderBridgeFixture();
      final service = DeadlineReminders(
        db,
        'student',
        () => true,
        bridge: bridge,
      );
      await service.reconcile();
      expect(await db.select(db.deadlineReminders).get(), isEmpty);
      await service.reconcile(trusted: true);
      final first = await db.select(db.deadlineReminders).get();
      expect(first.length, 2);
      await service.reconcile();
      expect(
        (await db.select(db.deadlineReminders).get()).map(
          (r) => r.systemAlarmId,
        ),
        first.map((r) => r.systemAlarmId),
      );
      await db
          .update(db.cachePosts)
          .write(
            CachePostsCompanion(
              dueAt: Value(now.add(const Duration(hours: 28))),
            ),
          );
      await service.reconcile(trusted: true);
      final updated = await db.select(db.deadlineReminders).get();
      expect(
        updated.every(
          (r) => !first.any((old) => old.systemAlarmId == r.systemAlarmId),
        ),
        isTrue,
      );
      expect(bridge.calls, greaterThan(0));
    },
  );
  test(
    'confirmed turn-in cancels, draft re-adds, deletion and access loss cancel',
    () async {
      final db = AppDatabase(NativeDatabase.memory(), now: () => now);
      addTearDown(db.close);
      await seedDeadline(db, now.add(const Duration(hours: 25)));
      final service = DeadlineReminders(
        db,
        'student',
        () => true,
        bridge: ReminderBridgeFixture(),
      );
      await service.reconcile(trusted: true);
      await db
          .into(db.cacheSubmissions)
          .insert(
            CacheSubmissionsCompanion.insert(
              id: 'submission',
              postId: 'post',
              studentId: 'student',
              status: const Value('turned_in'),
            ),
          );
      await service.reconcile(confirmedPostId: 'post');
      expect(await db.select(db.deadlineReminders).get(), isEmpty);
      await db
          .update(db.cacheSubmissions)
          .write(const CacheSubmissionsCompanion(status: Value('draft')));
      await service.reconcile(trusted: false, confirmedPostId: 'post');
      expect((await db.select(db.deadlineReminders).get()).length, 2);
      await db
          .update(db.cacheClassMembers)
          .write(const CacheClassMembersCompanion(status: Value('removed')));
      await service.reconcile(trusted: false);
      expect(await db.select(db.deadlineReminders).get(), isEmpty);
      await db
          .update(db.cacheClassMembers)
          .write(const CacheClassMembersCompanion(status: Value('active')));
      await service.reconcile(trusted: true);
      await db
          .update(db.cachePosts)
          .write(CachePostsCompanion(deletedAt: Value(now)));
      await service.reconcile(trusted: false);
      expect(await db.select(db.deadlineReminders).get(), isEmpty);
    },
  );
  test('incomplete pull preserves known schedules and does not infer missing submissions', () async {
    final db = AppDatabase(NativeDatabase.memory(), now: () => now);
    addTearDown(db.close);
    await seedDeadline(db, now.add(const Duration(hours: 25)));
    final service = DeadlineReminders(
      db,
      'student',
      () => true,
      bridge: ReminderBridgeFixture(),
    );
    await service.reconcile(trusted: true);
    await db.delete(db.cacheClassMembers).go();
    await service.reconcile(trusted: false);
    expect((await db.select(db.deadlineReminders).get()).length, 2);
  });
  test(
    'interrupted native scheduling keeps durable desired plan and retries',
    () async {
      final db = AppDatabase(NativeDatabase.memory(), now: () => now);
      addTearDown(db.close);
      await seedDeadline(db, now.add(const Duration(hours: 25)));
      final bridge = ReminderBridgeFixture()..fail = true;
      var current = true;
      final service = DeadlineReminders(
        db,
        'student',
        () => current,
        bridge: bridge,
      );
      await expectLater(service.reconcile(trusted: true), throwsStateError);
      final raw = await db
          .customSelect(
            "SELECT value FROM file_settings WHERE key='deadline_desired'",
          )
          .getSingle();
      expect(jsonDecode(raw.read<String>('value')), hasLength(2));
      final ids = (await db.select(db.deadlineReminders).get())
          .map((r) => r.systemAlarmId)
          .toList();
      bridge.fail = false;
      await service.reconcile();
      expect(
        (await db.select(db.deadlineReminders).get()).map(
          (r) => r.systemAlarmId,
        ),
        ids,
      );
      current = false;
      await expectLater(service.reconcile(), throwsStateError);
    },
  );
  test(
    'native channel passes account/session and does not hide failure',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(DeadlineBridge.channel, (call) async {
        calls.add(call);
        if (call.method == 'status') {
          return {'enabled': true, 'exact': false, 'error': false};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(DeadlineBridge.channel, null),
      );
      final bridge = ReminderBridgeFixture();
      const native = DeadlineBridge();
      if (!native.supported) return;
      await native.activate('student', 'session', '/private/account.sqlite');
      expect(calls.single.arguments, {
        'accountId': 'student',
        'lease': 'session',
        'database': '/private/account.sqlite',
      });
      expect((await native.status())['exact'], isFalse);
      await native.openSettings('alarm');
      await native.clear();
      expect(calls.last.method, 'clear');
      expect(bridge.supported, isTrue);
    },
  );
  test('reminder taps are identifiers only, deduplicated and deferred by exam guard', () {
    final events = PushEvents();
    addTearDown(events.dispose);
    const account = '00000000-0000-4000-8000-000000000001';
    const post = '00000000-0000-4000-8000-000000000002';
    final tap = {'accountId': account, 'postId': post, 'nonce': 'offset'};
    events.receiveReminder(tap);
    events.receiveReminder(tap);
    expect(events.take(account, allowOpen: false), isNull);
    final event = events.take(account, allowOpen: true)!;
    expect(event.id, isNull);
    expect(event.assignmentId, post);
    expect(events.take(account, allowOpen: true), isNull);
    events.receiveReminder({...tap, 'nonce': 'next'});
    expect(events.take('another account', allowOpen: true), isNull);
  });
}
