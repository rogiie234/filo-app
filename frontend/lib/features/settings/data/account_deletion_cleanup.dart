import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/local/user_database_manager.dart';
import '../../../core/account_file_lock.dart';
import '../../files/data/file_storage.dart';

class AccountDeletionCleanup {
  AccountDeletionCleanup(
    this.manager, {
    this.directoryProvider = getApplicationSupportDirectory,
  });
  final UserDatabaseManager manager;
  final Future<Directory> Function() directoryProvider;
  Future<void> block(String id, bool blocked) async {
    final support = await directoryProvider();
    FileStorage.setBlocked(
      Directory(p.join(support.path, 'files', id)),
      blocked,
    );
  }

  Future<void> remove(String id) async {
    final lock = await lockAccountFiles(
      id,
      directoryProvider: directoryProvider,
    );
    try {
      await _removeAccount(id);
    } finally {
      await lock.close();
    }
  }

  Future<void> _removeAccount(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
      throw StateError('Invalid account');
    }
    final support = await directoryProvider();
    final root = Directory(p.join(support.path, 'files', id));
    FileStorage.setBlocked(root, true);
    await FileStorage(root).waitForIdle();
    await manager.removeForUser(id);
    final canonicalSupport = await support.resolveSymbolicLinks();
    for (final folder in ['files', 'drive_backup']) {
      final parent = Directory(p.join(support.path, folder));
      if (await FileSystemEntity.type(parent.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        continue;
      }
      if (await FileSystemEntity.type(parent.path, followLinks: false) !=
              FileSystemEntityType.directory ||
          !p.equals(
            p.normalize(await parent.resolveSymbolicLinks()),
            p.normalize(p.join(canonicalSupport, folder)),
          )) {
        throw StateError('Unsafe account directory');
      }
      await _remove(p.join(parent.path, id), parent.path);
    }
    final legacyLock = p.join(support.path, '.account-$id.lock');
    final legacyType = await FileSystemEntity.type(
      legacyLock,
      followLinks: false,
    );
    if (legacyType == FileSystemEntityType.directory) {
      throw StateError('Invalid legacy lock');
    }
    await _remove(legacyLock, support.path);
    const storage = FlutterSecureStorage();
    bool owned(String key) =>
        key == 'filo.offline_verified.$id' ||
        key == 'notifications_prompt_$id' ||
        key.startsWith('filo.drive.$id.');
    final keys = await storage.readAll();
    for (final key in keys.keys.toList()) {
      if (owned(key)) {
        await storage.delete(key: key);
      }
    }
    if ((await storage.readAll()).keys.any(owned)) {
      throw StateError('Account keys remain');
    }
    for (final path in [
      p.join(support.path, 'files', id),
      p.join(support.path, 'drive_backup', id),
      p.join(support.path, '.account-$id.lock'),
      for (final suffix in ['', '-wal', '-shm', '-journal'])
        p.join(
          support.path,
          'databases',
          '${UserDatabaseManager.filenameForUser(id)}$suffix',
        ),
    ]) {
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Account files remain');
      }
    }
  }

  Future<void> _remove(String path, String parent) async {
    if (!p.isWithin(p.absolute(parent), p.absolute(path))) {
      throw StateError('Unsafe account path');
    }
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.link) {
      await Link(path).delete();
      return;
    }
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
      return;
    }
    final directory = Directory(path);
    await for (final child in directory.list(followLinks: false)) {
      await _remove(child.path, parent);
    }
    await directory.delete();
  }
}
