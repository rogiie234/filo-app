import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import 'class_remote.dart';

// Drift's generated JSON uses camelCase keys and epoch milliseconds for dates.
Map<String, dynamic> _cacheJson(ClassRow row) => {
  for (final entry in row.entries)
    entry.key.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (m) => m[1]!.toUpperCase(),
    ): entry.key.endsWith('_at') && entry.value != null
        ? DateTime.parse(entry.value as String).millisecondsSinceEpoch
        : entry.value,
};

class ClassRepository {
  ClassRepository(this.database, this.remote, this.userId);
  final AppDatabase database;
  final ClassRemote remote;
  final String userId;
  Future<void>? _pending;

  Stream<List<CacheClassesData>> watchClasses() =>
      (database.select(database.cacheClasses)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([
              (c) => OrderingTerm.asc(c.section),
              (c) => OrderingTerm.asc(c.id),
            ]))
          .watch();

  Future<void> sync() =>
      _pending ??= _pull().whenComplete(() => _pending = null);

  Future<void> _pull() async {
    final db = database;
    final cursors = {
      for (final row in await db.select(db.syncState).get())
        row.syncedTableName: row.lastSyncedAt,
    };
    // Inclusive boundaries replay equal timestamps; never use the phone clock.
    final changes = <String, List<ClassRow>>{
      'class_members': await remote.read(
        'class_members',
        since: cursors['class_members'],
      ),
      'classes': await remote.read('classes', since: cursors['classes']),
    };
    final inventory = await remote.read('classes', inventory: true);
    final visible = inventory
        .where((r) => r['deleted_at'] == null)
        .map((r) => r['id'] as String)
        .toSet();
    final cached = (await db.select(db.cacheClasses).get())
        .map((r) => r.id)
        .toSet();
    final changedIds = changes['classes']!.map((r) => r['id']).toSet();
    // Joining can expose an unchanged class older than the current cursor.
    for (final id in visible.difference(cached)) {
      if (!changedIds.contains(id)) {
        changes['classes']!.addAll(await remote.read('classes', id: id));
      }
    }
    // RLS limits profiles to this account and related people. Load references
    // before inserting classes/members so SQLite foreign keys remain enforced.
    final profiles = await remote.read('profiles');
    final revoked = changes['class_members']!
        .where(
          (r) =>
              r['student_id'] == userId &&
              (r['deleted_at'] != null ||
                  !['pending', 'active'].contains(r['status'])),
        )
        .map((r) => r['class_id'])
        .toSet();

    await db.transaction(() async {
      for (final profile in profiles) {
        await db
            .into(db.cacheProfiles)
            .insertOnConflictUpdate(CacheProfile.fromJson(_cacheJson(profile)));
      }
      for (final row in changes['classes']!) {
        if (!visible.contains(row['id']) ||
            row['deleted_at'] != null ||
            (row['owner_id'] != userId && revoked.contains(row['id']))) {
          continue;
        }
        await db
            .into(db.cacheClasses)
            .insertOnConflictUpdate(CacheClassesData.fromJson(_cacheJson(row)));
      }
      for (final row in await db.select(db.cacheClasses).get()) {
        if (!visible.contains(row.id) ||
            (row.ownerId != userId && revoked.contains(row.id))) {
          await (db.delete(
            db.cacheClasses,
          )..where((c) => c.id.equals(row.id))).go();
        }
      }
      final classIds = (await db.select(db.cacheClasses).get())
          .map((c) => c.id)
          .toSet();
      for (final row in changes['class_members']!) {
        if (row['deleted_at'] != null) {
          await (db.delete(
            db.cacheClassMembers,
          )..where((m) => m.id.equals(row['id'] as String))).go();
        } else if (classIds.contains(row['class_id'])) {
          await db
              .into(db.cacheClassMembers)
              .insertOnConflictUpdate(
                CacheClassMember.fromJson(_cacheJson(row)),
              );
        }
      }
      // Commit checkpoints with the cache. A failed pull/write advances nothing.
      for (final entry in changes.entries) {
        var cursor = cursors[entry.key];
        for (final row in entry.value) {
          final updated = DateTime.parse(row['updated_at'] as String);
          if (cursor == null || updated.isAfter(cursor)) cursor = updated;
        }
        await db
            .into(db.syncState)
            .insertOnConflictUpdate(
              SyncStateCompanion.insert(
                syncedTableName: entry.key,
                lastSyncedAt: Value(cursor),
              ),
            );
      }
    });
  }

  Future<dynamic> mutate(String function, ClassRow parameters) async {
    final result = await remote.call(function, parameters);
    // Any older pull must finish before fetching the result of this mutation.
    await _pending;
    await sync();
    return result;
  }

  Future<dynamic> requestJoin(String code) =>
      mutate('request_join', {'p_code': code.trim().toUpperCase()});

  /// The caller retains this server response and syncs before opening Stream.
  /// Retaining it prevents a second insert if only the following pull fails.
  Future<ClassRow> createClass({
    required String course,
    required String section,
    required String schoolYear,
    String? bannerColor,
  }) {
    if (course.trim().isEmpty ||
        course.trim().length > 120 ||
        section.trim().isEmpty ||
        section.trim().length > 60 ||
        schoolYear.trim().isEmpty ||
        schoolYear.trim().length > 20) {
      throw ArgumentError('Valid class details are required');
    }
    return remote.createClass({
      'owner_id': userId,
      'course': course.trim(),
      'section': section.trim(),
      'school_year': schoolYear.trim(),
      'banner_color': bannerColor,
    });
  }

  Future<dynamic> leave(String id) => mutate('leave_class', {'p_class': id});
  Future<dynamic> archive(String id) =>
      mutate('archive_class', {'p_class': id});
  Future<dynamic> restore(String id) =>
      mutate('restore_class', {'p_class': id});
  Future<dynamic> delete(String id, String section) =>
      mutate('delete_class', {'p_class': id, 'p_section': section});
  Future<dynamic> restoreDeleted(String id) =>
      mutate('restore_deleted_class', {'p_class': id});
}
