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
  int get schemaVersion => 3;

  Future<void> _createDriveBackup() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS drive_backup_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        enabled INTEGER NOT NULL DEFAULT 0,
        wifi_only INTEGER NOT NULL DEFAULT 1,
        google_id TEXT,
        folder_id TEXT,
        last_success TEXT
      )
    ''');
    await customStatement(
      'INSERT OR IGNORE INTO drive_backup_settings (id) VALUES (1)',
    );
    await customStatement('''
      CREATE TABLE IF NOT EXISTS drive_backup_jobs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        local_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        digest TEXT NOT NULL UNIQUE,
        file_id TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        uploaded INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        elapsed_ms INTEGER
      )
    ''');
  }

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
      await _createDriveBackup();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await _createGradingCache();
      if (from < 3) await _createDriveBackup();
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> saveProfile(CacheProfilesCompanion profile) =>
      into(cacheProfiles).insertOnConflictUpdate(profile);

  Future<CacheProfile?> readProfile(String id) => (select(
    cacheProfiles,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
}
