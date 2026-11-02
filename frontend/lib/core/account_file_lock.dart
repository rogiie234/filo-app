import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Keep the lock file: unlinking it could let two processes lock different inodes.
class AccountFileLock {
  AccountFileLock(this.handle, this.port, this.name);
  final RandomAccessFile handle;
  final ReceivePort port;
  final String name;
  Future<void> close() async {
    try {
      await handle.close();
    } finally {
      IsolateNameServer.removePortNameMapping(name);
      port.close();
    }
  }
}

Future<AccountFileLock> lockAccountFiles(
  String id, {
  Future<Directory> Function() directoryProvider =
      getApplicationSupportDirectory,
}) async {
  if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id)) {
    throw StateError('Invalid account');
  }
  final support = await directoryProvider();
  final name = 'filo.account.files:${p.normalize(support.absolute.path)}';
  final port = ReceivePort();
  // POSIX file locks alone do not exclude another isolate in the same process.
  if (!IsolateNameServer.registerPortWithName(port.sendPort, name)) {
    port.close();
    throw StateError('Account files are in use');
  }
  RandomAccessFile? handle;
  try {
    final file = File(p.join(support.path, '.account-files.lock'));
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Unsafe account lock');
    }
    handle = await file.open(mode: FileMode.append);
    await handle.lock(FileLock.exclusive);
    return AccountFileLock(handle, port, name);
  } catch (_) {
    try {
      await handle?.close();
    } finally {
      IsolateNameServer.removePortNameMapping(name);
      port.close();
    }
    rethrow;
  }
}
