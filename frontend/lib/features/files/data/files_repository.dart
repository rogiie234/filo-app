import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../data/local/app_database.dart';
import 'file_storage.dart';

class FilesRepository {
  FilesRepository(this.db, this.storage);
  final AppDatabase db;
  final FileStorage storage;
  Future<void> _pending = Future.value();

  Future<T> serialize<T>(Future<T> Function() work) {
    final result = _pending.then((_) => work());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> recoverInterruptedDeletes() async {
    await for (final entry in storage.root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File &&
          p.basename(entry.path).startsWith('.') &&
          entry.path.endsWith('.importing.writing')) {
        await entry.delete();
        continue;
      }
      if (entry is File &&
          p.basename(entry.path).startsWith('.') &&
          entry.path.endsWith('.importing')) {
        final row = LocalFileRecord.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(await entry.readAsString()) as Map,
          ),
        );
        final target = storage.file(row.relativePath);
        if (entry.path != p.join(target.parent.path, '.${row.id}.importing')) {
          throw const FileProblem('Invalid interrupted import.');
        }
        if (await target.exists() && await get(row.id) == null) {
          final existing = row.sourceAttachmentId == null
              ? null
              : await source(row.sourceAttachmentId!);
          if (existing == null) {
            await db.into(db.localFiles).insert(row);
          } else if (await storage.file(existing.relativePath).exists()) {
            if (existing.relativePath != row.relativePath) {
              await target.delete();
            }
          } else {
            await db.transaction(() async {
              await (db.delete(
                db.localFiles,
              )..where((f) => f.id.equals(existing.id))).go();
              await db.into(db.localFiles).insert(row);
            });
          }
        }
        await entry.delete();
        continue;
      }
    }
    final indexed = {
      for (final row in await db.select(db.localFiles).get())
        storage.file(row.relativePath).path: row,
    };
    await for (final entry in storage.root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is! File ||
          indexed.containsKey(entry.path) ||
          !entry.path.endsWith('.deleting')) {
        continue;
      }
      final original = entry.path.substring(
        0,
        entry.path.length - '.deleting'.length,
      );
      if (indexed.containsKey(original)) {
        if (!await File(original).exists()) {
          await entry.rename(original);
        }
      } else {
        await entry.delete();
      }
    }
  }

  Stream<List<LocalFileRecord>> watchFiles() =>
      db.select(db.localFiles).watch();
  Stream<List<LocalFolderRecord>> watchFolders() =>
      db.select(db.localFolders).watch();
  Future<LocalFileRecord?> get(String id) => (db.select(
    db.localFiles,
  )..where((f) => f.id.equals(id))).getSingleOrNull();
  Future<LocalFileRecord?> source(String id) => (db.select(
    db.localFiles,
  )..where((f) => f.sourceAttachmentId.equals(id))).getSingleOrNull();

  static String validName(String value) {
    final name = value.trim();
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.length > 255 ||
        RegExp(r'[\x00-\x1f/\\]').hasMatch(name)) {
      throw const FileProblem(
        'Enter a name without slashes, up to 255 characters.',
      );
    }
    return name;
  }

  Future<String> uniqueName(
    String value,
    String? parent, {
    String? exclude,
    bool folder = false,
  }) async {
    final name = validName(value);
    final folders = await db.select(db.localFolders).get();
    final files = await db.select(db.localFiles).get();
    final names = {
      ...folders
          .where((f) => f.parentId == parent && f.id != exclude)
          .map((f) => f.name.toLowerCase()),
      ...files
          .where((f) => f.folderId == parent && f.id != exclude)
          .map((f) => f.name.toLowerCase()),
    };
    var candidate = name, suffix = 1;
    final ext = folder ? '' : p.extension(name);
    final base = folder ? name : p.basenameWithoutExtension(name);
    while (names.contains(candidate.toLowerCase())) {
      candidate =
          '${base.substring(0, (base.length > 220 ? 220 : base.length))} (${suffix++})$ext';
    }
    return candidate;
  }

  Future<LocalFolderRecord> _folder(
    String name,
    String? parent,
    String? classId,
  ) async {
    final now = DateTime.now().toUtc();
    final row = LocalFolderRecord(
      id: const Uuid().v4(),
      parentId: parent,
      name: await uniqueName(name, parent, folder: true),
      classId: classId,
      createdAt: now,
      updatedAt: now,
    );
    await storage.createFolder('folders/${row.id}');
    await db.into(db.localFolders).insert(row);
    return row;
  }

  Future<LocalFolderRecord> newFolder(String name, String? parent) =>
      serialize(() => _folder(name, parent, null));

  Future<LocalFolderRecord> classFolder(String classId) async {
    final existing = await (db.select(
      db.localFolders,
    )..where((f) => f.classId.equals(classId))).getSingleOrNull();
    if (existing != null) {
      return existing;
    }
    final room = await (db.select(
      db.cacheClasses,
    )..where((c) => c.id.equals(classId))).getSingleOrNull();
    return _folder(room?.section ?? 'Class files', null, classId);
  }

  Future<LocalFileRecord> commit(
    File temporary, {
    required String name,
    required String source,
    String? attachmentId,
    String? classId,
    String? postId,
    String? folderId,
    String? mimeType,
  }) => serialize(() async {
    storage.ensureAvailable();
    if (attachmentId != null) {
      await recoverInterruptedDeletes();
      final cached = await this.source(attachmentId);
      if (cached != null && await storage.file(cached.relativePath).exists()) {
        if (await temporary.exists()) {
          await temporary.delete();
        }
        return cached;
      }
      if (cached != null) {
        await (db.delete(
          db.localFiles,
        )..where((f) => f.id.equals(cached.id))).go();
      }
    }
    final folder = classId == null ? folderId : (await classFolder(classId)).id;
    final id = const Uuid().v4();
    final extension = p.extension(name).toLowerCase();
    final relative =
        '${folder == null ? 'blobs' : 'folders/$folder'}/$id${RegExp(r'^\.[a-z0-9]{1,12}$').hasMatch(extension) ? extension : ''}';
    final target = storage.file(relative);
    final now = DateTime.now().toUtc();
    final row = LocalFileRecord(
      id: id,
      folderId: folder,
      name: await uniqueName(name, folder),
      relativePath: relative,
      mimeType: mimeType,
      size: await temporary.length(),
      source: source,
      sourceAttachmentId: attachmentId,
      classId: classId,
      sourcePostId: postId,
      backedUpAt: null,
      createdAt: now,
      updatedAt: now,
    );
    final journal = File(p.join(target.parent.path, '.$id.importing'));
    final writing = File('${journal.path}.writing');
    await writing.writeAsString(jsonEncode(row.toJson()), flush: true);
    await writing.rename(journal.path);
    await temporary.rename(target.path);
    // Keep the journal and bytes after an interrupted/failed index insert.
    await db.into(db.localFiles).insert(row);
    await journal.delete();
    return row;
  });

  Future<LocalFileRecord> importFile(
    File file,
    String name,
    String? folder,
  ) async {
    final size = await file.length();
    if (size > maxLocalFileBytes) {
      throw const FileProblem('Choose a file no larger than 25 MB.');
    }
    await storage.ensureSpace(size);
    final copy = storage.reserveTemporary(const Uuid().v4());
    try {
      await file.copy(copy.path);
      return await commit(
        copy,
        name: name,
        source: 'personal_upload',
        folderId: folder,
      );
    } finally {
      try {
        if (await copy.exists()) await copy.delete();
      } finally {
        storage.releaseTemporary(copy);
      }
    }
  }

  Future<void> renameFile(
    LocalFileRecord file,
    String baseName,
  ) => serialize(() async {
    final name = '${validName(baseName)}${p.extension(file.name)}';
    await (db.update(db.localFiles)..where((f) => f.id.equals(file.id))).write(
      LocalFilesCompanion(
        name: Value(await uniqueName(name, file.folderId, exclude: file.id)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  });
  Future<void> moveFile(
    LocalFileRecord file,
    String? folder,
  ) => serialize(() async {
    // Folder membership is metadata; stable disk paths survive process death.
    await (db.update(db.localFiles)..where((f) => f.id.equals(file.id))).write(
      LocalFilesCompanion(
        folderId: Value(folder),
        name: Value(await uniqueName(file.name, folder, exclude: file.id)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  });
  Future<void> changeFolder(
    LocalFolderRecord folder, {
    String? name,
    String? parent,
    bool move = false,
  }) => serialize(() async {
    final all = await db.select(db.localFolders).get();
    var ancestor = parent;
    final visited = <String>{};
    while (ancestor != null) {
      if (ancestor == folder.id || !visited.add(ancestor)) {
        throw const FileProblem('A folder cannot be moved inside itself.');
      }
      ancestor = all.where((f) => f.id == ancestor).firstOrNull?.parentId;
    }
    final destination = move ? parent : folder.parentId;
    await (db.update(
      db.localFolders,
    )..where((f) => f.id.equals(folder.id))).write(
      LocalFoldersCompanion(
        parentId: Value(destination),
        name: Value(
          await uniqueName(
            name ?? folder.name,
            destination,
            exclude: folder.id,
            folder: true,
          ),
        ),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  });

  Future<void> discardBackupCopies(String fileId) async {
    final jobs = await db
        .customSelect(
          "SELECT id,local_path FROM drive_backup_jobs WHERE local_file_id=? AND status!='complete'",
          variables: [Variable(fileId)],
        )
        .get();
    final userId = p.basename(storage.root.path);
    final support = p.dirname(p.dirname(storage.root.path));
    for (final row in jobs) {
      final id = row.read<String>('id');
      final expected = p.join(support, 'drive_backup', userId, id);
      if (!p.equals(
        p.normalize(row.read<String>('local_path')),
        p.normalize(expected),
      )) {
        continue;
      }
      final copy = File(expected);
      if (await copy.exists()) await copy.delete();
      await const FlutterSecureStorage().delete(key: 'filo.drive.$userId.$id');
      await db.customStatement(
        "DELETE FROM drive_backup_jobs WHERE id=? AND status!='complete'",
        [id],
      );
    }
  }

  Future<void> deleteFile(LocalFileRecord row) =>
      serialize(() => _deleteFile(row));
  Future<void> _deleteFile(LocalFileRecord row) async {
    final file = storage.file(row.relativePath);
    File? staged;
    if (await file.exists()) {
      staged = await file.rename('${file.path}.deleting');
    }
    try {
      await (db.delete(db.localFiles)..where((f) => f.id.equals(row.id))).go();
    } catch (_) {
      await staged?.rename(file.path);
      rethrow;
    }
    if (staged != null) {
      try {
        await staged.delete();
      } catch (_) {
        if (await staged.exists()) {
          await staged.rename(file.path);
        }
        await db.into(db.localFiles).insertOnConflictUpdate(row);
        rethrow;
      }
    }
    try {
      await discardBackupCopies(row.id);
    } catch (_) {
      /* Retried by the outbox. */
    }
  }

  Future<void> deleteFolder(LocalFolderRecord folder) => serialize(() async {
    Future<void> remove(String id) async {
      final children = await (db.select(
        db.localFolders,
      )..where((f) => f.parentId.equals(id))).get();
      for (final child in children) {
        await remove(child.id);
      }
      final files = await (db.select(
        db.localFiles,
      )..where((f) => f.folderId.equals(id))).get();
      for (final file in files) {
        await _deleteFile(file);
      }
      await (db.delete(db.localFolders)..where((f) => f.id.equals(id))).go();
      final directory = Directory(storage.file('folders/$id').path);
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    }

    await remove(folder.id);
  });

  Future<bool> needsStorageNotice() async =>
      (await db
              .customSelect(
                "SELECT value FROM file_settings WHERE key='storage_notice'",
              )
              .get())
          .isEmpty;
  Future<void> acknowledgeStorageNotice() => db.customStatement(
    "INSERT OR REPLACE INTO file_settings(key,value) VALUES('storage_notice','1')",
  );
}
