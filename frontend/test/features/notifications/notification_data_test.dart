import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:filo/features/notifications/data/alarm_repository.dart';
import 'package:filo/features/notifications/data/inbox_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> seed(AppDatabase db, String user) async {
  await db.saveProfile(
    CacheProfilesCompanion.insert(
      id: user,
      role: 'student',
      displayName: 'Fixture',
    ),
  );
  for (final id in ['a', 'b']) {
    await db
        .into(db.cacheNotifications)
        .insert(
          CacheNotificationsCompanion.insert(
            id: id,
            recipientId: user,
            type: 'announcement',
            title: id,
            createdAt: Value(DateTime.utc(2026, 11, 1)),
          ),
        );
  }
}

void main() {
  test(
    'alarm constraints reject invalid values and duplicate system IDs',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final alarms = AlarmRepository(db, () => true);
      await expectLater(
        alarms.saveAlarm(
          StudyAlarmsCompanion.insert(
            id: 'bad',
            subject: 'Study',
            minuteOfDay: 1440,
            repeatDays: 1,
          ),
        ),
        throwsA(anything),
      );
      await alarms.saveAlarm(
        StudyAlarmsCompanion.insert(
          id: 'valid',
          subject: 'Study',
          minuteOfDay: 510,
          repeatDays: 1,
        ),
      );
      await alarms.saveSlot(
        AlarmSlotsCompanion.insert(
          alarmId: 'valid',
          weekday: 1,
          systemAlarmId: 1,
        ),
      );
      await expectLater(
        alarms.saveSlot(
          AlarmSlotsCompanion.insert(
            alarmId: 'valid',
            weekday: 2,
            systemAlarmId: 1,
          ),
        ),
        throwsA(anything),
      );
      await expectLater(
        alarms.saveSlot(
          AlarmSlotsCompanion.insert(
            alarmId: 'valid',
            weekday: 8,
            systemAlarmId: 2,
          ),
        ),
        throwsA(anything),
      );
      await expectLater(
        alarms.saveReminder(
          DeadlineRemindersCompanion.insert(
            postId: 'post',
            fireAt: DateTime.utc(2026),
            systemAlarmId: 0,
          ),
        ),
        throwsA(anything),
      );
    },
  );

  test('all four tables survive reopening and account switching', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-notifications-',
    );
    final manager = UserDatabaseManager(
      directoryProvider: () async => directory,
    );
    addTearDown(() async {
      await manager.close();
      await directory.delete(recursive: true);
    });
    var db = await manager.openForUser('student-a');
    await seed(db, 'student-a');
    var alarms = AlarmRepository(db, () => true);
    final fire = DateTime.utc(2026, 11, 2);
    await alarms.saveReminder(
      DeadlineRemindersCompanion.insert(
        postId: 'post',
        fireAt: fire,
        systemAlarmId: 1,
      ),
    );
    await alarms.saveReminder(
      DeadlineRemindersCompanion.insert(
        postId: 'post',
        fireAt: fire.add(const Duration(hours: 23)),
        systemAlarmId: 2,
      ),
    );
    await alarms.saveAlarm(
      StudyAlarmsCompanion.insert(
        id: 'alarm',
        subject: 'Study',
        minuteOfDay: 510,
        repeatDays: 1,
        linkedClassId: const Value('uncached-class'),
        linkedDeckId: const Value('uncached-deck'),
      ),
    );
    await alarms.saveSlot(
      AlarmSlotsCompanion.insert(
        alarmId: 'alarm',
        weekday: 1,
        systemAlarmId: 3,
      ),
    );
    await InboxRepository(db, 'student-a', () => true).markRead('a');
    final other = await manager.openForUser('student-b');
    expect(await other.select(other.cacheNotifications).get(), isEmpty);
    expect(await AlarmRepository(other, () => true).readAlarms(), isEmpty);
    expect(await other.select(other.deadlineReminders).get(), isEmpty);
    expect(await other.select(other.alarmSlots).get(), isEmpty);
    expect(await other.select(other.outbox).get(), isEmpty);
    db = await manager.openForUser('student-a');
    alarms = AlarmRepository(db, () => true);
    expect(
      await InboxRepository(
        db,
        'student-a',
        () => true,
      ).watchUnreadCount().first,
      1,
    );
    expect((await alarms.readReminders()).map((r) => r.fireAt.toUtc()), [
      fire,
      fire.add(const Duration(hours: 23)),
    ]);
    expect((await alarms.readAlarms()).single.minuteOfDay, 510);
    expect((await alarms.readSlots('alarm')).single.systemAlarmId, 3);
    expect((await db.select(db.outbox).get()).single.status, 'pending');
    await alarms.deleteAlarm('alarm');
    expect(await alarms.readSlots('alarm'), isEmpty);
  });

  test(
    'read streams, stable marks, mark-all snapshot and account guard',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, 'user');
      var current = true;
      final repo = InboxRepository(db, 'user', () => current);
      final counts = <int>[];
      final subscription = repo.watchUnreadCount().listen(counts.add);
      addTearDown(subscription.cancel);
      expect((await repo.watchInbox().first).map((n) => n.id), ['b', 'a']);
      await repo.markRead('a');
      final first = (await db.select(db.outbox).get()).single.payload;
      await repo.markRead('a');
      expect((await db.select(db.outbox).get()).single.payload, first);
      await repo.markAllRead();
      expect(await repo.watchUnreadCount().first, 0);
      await Future<void>.delayed(Duration.zero);
      expect(counts, contains(0));
      await repo.markRead('missing');
      await db
          .into(db.cacheNotifications)
          .insert(
            CacheNotificationsCompanion.insert(
              id: 'later',
              recipientId: 'user',
              type: 'material',
              title: 'Later',
            ),
          );
      expect(await repo.watchUnreadCount().first, 1);
      expect((await db.select(db.outbox).get()).length, 2);
      await Future<void>.delayed(Duration.zero);
      expect(counts, contains(1));
      current = false;
      await expectLater(repo.markAllRead(), throwsStateError);
    },
  );

  test('enqueue failure rolls back local marks and mark-all queue', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db, 'user');
    await db.customStatement('''CREATE TRIGGER fail_read BEFORE INSERT ON outbox
      WHEN NEW.id='read:b' BEGIN SELECT RAISE(ABORT,'fixture'); END''');
    await expectLater(
      InboxRepository(db, 'user', () => true).markAllRead(),
      throwsA(anything),
    );
    expect(
      (await db.select(db.cacheNotifications).get()).every(
        (n) => n.readAt == null,
      ),
      isTrue,
    );
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('v12 migration retains inbox, notebook and queued reads', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-notification-upgrade-',
    );
    final file = File('${directory.path}/upgrade.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      await seed(db, 'user');
      await InboxRepository(db, 'user', () => true).markRead('a');
      await db
          .into(db.notebooks)
          .insert(
            NotebooksCompanion.insert(
              id: 'book',
              name: 'Saved',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
              lastOpenedAt: DateTime.utc(2026),
            ),
          );
      await db.customStatement('DROP TABLE alarm_slots');
      await db.customStatement('DROP TABLE study_alarms');
      await db.customStatement('DROP TABLE deadline_reminders');
      await db.customStatement('PRAGMA user_version=12');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect((await db.select(db.cacheNotifications).get()).length, 2);
      expect((await db.select(db.outbox).get()).single.id, 'read:a');
      expect((await db.select(db.notebooks).get()).single.id, 'book');
      expect(await db.select(db.studyAlarms).get(), isEmpty);
      expect(await db.select(db.deadlineReminders).get(), isEmpty);
      expect(await db.select(db.alarmSlots).get(), isEmpty);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
