import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/notifications/deadline_reminders.dart';

import '../../../data/local/app_database.dart';

class StudySchedulingFailure implements Exception {}

/// Raw storage methods remain available; study mutations also reconcile Android.
class AlarmRepository {
  AlarmRepository(
    this.db,
    this.isCurrent, {
    this.userId = '',
    this.bridge = const DeadlineBridge(),
  });
  final AppDatabase db;
  final bool Function() isCurrent;
  final String userId;
  final DeadlineBridge bridge;

  Stream<List<StudyAlarm>> watchAlarms() =>
      (db.select(db.studyAlarms)..orderBy([
            (a) => OrderingTerm.asc(a.minuteOfDay),
            (a) => OrderingTerm.asc(a.id),
          ]))
          .watch()
          .map((rows) {
            if (!isCurrent()) throw StateError('Account changed');
            return rows;
          });

  Future<String?> setting(String key) async =>
      (await db
              .customSelect(
                'SELECT value FROM file_settings WHERE key=?',
                variables: [Variable(key)],
              )
              .getSingleOrNull())
          ?.read<String>('value');

  Future<void> setSetting(String key, String value) => _account(
    () => db.customStatement(
      'INSERT OR REPLACE INTO file_settings(key,value) VALUES(?,?)',
      [key, value],
    ),
  );

  Future<void> saveStudy({
    required String id,
    required String subject,
    required int minute,
    required int days,
    bool enabled = true,
    String? classId,
    String? deckId,
  }) async {
    if (subject.trim().isEmpty ||
        subject.trim().length > 120 ||
        minute < 0 ||
        minute > 1439 ||
        days < 0 ||
        days > 127 ||
        (classId != null && deckId != null))
      throw ArgumentError('Invalid study alarm');
    await _account(() async {
      await db
          .into(db.studyAlarms)
          .insertOnConflictUpdate(
            StudyAlarmsCompanion.insert(
              id: id,
              subject: subject.trim(),
              minuteOfDay: minute,
              repeatDays: days,
              enabled: Value(enabled),
              linkedClassId: Value(classId),
              linkedDeckId: Value(deckId),
            ),
          );
      final wanted = days == 0
          ? [0]
          : [
              for (var day = 1; day <= 7; day++)
                if ((days & (1 << (day - 1))) != 0) day,
            ];
      final slots = await readSlots(id);
      var next = int.tryParse(await setting('study_next_id') ?? '') ?? 1;
      final max = await db
          .customSelect(
            'SELECT coalesce(max(system_alarm_id),0) AS n FROM alarm_slots',
          )
          .getSingle();
      if (next <= max.read<int>('n')) next = max.read<int>('n') + 1;
      for (final slot in slots) {
        if (!wanted.contains(slot.weekday))
          await (db.delete(db.alarmSlots)..where(
                (s) => s.alarmId.equals(id) & s.weekday.equals(slot.weekday),
              ))
              .go();
      }
      for (final day in wanted) {
        if (slots.any((s) => s.weekday == day)) continue;
        if (next > 2147483647) throw StateError('Alarm IDs exhausted');
        await db
            .into(db.alarmSlots)
            .insert(
              AlarmSlotsCompanion.insert(
                alarmId: id,
                weekday: day,
                systemAlarmId: next++,
              ),
            );
      }
      await setSetting('study_next_id', '$next');
      final once = nextStudyOnce(db.now().toLocal(), minute);
      await setSetting(
        'study_alarm:$id',
        jsonEncode({
          'revision': const Uuid().v4(),
          'savedAt': db.now().millisecondsSinceEpoch,
          'onceDate':
              '${once.year.toString().padLeft(4, '0')}-${once.month.toString().padLeft(2, '0')}-${once.day.toString().padLeft(2, '0')}',
        }),
      );
    });
    await reconcileStudy();
  }

  Future<void> toggleStudy(StudyAlarm alarm, bool enabled) => saveStudy(
    id: alarm.id,
    subject: alarm.subject,
    minute: alarm.minuteOfDay,
    days: alarm.repeatDays,
    enabled: enabled,
    classId: alarm.linkedClassId,
    deckId: alarm.linkedDeckId,
  );

  Future<void> deleteStudy(String id) async {
    await _account(() async {
      await (db.delete(db.studyAlarms)..where((a) => a.id.equals(id))).go();
      await db.customStatement('DELETE FROM file_settings WHERE key=?', [
        'study_alarm:$id',
      ]);
    });
    await reconcileStudy();
  }

  Future<void> reconcileStudy() async {
    if (!bridge.supported || !isCurrent()) return;
    try {
      final lease = await setting('deadline_lease');
      if (lease == null || userId.isEmpty)
        throw StateError('Alarm session unavailable');
      final completed = await bridge.reconcileStudy(userId, lease);
      await _account(() async {
        for (final item in completed) {
          final meta = await setting('study_alarm:${item['id']}');
          if (meta != null &&
              jsonDecode(meta)['revision'] == item['revision']) {
            await (db.update(db.studyAlarms)..where(
                  (a) =>
                      a.id.equals(item['id'] as String) &
                      a.repeatDays.equals(0),
                ))
                .write(const StudyAlarmsCompanion(enabled: Value(false)));
          }
        }
        await setSetting('study_error', '');
      });
    } catch (_) {
      if (isCurrent())
        await setSetting(
          'study_error',
          'Saved, but alarm scheduling failed. Retry.',
        );
      throw StudySchedulingFailure();
    }
  }

  Future<T> _account<T>(Future<T> Function() action) =>
      db.transaction(() async {
        if (!isCurrent()) throw StateError('Account changed');
        final value = await action();
        if (!isCurrent()) throw StateError('Account changed');
        return value;
      });

  Future<void> saveReminder(DeadlineRemindersCompanion row) =>
      _account(() async {
        await db.into(db.deadlineReminders).insertOnConflictUpdate(row);
      });
  Future<List<DeadlineReminder>> readReminders() => _account(
    () => (db.select(
      db.deadlineReminders,
    )..orderBy([(r) => OrderingTerm.asc(r.fireAt)])).get(),
  );
  Future<void> saveAlarm(StudyAlarmsCompanion row) => _account(() async {
    await db.into(db.studyAlarms).insertOnConflictUpdate(row);
  });
  Future<List<StudyAlarm>> readAlarms() =>
      _account(() => db.select(db.studyAlarms).get());
  Future<void> saveSlot(AlarmSlotsCompanion row) => _account(() async {
    await db.into(db.alarmSlots).insertOnConflictUpdate(row);
  });
  Future<List<AlarmSlot>> readSlots(String alarmId) => _account(
    () =>
        (db.select(db.alarmSlots)
              ..where((s) => s.alarmId.equals(alarmId))
              ..orderBy([(s) => OrderingTerm.asc(s.weekday)]))
            .get(),
  );
  Future<void> deleteAlarm(String id) => _account(() async {
    await (db.delete(db.studyAlarms)..where((a) => a.id.equals(id))).go();
  });
}

DateTime nextStudyOnce(DateTime now, int minute) {
  DateTime occurrence(int day) {
    var value = DateTime(now.year, now.month, day, minute ~/ 60, minute % 60);
    // Match native DST gap handling: use the first valid local minute.
    if (value.hour * 60 + value.minute != minute) {
      while (true) {
        final before = value.subtract(const Duration(minutes: 1));
        if (before.day != value.day ||
            before.hour * 60 + before.minute < minute)
          break;
        value = before;
      }
    }
    return value;
  }

  var next = occurrence(now.day);
  if (!next.isAfter(now)) next = occurrence(now.day + 1);
  return next;
}
