import 'dart:io';

import 'package:filo/core/account_file_lock.dart';
import 'package:filo/core/account_deletion_journal.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/settings/data/account_deletion_cleanup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late UserDatabaseManager manager;
  late AccountDeletionCleanup cleanup;
  Future<File> fixture(String name) async {
    final file = File(p.join(root.path, name));
    await file.parent.create(recursive: true);
    return file.writeAsString(name);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'filo.offline_verified.a': 'fixture',
      'notifications_prompt_a': 'fixture',
      'filo.drive.a.job': 'fixture',
      'filo.offline_verified.b': 'preserve',
      'filo.device': 'installation',
    });
    root = await Directory.systemTemp.createTemp('filo-deletion-');
    manager = UserDatabaseManager(directoryProvider: () async => root);
    cleanup = AccountDeletionCleanup(
      manager,
      directoryProvider: () async => root,
    );
  });
  tearDown(() async {
    await manager.close();
    FileStorage.setBlocked(Directory(p.join(root.path, 'files', 'a')), false);
    await root.delete(recursive: true);
  });
  test('removes only owner files, snapshots, database and owner secure keys', () async {
    final a = await manager.openForUser('a');
    await a.customStatement(
      "INSERT INTO app_settings(key,value) VALUES('theme','dark')",
    );
    await fixture('files/a/blobs/download.pdf');
    await fixture('files/a/folders/nested/personal.txt');
    await fixture('drive_backup/a/job/snapshot.zip');
    final other = await fixture('files/b/blobs/keep.pdf');
    await fixture('.account-a.lock');
    final otherLock = await fixture('.account-b.lock');
    final export = await fixture('exports/keep.pdf');
    final b = await manager.openForUser('b');
    await b.customStatement(
      "INSERT INTO app_settings(key,value) VALUES('theme','light')",
    );
    await b.customStatement(
      "INSERT INTO file_settings(key,value) VALUES('alarm-fixture','preserve')",
    );
    await cleanup.remove('a');
    expect(await Directory(p.join(root.path, 'files/a')).exists(), isFalse);
    expect(
      await Directory(p.join(root.path, 'drive_backup/a')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(root.path, 'databases/a.sqlite')).exists(),
      isFalse,
    );
    expect(await other.readAsString(), 'files/b/blobs/keep.pdf');
    expect(await File(p.join(root.path, '.account-a.lock')).exists(), isFalse);
    expect(await otherLock.readAsString(), '.account-b.lock');
    expect(
      (await b
              .customSelect("SELECT value FROM app_settings WHERE key='theme'")
              .getSingle())
          .read<String>('value'),
      'light',
    );
    expect(
      (await b
              .customSelect(
                "SELECT value FROM file_settings WHERE key='alarm-fixture'",
              )
              .getSingle())
          .read<String>('value'),
      'preserve',
    );
    expect(await export.readAsString(), 'exports/keep.pdf');
    expect(await b.customSelect('SELECT 1').get(), isNotEmpty);
    const secure = FlutterSecureStorage();
    expect(await secure.read(key: 'filo.drive.a.job'), isNull);
    expect(await secure.read(key: 'filo.offline_verified.a'), isNull);
    expect(await secure.read(key: 'filo.offline_verified.b'), 'preserve');
    expect(await secure.read(key: 'filo.device'), 'installation');
    await cleanup.remove('a'); // Interrupted cleanup is idempotent.
  });
  test(
    'blocks new temporary writes and waits for active foreground lease',
    () async {
      await fixture('files/a/temporary/active.part');
      final storage = FileStorage(Directory(p.join(root.path, 'files/a')));
      final active = storage.reserveTemporary('active.part');
      await cleanup.block('a', true);
      expect(
        () => storage.reserveTemporary('new.part'),
        throwsA(isA<FileProblem>()),
      );
      var finished = false;
      final removing = cleanup.remove('a').then((_) => finished = true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(finished, isFalse);
      expect(await active.exists(), isTrue);
      storage.releaseTemporary(active);
      await removing;
      expect(await storage.root.exists(), isFalse);
    },
  );
  test('does not follow owner symlink into another account', () async {
    final other = await fixture('files/b/keep.txt');
    final link = Link(p.join(root.path, 'files/a'));
    try {
      await link.create(Directory(p.join(root.path, 'files/b')).path);
    } on FileSystemException {
      markTestSkipped('Host does not permit symlink creation');
      return;
    }
    await cleanup.remove('a');
    expect(await other.readAsString(), 'files/b/keep.txt');
    expect(
      await FileSystemEntity.type(link.path, followLinks: false),
      FileSystemEntityType.notFound,
    );
  });
  test(
    'worker lock prevents deletion until worker releases private storage',
    () async {
      final file = await fixture('files/a/blobs/keep.pdf');
      final lock = await lockAccountFiles(
        'a',
        directoryProvider: () async => root,
      );
      try {
        await expectLater(
          cleanup.remove('a'),
          throwsA(anyOf(isA<StateError>(), isA<FileSystemException>())),
        );
        expect(await file.exists(), isTrue);
      } finally {
        await lock.close();
      }
      await cleanup.remove('a');
      expect(await file.exists(), isFalse);
    },
  );
  test('rejects traversal before touching account storage', () async {
    final other = await fixture('files/b/keep.txt');
    await expectLater(cleanup.remove('../b'), throwsStateError);
    expect(await other.exists(), isTrue);
  });
  test(
    'restored deletion journal blocks ordinary account database access',
    () async {
      await DeletionJournalStore().write({
        'a': const DeletionRecord(
          'a',
          'original-session',
          DeletionStage.pending,
        ),
      });
      final container = ProviderContainer(
        overrides: [
          userDatabaseManagerProvider.overrideWithValue(manager),
          verifiedUserIdProvider.overrideWith((ref) async => 'a'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(accountDatabaseProvider, (_, _) {});
      expect(await container.read(accountDatabaseProvider.future), isNull);
      expect(
        await File(p.join(root.path, 'databases/a.sqlite')).exists(),
        isFalse,
      );
    },
  );
}
