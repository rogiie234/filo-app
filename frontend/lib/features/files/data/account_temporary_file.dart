import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'file_storage.dart';

class AccountTemporaryFile {
  AccountTemporaryFile._(this.storage, this.lease, this.file);
  final FileStorage storage;
  final File lease, file;

  static Future<AccountTemporaryFile> create(
    String id,
    String filename, {
    required bool Function() isCurrent,
    Future<Directory> Function() directoryProvider =
        getApplicationSupportDirectory,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(id) ||
        filename.isEmpty ||
        p.basename(filename) != filename ||
        filename == '.' ||
        filename == '..') {
      throw const FileProblem('Invalid temporary path.');
    }
    final support = await directoryProvider();
    if (!isCurrent()) throw const FileProblem('Account changed.');
    final storage = FileStorage(Directory(p.join(support.path, 'files', id)));
    final lease = storage.reserveTemporary('work-${const Uuid().v4()}');
    final temporary = AccountTemporaryFile._(
      storage,
      lease,
      File(p.join(lease.path, filename)),
    );
    var created = false;
    try {
      var directory = support;
      for (final part in ['files', id, 'temporary', p.basename(lease.path)]) {
        directory = Directory(p.join(directory.path, part));
        final type = await FileSystemEntity.type(
          directory.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound)
          await directory.create();
        else if (type != FileSystemEntityType.directory)
          throw const FileProblem('Unsafe temporary path.');
        if (!p.equals(
          p.normalize(await directory.resolveSymbolicLinks()),
          p.normalize(directory.absolute.path),
        )) {
          throw const FileProblem('Unsafe temporary path.');
        }
      }
      created = true;
      storage.ensureAvailable();
      if (!isCurrent()) throw const FileProblem('Account changed.');
      return temporary;
    } catch (_) {
      if (created)
        await temporary.close();
      else
        storage.releaseTemporary(lease);
      rethrow;
    }
  }

  Future<void> close() async {
    try {
      if (await file.exists()) await file.delete();
      if (await file.parent.exists()) await file.parent.delete();
    } finally {
      storage.releaseTemporary(lease);
    }
  }
}
