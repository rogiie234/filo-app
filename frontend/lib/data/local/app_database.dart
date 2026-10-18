import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    CacheProfiles,
    CacheClasses,
    CacheClassMembers,
    CachePosts,
    CachePostAttachments,
    CacheSubmissions,
    CacheSubmissionItems,
    CacheGrades,
    CacheQuizzes,
    CacheResults,
    CacheNotifications,
    SyncState,
    Outbox,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  Future<void> _createGradingCache() => customStatement('''
    CREATE TABLE IF NOT EXISTS instructor_grading_snapshots (
      class_id TEXT PRIMARY KEY REFERENCES cache_classes(id) ON DELETE CASCADE,
      payload TEXT NOT NULL
    )
  ''');

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createGradingCache();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await _createGradingCache();
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> saveProfile(CacheProfilesCompanion profile) =>
      into(cacheProfiles).insertOnConflictUpdate(profile);

  Future<CacheProfile?> readProfile(String id) => (select(
    cacheProfiles,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
}
