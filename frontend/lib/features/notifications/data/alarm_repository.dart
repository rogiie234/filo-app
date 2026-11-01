import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';

/// Account-local storage only; saving never schedules an Android notification.
class AlarmRepository {
  AlarmRepository(this.db, this.isCurrent);
  final AppDatabase db;
  final bool Function() isCurrent;

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
