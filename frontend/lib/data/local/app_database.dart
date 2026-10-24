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
    LocalFolders,
    LocalFiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 8;

  Future<void> _createExamSubmissionIntent() => customStatement('''
    CREATE TABLE IF NOT EXISTS exam_submission_intent (
      session_id TEXT PRIMARY KEY REFERENCES exam_active_attempt(session_id) ON DELETE CASCADE
    )
  ''');

  Future<void> _createStudentQuizCache() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS student_quiz_catalog (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL REFERENCES cache_classes(id) ON DELETE CASCADE,
        payload TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS student_quiz_catalog_state (
        id INTEGER PRIMARY KEY CHECK (id = 1)
      )
    ''');
  }

  Future<void> _createExamStorage() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS exam_active_attempt (
        session_id TEXT PRIMARY KEY, quiz_id TEXT NOT NULL,
        started_at TEXT NOT NULL, deadline_at TEXT NOT NULL,
        server_now TEXT NOT NULL, questions TEXT NOT NULL,
        saved_at TEXT NOT NULL, device_fetch_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS exam_local_answers (
        session_id TEXT NOT NULL REFERENCES exam_active_attempt(session_id) ON DELETE CASCADE,
        question_id TEXT NOT NULL, option_id TEXT, bool_answer INTEGER,
        text_answer TEXT, updated_at TEXT NOT NULL, sent INTEGER NOT NULL DEFAULT 0,
        revision INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (session_id, question_id),
        CHECK (bool_answer IS NULL OR bool_answer IN (0,1)), CHECK (sent IN (0,1))
      )
    ''');
  }

  Future<void> _createFileSyncState() async {
    final columns = await customSelect('PRAGMA table_info(drive_backup_jobs)')
        .get();
    if (!columns.any((row) => row.read<String>('name') == 'local_file_id')) {
      // Keep existing resumable IDs/session keys while making backup identity
      // per local file, so equal bytes with different names remain distinct.
      await customStatement(
        'ALTER TABLE drive_backup_jobs RENAME TO drive_backup_jobs_legacy',
      );
      await _createDriveBackup();
      await customStatement(
        'INSERT INTO drive_backup_jobs(id,name,local_path,size,digest,file_id,status,uploaded,completed_at,elapsed_ms) SELECT id,name,local_path,size,digest,file_id,status,uploaded,completed_at,elapsed_ms FROM drive_backup_jobs_legacy',
      );
      await customStatement('DROP TABLE drive_backup_jobs_legacy');
    }
    await customStatement(
      'CREATE TABLE IF NOT EXISTS file_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_payloads (table_name TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(table_name,id))',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS sync_cursors (table_name TEXT PRIMARY KEY, stamp TEXT NOT NULL)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS outbox_schedule (id TEXT PRIMARY KEY, next_at TEXT, lease_until TEXT)',
    );
  }

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
        digest TEXT NOT NULL,
        local_file_id TEXT UNIQUE,
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

  Future<void> _createInstructorQuizCache() async {
    await customStatement(
      "CREATE TABLE IF NOT EXISTS instructor_quiz_lists (class_id TEXT PRIMARY KEY REFERENCES cache_classes(id) ON DELETE CASCADE, payload TEXT NOT NULL)",
    );
    await customStatement(
      "CREATE TABLE IF NOT EXISTS instructor_quiz_details (id TEXT PRIMARY KEY, class_id TEXT NOT NULL REFERENCES cache_classes(id) ON DELETE CASCADE, payload TEXT NOT NULL)",
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createStudentQuizCache();
      await _createExamStorage();
      await _createExamSubmissionIntent();
      await _createInstructorQuizCache();
      await _createGradingCache();
      await _createDriveBackup();
      await _createFileSyncState();
    },
    onUpgrade: (m, from, to) async {
      if (from < 7) await _createStudentQuizCache();
      if (from < 6) await _createExamStorage();
      if (from < 8) await _createExamSubmissionIntent();
      if (from < 5) await _createInstructorQuizCache();
      if (from < 2) await _createGradingCache();
      if (from < 3) await _createDriveBackup();
      if (from < 4) {
        await m.createTable(localFolders);
        await m.createTable(localFiles);
        for (final index in allSchemaEntities.whereType<Index>()) {
          if (index.entityName.startsWith('local_')) await m.createIndex(index);
        }
        await _createFileSyncState();
      }
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> saveProfile(CacheProfilesCompanion profile) =>
      into(cacheProfiles).insertOnConflictUpdate(profile);

  Future<CacheProfile?> readProfile(String id) => (select(
    cacheProfiles,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
}
