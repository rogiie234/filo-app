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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> saveProfile(CacheProfilesCompanion profile) =>
      into(cacheProfiles).insertOnConflictUpdate(profile);

  Future<CacheProfile?> readProfile(String id) => (select(
    cacheProfiles,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
}
