import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const maxLocalFileBytes = 26214400;

class FileProblem implements Exception {
  const FileProblem(this.message, {this.kind = 'failed'});
  final String message, kind;
}

class FileStorage {
  FileStorage(this.root);
  final Directory root;

  // shortcut: leases share a foreground isolate; extend before background sync creates temporary files.
  static final _activeTemporary = <String>{};

  File reserveTemporary(String name) {
    if (name.isEmpty ||
        p.basename(name) != name ||
        name == '.' ||
        name == '..') {
      throw const FileProblem('Invalid temporary file path.');
    }
    final result = file('temporary/$name');
    _activeTemporary.add(p.normalize(p.absolute(result.path)));
    return result;
  }

  void releaseTemporary(File file) =>
      _activeTemporary.remove(p.normalize(p.absolute(file.path)));

  void _checkRoot() {
    if (FileSystemEntity.typeSync(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileProblem('Could not read storage. Try again.');
    }
  }

  Future<int> _bytes(Directory directory) async {
    final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return 0;
    if (type != FileSystemEntityType.directory) {
      throw const FileProblem('Could not read storage. Try again.');
    }
    var total = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File) total += await entry.length();
      if (entry is Directory) total += await _bytes(entry);
    }
    return total;
  }

  // Only direct regular temporary files are disposable; unknown nested content stays.
  Future<List<File>> _disposable() async {
    _checkRoot();
    final directory = Directory(p.join(root.path, 'temporary'));
    final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return [];
    if (type != FileSystemEntityType.directory) {
      throw const FileProblem('Could not read storage. Try again.');
    }
    return [
      await for (final entry in directory.list(followLinks: false))
        if (entry is File &&
            !_activeTemporary.contains(p.normalize(p.absolute(entry.path))))
          entry,
    ];
  }

  Future<StorageUsage> usage() async {
    _checkRoot();
    final completed =
        await _bytes(Directory(p.join(root.path, 'blobs'))) +
        await _bytes(Directory(p.join(root.path, 'folders')));
    var cache = 0;
    for (final file in await _disposable()) {
      if (!_activeTemporary.contains(p.normalize(p.absolute(file.path)))) {
        cache += await file.length();
      }
    }
    return StorageUsage(completed, cache);
  }

  Future<int> clearTemporary({bool Function()? isCurrent}) async {
    var removed = 0;
    for (final file in await _disposable()) {
      if (isCurrent != null && !isCurrent())
        throw StateError('Account changed');
      _checkRoot();
      final parent = p.dirname(file.path);
      if (FileSystemEntity.typeSync(parent, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FileProblem('Could not read storage. Try again.');
      }
      // No await between checking the lease and deletion: new transfers cannot race it.
      if (!_activeTemporary.contains(p.normalize(p.absolute(file.path))) &&
          FileSystemEntity.typeSync(file.path, followLinks: false) ==
              FileSystemEntityType.file) {
        final bytes = file.lengthSync();
        file.deleteSync();
        removed += bytes;
      }
      await Future<void>.delayed(Duration.zero);
    }
    return removed;
  }

  static Future<FileStorage> forAccount(
    String userId, {
    bool cleanTemporary = true,
    bool Function()? isCurrent,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw const FileProblem('Sign in again to access your files.');
    }
    final support = await getApplicationSupportDirectory();
    if (isCurrent != null && !isCurrent()) throw StateError('Account changed');
    final storage = FileStorage(
      Directory(p.join(support.path, 'files', userId)),
    );
    await storage.root.create(recursive: true);
    await Directory(p.join(storage.root.path, 'blobs')).create(recursive: true);
    await Directory(p.join(storage.root.path, 'temporary'))
        .create(recursive: true);
    if (cleanTemporary) await storage.clearTemporary(isCurrent: isCurrent);
    return storage;
  }

  File file(String relative) {
    final full = p.normalize(p.join(root.path, relative));
    if (!p.isWithin(root.path, full)) {
      throw const FileProblem('Invalid local file path.');
    }
    return File(full);
  }

  Future<Directory> createFolder(String relative) async =>
      Directory(file(relative).path).create(recursive: true);

  Future<void> ensureSpace(int expected) async {
    final free = await const MethodChannel('com.filo.filo/storage')
        .invokeMethod<int>('freeBytes');
    if (free == null) {
      throw const FileProblem('Could not check free space. Try again.');
    }
    if (free < expected + 1048576) {
      throw const FileProblem('Not enough space on your phone.', kind: 'space');
    }
  }

  Future<int> usedBytes() async {
    var bytes = 0;
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is File) bytes += await entry.length();
    }
    return bytes;
  }
}

class StorageUsage {
  const StorageUsage(this.filesBytes, this.cacheBytes);
  final int filesBytes, cacheBytes;
}
