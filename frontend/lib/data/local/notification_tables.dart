import 'package:drift/drift.dart';

class DeadlineReminders extends Table {
  TextColumn get postId => text()();
  DateTimeColumn get fireAt => dateTime()();
  IntColumn get systemAlarmId =>
      integer().unique().check(systemAlarmId.isBetweenValues(1, 2147483647))();
  @override
  Set<Column> get primaryKey => {postId, fireAt};
}

class StudyAlarms extends Table {
  TextColumn get id => text()();
  TextColumn get subject =>
      text().check(subject.trim().length.isBiggerThanValue(0))();
  IntColumn get minuteOfDay =>
      integer().check(minuteOfDay.isBetweenValues(0, 1439))();
  // ISO weekdays: bit zero is Monday; zero means a one-time alarm.
  IntColumn get repeatDays =>
      integer().check(repeatDays.isBetweenValues(0, 127))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get linkedClassId => text().nullable()();
  TextColumn get linkedDeckId => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class AlarmSlots extends Table {
  TextColumn get alarmId =>
      text().references(StudyAlarms, #id, onDelete: KeyAction.cascade)();
  // Zero is the one-time slot; 1..7 are ISO weekdays.
  IntColumn get weekday => integer().check(weekday.isBetweenValues(0, 7))();
  IntColumn get systemAlarmId =>
      integer().unique().check(systemAlarmId.isBetweenValues(1, 2147483647))();
  @override
  Set<Column> get primaryKey => {alarmId, weekday};
}
