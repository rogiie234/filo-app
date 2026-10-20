import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../data/class_member_repository.dart';
import '../data/class_remote.dart';
import '../data/class_repository.dart';
import '../domain/prototype_models.dart';
import '../domain/class_banner.dart';

/// Existing card widgets get their display values from SQLite, including the
/// instructor's cached profile and this student's membership status.
// Cancel SQLite subscriptions when account screens unmount. Keeping paused
// query streams alive can prevent Drift from completing database.close().
final classCardsProvider = StreamProvider.autoDispose<List<ClassRoom>>((
  ref,
) async* {
  final repository = await ref.watch(classRepositoryProvider.future);
  if (repository == null) {
    yield [];
    return;
  }
  final db = repository.database;
  final classes = db.cacheClasses;
  final profiles = db.cacheProfiles;
  final members = db.cacheClassMembers;
  final query =
      db.select(classes).join([
          leftOuterJoin(profiles, profiles.id.equalsExp(classes.ownerId)),
          leftOuterJoin(
            members,
            members.classId.equalsExp(classes.id) &
                members.studentId.equals(repository.userId),
          ),
        ])
        ..where(
          classes.deletedAt.isNull() &
              (classes.ownerId.equals(repository.userId) |
                  members.status.isIn(['pending', 'active'])),
        )
        ..orderBy([
          OrderingTerm.asc(classes.section),
          OrderingTerm.asc(classes.id),
        ]);
  yield* query.watch().map(
    (rows) => rows.map((row) {
      final room = row.readTable(classes);
      final owner = row.readTableOrNull(profiles);
      final member = row.readTableOrNull(members);
      return ClassRoom(
        id: room.id,
        section: room.section,
        course: room.course,
        instructor: owner?.displayName ?? 'Instructor',
        color: classBannerColor(room.bannerColor),
        pending:
            room.ownerId != repository.userId && member?.status == 'pending',
        archived: room.archivedAt != null,
        schoolYear: room.schoolYear,
        joinCode: room.joinCode,
        instructorPhotoUrl: owner?.googlePhotoUrl,
        instructorAvatarPath: owner?.avatarPath,
        bannerPath: room.bannerPath,
      );
    }).toList(),
  );
});

final classRemoteProvider = Provider<ClassRemote>(
  (ref) => SupabaseClassRemote(ref.watch(supabaseClientProvider)),
);

final classRepositoryProvider = FutureProvider<ClassRepository?>((ref) async {
  final userId = await ref.watch(verifiedUserIdProvider.future);
  final database = await ref.watch(accountDatabaseProvider.future);
  if (userId == null || database == null || !ref.mounted) return null;
  return ClassRepository(database, ref.watch(classRemoteProvider), userId);
});

final classMemberRepositoryProvider = FutureProvider<ClassMemberRepository?>((
  ref,
) async {
  final classes = await ref.watch(classRepositoryProvider.future);
  return classes == null ? null : ClassMemberRepository(classes);
});

final classesProvider = StreamProvider.autoDispose<List<CacheClassesData>>((
  ref,
) async* {
  final repository = await ref.watch(classRepositoryProvider.future);
  if (repository == null) {
    yield [];
    return;
  }
  yield* repository.watchClasses();
});

final classMembersProvider = StreamProvider.autoDispose
    .family<List<CacheClassMember>, String>((ref, id) async* {
      final repository = await ref.watch(classMemberRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchMembers(id);
    });

final classStudentsProvider = StreamProvider.autoDispose
    .family<List<ClassStudent>, String>((ref, id) async* {
      final repository = await ref.watch(classMemberRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchStudents(id);
    });

final pendingClassRequestsProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) async* {
      final repository = await ref.watch(classRepositoryProvider.future);
      if (repository == null) {
        yield {};
        return;
      }
      final db = repository.database;
      final members = db.cacheClassMembers;
      final count = members.id.count();
      final query = db.selectOnly(members)
        ..addColumns([members.classId, count])
        ..where(members.status.equals('pending'))
        ..groupBy([members.classId]);
      yield* query.watch().map(
        (rows) => {
          for (final row in rows)
            row.read(members.classId)!: row.read(count) ?? 0,
        },
      );
    });

final classSyncProvider = AsyncNotifierProvider<ClassSync, void>(ClassSync.new);

class ClassSync extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final coordinator = await ref.read(syncCoordinatorProvider.future);
      if (ref.mounted) await coordinator?.run();
    });
    if (ref.mounted) state = result;
  }
}

// Mounted by the signed-in Classes screen and retained while opening a class.
final classSyncLifecycleProvider = Provider.autoDispose<void>((ref) {
  ref.watch(syncLifecycleProvider);
});

// Owner-visible tombstones are cached separately from normal class cards.
final deletedClassesProvider =
    StreamProvider.autoDispose<List<CacheClassesData>>((ref) async* {
      final repository = await ref.watch(classRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      final db = repository.database;
      yield* (db.select(db.cacheClasses)
            ..where(
              (c) =>
                  c.ownerId.equals(repository.userId) & c.deletedAt.isNotNull(),
            )
            ..orderBy([(c) => OrderingTerm.desc(c.deletedAt)]))
          .watch();
    });
