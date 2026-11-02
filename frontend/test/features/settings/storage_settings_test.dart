import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/settings/application/storage_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedStorage extends StorageRepository {
  DelayedStorage(super.files);
  final result = Completer<StorageUsage>();
  bool Function()? current;
  @override
  Future<StorageUsage> load() async => const StorageUsage(10, 5);
  @override
  Future<StorageUsage> clear(bool Function() isCurrent) {
    current = isCurrent;
    return result.future;
  }
}

class FailedRescanStorage extends FileStorage {
  FailedRescanStorage(super.root);
  bool cleared = false;
  @override
  Future<int> clearTemporary({bool Function()? isCurrent}) async {
    final removed = await super.clearTemporary(isCurrent: isCurrent);
    cleared = true;
    return removed;
  }

  @override
  Future<StorageUsage> usage() {
    if (cleared) throw const FileProblem('fixture failed rescan');
    return super.usage();
  }
}

void main() {
  late Directory root;
  late FileStorage storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('filo-storage-');
    storage = FileStorage(Directory('${root.path}/account-a'));
    await storage.root.create();
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<File> write(String relative, int bytes) async {
    final file = File('${root.path}/$relative');
    await file.parent.create(recursive: true);
    return file.writeAsBytes(List.filled(bytes, 7));
  }

  test('temporary reservation rejects paths outside its direct directory', () {
    for (final name in ['', '..', '../blobs/file', 'nested/file']) {
      expect(() => storage.reserveTemporary(name), throwsA(isA<FileProblem>()));
    }
  });

  test('measures actual bytes; clearing preserves completed, nested personal and all other data', () async {
    final downloaded = await write('account-a/blobs/lesson.pdf', 1024);
    final personal = await write('account-a/folders/nested/personal.txt', 55);
    await write('account-a/temporary/stale', 30);
    final nested = await write('account-a/temporary/unknown/nested', 9);
    final protected = [
      await write('account-a/profile.sqlite', 70),
      await write('account-a/drafts/edit', 80),
      await write('drive_backup/account-a/queued', 90),
      await write('account-b/temporary/stale', 100),
      await write('exported.txt', 110),
    ];
    final active = storage.reserveTemporary('running');
    try {
      await active.writeAsBytes(List.filled(45, 1));
      final usage = await storage.usage();
      expect(usage.filesBytes, 1079);
      expect(usage.cacheBytes, 30);
      // A second storage instance uses the same protection as startup cleanup.
      expect(await FileStorage(storage.root).clearTemporary(), 30);
      expect((await storage.usage()).cacheBytes, 0);
      expect(await downloaded.readAsBytes(), List.filled(1024, 7));
      expect(await personal.readAsBytes(), List.filled(55, 7));
      expect(await nested.exists(), isTrue);
      for (final file in protected) {
        expect(await file.exists(), isTrue);
      }
      expect(await active.length(), 45);
    } finally {
      storage.releaseTemporary(active);
    }
    expect((await storage.usage()).cacheBytes, 45);
    expect(await storage.clearTemporary(), 45);
  });

  test(
    'clear leaves the local file index and offline settings untouched',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await write('account-a/blobs/lesson.txt', 6);
      await write('account-a/temporary/stale', 8);
      await db.customStatement(
        "INSERT INTO local_files(id,name,relative_path,size,source,created_at,updated_at) VALUES('file','lesson.txt','blobs/lesson.txt',6,'download',1,1)",
      );
      await db.customStatement(
        "INSERT INTO app_settings(key,value) VALUES('theme','dark')",
      );
      final repository = StorageRepository(FilesRepository(db, storage));
      final before =
          (await db.customSelect('SELECT * FROM local_files').getSingle()).data;
      expect((await repository.clear(() => true)).cacheBytes, 0);
      expect(
        (await db.customSelect('SELECT * FROM local_files').getSingle()).data,
        before,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT value FROM app_settings WHERE key='theme'",
                )
                .getSingle())
            .read<String>('value'),
        'dark',
      );
      expect(
        await File('${storage.root.path}/blobs/lesson.txt').readAsBytes(),
        List.filled(6, 7),
      );
    },
  );

  test('account cancellation stops before deletion and retry clears remaining bytes', () async {
    final first = await write('account-a/temporary/one', 3);
    await write('account-a/temporary/two', 4);
    await expectLater(
      storage.clearTemporary(isCurrent: () => false),
      throwsStateError,
    );
    expect(await first.exists(), isTrue);
    var checks = 0;
    await expectLater(
      storage.clearTemporary(isCurrent: () => ++checks == 1),
      throwsStateError,
    );
    expect((await storage.usage()).cacheBytes, anyOf(3, 4));
    await storage.clearTemporary();
    expect((await storage.usage()).cacheBytes, 0);
  });

  test('never follows directory or file symlinks', () async {
    final outside = await write('outside/keep', 13);
    await Directory('${storage.root.path}/temporary').create();
    await Directory('${storage.root.path}/folders').create();
    try {
      await Link('${storage.root.path}/temporary/link').create(outside.path);
      await Link('${storage.root.path}/folders/link')
          .create(outside.parent.path);
    } on FileSystemException {
      markTestSkipped(
        'Host does not permit symlinks; run on a symlink-capable host.',
      );
      return;
    }
    expect((await storage.usage()).filesBytes, 0);
    expect((await storage.usage()).cacheBytes, 0);
    expect(await storage.clearTemporary(), 0);
    expect(await outside.length(), 13);
    await Directory('${storage.root.path}/temporary').delete(recursive: true);
    await Link('${storage.root.path}/temporary').create(outside.parent.path);
    await expectLater(storage.clearTemporary(), throwsA(isA<FileProblem>()));
    expect(await outside.exists(), isTrue);
  });

  test(
    'successful deletion followed by a failed rescan is not a success',
    () async {
      await write('account-a/temporary/stale', 5);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = StorageRepository(
        FilesRepository(db, FailedRescanStorage(storage.root)),
      );
      await expectLater(
        repository.clear(() => true),
        throwsA(isA<FileProblem>()),
      );
      expect(
        await File('${storage.root.path}/temporary/stale').exists(),
        isFalse,
      );
      expect((await storage.usage()).cacheBytes, 0);
    },
  );

  test('failed measurement is not reported as zero', () async {
    await storage.root.delete();
    await expectLater(storage.usage(), throwsA(isA<FileProblem>()));
  });

  test(
    'late clear after account A to B to A cannot publish or continue',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final accounts = StreamController<String?>.broadcast();
      final repository = DelayedStorage(FilesRepository(db, storage));
      final container = ProviderContainer(
        overrides: [
          authUserIdProvider.overrideWith((ref) async* {
            yield 'a';
            yield* accounts.stream;
          }),
          storageRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      final auth = container.listen(authUserIdProvider, (_, _) {});
      final subscription = container.listen(storageSettingsProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        auth.close();
        container.dispose();
        await accounts.close();
        await db.close();
      });
      await container.read(authUserIdProvider.future);
      await container.read(storageSettingsProvider.future);
      final old = container.read(storageSettingsProvider.notifier).clear();
      expect(
        await container.read(storageSettingsProvider.notifier).clear(),
        isFalse,
      );
      accounts.add('b');
      await container.pump();
      accounts.add('a');
      await container.pump();
      expect(repository.current!(), isFalse);
      repository.result.complete(const StorageUsage(999, 0));
      expect(await old, isFalse);
      expect(
        (await container.read(storageSettingsProvider.future)).filesBytes,
        10,
      );
    },
  );
}
