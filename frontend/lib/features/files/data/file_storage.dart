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

  static Future<FileStorage> forAccount(
    String userId, {
    bool cleanTemporary = true,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw const FileProblem('Sign in again to access your files.');
    }
    final support = await getApplicationSupportDirectory();
    final storage = FileStorage(
      Directory(p.join(support.path, 'files', userId)),
    );
    await storage.root.create(recursive: true);
    await Directory(p.join(storage.root.path, 'blobs')).create(recursive: true);
    await Directory(p.join(storage.root.path, 'temporary'))
        .create(recursive: true);
    // These bytes were never committed to the local index.
    if (cleanTemporary) {
      await for (final entry in Directory(
        p.join(storage.root.path, 'temporary'),
      ).list()) {
        if (entry is File) {
          await entry.delete();
        }
      }
    }
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
