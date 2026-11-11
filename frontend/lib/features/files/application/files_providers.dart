import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../data/file_storage.dart';
import '../data/files_repository.dart';
import '../data/download_manager.dart';

final filesRepositoryProvider = FutureProvider<FilesRepository?>((ref) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  final id = await ref.watch(verifiedUserIdProvider.future);
  if (db == null || id == null || !ref.mounted) {
    return null;
  }
  final storage = await FileStorage.forAccount(
    id,
    isCurrent: () =>
        ref.mounted &&
        ref.read(supabaseClientProvider).auth.currentUser?.id == id,
  );
  if (!ref.mounted) {
    return null;
  }
  final repository = FilesRepository(db, storage);
  await repository.recoverInterruptedDeletes();
  return repository;
});

class LibrarySnapshot {
  List<LocalFileRecord>? files;
  List<LocalFolderRecord>? folders;
}

// Retain display metadata, not SQLite subscriptions, across tab navigation.
final librarySnapshotProvider = Provider<LibrarySnapshot>((ref) {
  ref.watch(verifiedUserIdProvider);
  ref.watch(accountDatabaseProvider);
  return LibrarySnapshot();
});

final localFilesProvider = StreamProvider.autoDispose<List<LocalFileRecord>>((
  ref,
) async* {
  final snapshot = ref.watch(librarySnapshotProvider);
  final files = await ref.watch(filesRepositoryProvider.future);
  if (!ref.mounted) return;
  if (files == null) {
    yield [];
    return;
  }
  yield* files.watchFiles().map((rows) {
    snapshot.files = List.unmodifiable(rows);
    return rows;
  });
});
final localFoldersProvider =
    StreamProvider.autoDispose<List<LocalFolderRecord>>((ref) async* {
      final snapshot = ref.watch(librarySnapshotProvider);
      final files = await ref.watch(filesRepositoryProvider.future);
      if (!ref.mounted) return;
      if (files == null) {
        yield [];
        return;
      }
      yield* files.watchFolders().map((rows) {
        snapshot.folders = List.unmodifiable(rows);
        return rows;
      });
    });
final downloadManagerProvider = FutureProvider<DownloadManager?>((ref) async {
  final files = await ref.watch(filesRepositoryProvider.future);
  final user = await ref.watch(verifiedUserIdProvider.future);
  if (files == null || user == null || !ref.mounted) {
    return null;
  }
  final client = ref.watch(supabaseClientProvider);
  final manager = DownloadManager(
    files,
    client,
    () => ref.mounted && client.auth.currentUser?.id == user,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

class ClassFileEntry {
  ClassFileEntry(this.post, this.attachment);
  final CachePost post;
  final CachePostAttachment attachment;
}

// Retain display data without retaining paused SQLite subscriptions.
final classFileSnapshotsProvider = Provider<Map<String, List<ClassFileEntry>>>((
  ref,
) {
  ref.watch(verifiedUserIdProvider);
  ref.watch(accountDatabaseProvider);
  return {};
});

final classFilesProvider = StreamProvider.autoDispose
    .family<List<ClassFileEntry>, String>((ref, classId) async* {
      final snapshots = ref.watch(classFileSnapshotsProvider);
      final db = await ref.watch(accountDatabaseProvider.future);
      if (!ref.mounted) return;
      if (db == null) {
        yield [];
        return;
      }
      final a = db.cachePostAttachments, p = db.cachePosts;
      final query = db.select(a).join([innerJoin(p, p.id.equalsExp(a.postId))])
        ..where(
          p.classId.equals(classId) &
              p.deletedAt.isNull() &
              a.deletedAt.isNull() &
              a.kind.equals('file'),
        )
        ..orderBy([
          OrderingTerm.desc(p.createdAt),
          OrderingTerm.desc(a.createdAt),
          OrderingTerm.asc(a.id),
        ]);
      yield* query.watch().map((rows) {
        final entries = rows
            .map((r) => ClassFileEntry(r.readTable(p), r.readTable(a)))
            .toList();
        snapshots[classId] = List.unmodifiable(entries);
        return entries;
      });
    });
