import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImportStorage extends FileStorage {
  _ImportStorage(super.root);

  @override
  Future<void> ensureSpace(int bytes) async {}
}

void main() {
  test('unfinished .deleting import survives recovery and reopen', () async {
    final root = await Directory.systemTemp.createTemp(
      'filo-deleting-recovery-',
    );
    final databaseFile = File('${root.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(databaseFile));
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final storage = _ImportStorage(root);
    await storage.createFolder('blobs');
    await storage.createFolder('temporary');
    var repo = FilesRepository(db, storage);
    await db.customStatement(
      "CREATE TRIGGER fail_import BEFORE INSERT ON local_files BEGIN SELECT RAISE(ABORT,'fixture index failure'); END",
    );
    final picked = File('${root.path}/picked');
    await picked.writeAsString('Keep these bytes');
    await expectLater(
      repo.importFile(picked, 'notes.deleting', null),
      throwsA(isA<Exception>()),
    );
    expect(await db.select(db.localFiles).get(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_import');
    await db.close();
    db = AppDatabase(NativeDatabase(databaseFile));
    repo = FilesRepository(db, storage);
    await repo.recoverInterruptedDeletes();
    final recovered = (await db.select(db.localFiles).get()).single;
    expect(recovered.name, 'notes.deleting');
    expect(recovered.relativePath, 'blobs/${recovered.id}.deleting');
    expect(
      await storage.file(recovered.relativePath).readAsString(),
      'Keep these bytes',
    );

    await db.close();
    db = AppDatabase(NativeDatabase(databaseFile));
    repo = FilesRepository(db, storage);
    await repo.recoverInterruptedDeletes();
    expect((await db.select(db.localFiles).get()).single, recovered);
    expect(
      await storage.file(recovered.relativePath).readAsString(),
      'Keep these bytes',
    );
    expect(await Directory('${root.path}/blobs').list().length, 1);
  });

  test(
    'indexed .deleting file survives attachment commit and reopen',
    () async {
      final root = await Directory.systemTemp.createTemp('filo-deleting-file-');
      final databaseFile = File('${root.path}/cache.sqlite');
      var db = AppDatabase(NativeDatabase(databaseFile));
      addTearDown(() async {
        await db.close();
        await root.delete(recursive: true);
      });
      final storage = _ImportStorage(root);
      await storage.createFolder('blobs');
      await storage.createFolder('temporary');
      var repo = FilesRepository(db, storage);
      final picked = File('${root.path}/picked');
      await picked.writeAsString('Keep these bytes');
      final original = await repo.importFile(picked, 'notes.deleting', null);
      expect(original.relativePath, 'blobs/${original.id}.deleting');
      final indexed = await repo.get(original.id);
      expect(indexed, isNotNull);

      final attachment = File('${root.path}/attachment');
      await attachment.writeAsString('Attachment bytes');
      await repo.commit(
        attachment,
        name: 'lesson.txt',
        source: 'class_material',
        attachmentId: 'attachment',
      );
      expect(await repo.get(original.id), indexed);
      expect(
        await storage.file(original.relativePath).readAsString(),
        'Keep these bytes',
      );

      await db.close();
      db = AppDatabase(NativeDatabase(databaseFile));
      repo = FilesRepository(db, storage);
      await repo.recoverInterruptedDeletes();
      expect(await repo.get(original.id), indexed);
      expect(
        await storage.file(original.relativePath).readAsString(),
        'Keep these bytes',
      );
      expect(await db.select(db.localFiles).get(), hasLength(2));
    },
  );

  test('failed attachment index insert recovers before Retry and survives database reopen', () async {
    final root = await Directory.systemTemp.createTemp('filo-import-retry-');
    final databaseFile = File('${root.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(databaseFile));
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final storage = FileStorage(root);
    await storage.createFolder('blobs');
    var repo = FilesRepository(db, storage);
    await db.customStatement(
      "CREATE TRIGGER fail_import BEFORE INSERT ON local_files BEGIN SELECT RAISE(ABORT,'fixture index failure'); END",
    );
    final first = File('${root.path}/first.txt');
    await first.writeAsString('keep');
    await expectLater(
      repo.commit(
        first,
        name: 'lesson.txt',
        source: 'class_material',
        attachmentId: 'attachment',
      ),
      throwsA(isA<Exception>()),
    );
    expect(await first.exists(), isFalse);
    final journals = await Directory('${root.path}/blobs')
        .list()
        .where((f) => f.path.endsWith('.importing'))
        .toList();
    expect(journals, hasLength(1));
    final pending = LocalFileRecord.fromJson(
      jsonDecode(await File(journals.single.path).readAsString())
          as Map<String, dynamic>,
    );
    await db.customStatement('DROP TRIGGER fail_import');
    final retry = File('${root.path}/retry.txt');
    await retry.writeAsString('keep');
    final saved = await repo.commit(
      retry,
      name: 'lesson.txt',
      source: 'class_material',
      attachmentId: 'attachment',
    );
    expect(saved.id, pending.id);
    expect(await retry.exists(), isFalse);
    await db.close();
    db = AppDatabase(NativeDatabase(databaseFile));
    repo = FilesRepository(db, storage);
    await repo.recoverInterruptedDeletes();
    expect(await db.select(db.localFiles).get(), hasLength(1));
    expect(
      await storage
          .file((await repo.source('attachment'))!.relativePath)
          .readAsString(),
      'keep',
    );
    final remaining = await Directory('${root.path}/blobs').list().toList();
    expect(remaining, hasLength(1));
    expect(
      await remaining.single.resolveSymbolicLinks(),
      await storage.file(saved.relativePath).resolveSymbolicLinks(),
    );
  });
  for (final completedBytes in [true, false]) {
    test(
      'startup settles older attachment journal; completed bytes exist=$completedBytes',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'filo-import-duplicate-',
        );
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
          await root.delete(recursive: true);
        });
        final storage = FileStorage(root);
        await storage.createFolder('blobs');
        final now = DateTime.utc(2026, 11, 15);
        LocalFileRecord row(String id) => LocalFileRecord(
          id: id,
          name: 'lesson.txt',
          relativePath: 'blobs/$id.txt',
          size: 4,
          source: 'class_material',
          sourceAttachmentId: 'attachment',
          createdAt: now,
          updatedAt: now,
        );
        final old = row('old'), completed = row('completed');
        await storage.file(old.relativePath).writeAsString('keep');
        final journal = File('${root.path}/blobs/.old.importing');
        await journal.writeAsString(jsonEncode(old.toJson()));
        await db.into(db.localFiles).insert(completed);
        if (completedBytes) {
          await storage.file(completed.relativePath).writeAsString('keep');
        }
        final repo = FilesRepository(db, storage);
        await repo.recoverInterruptedDeletes();
        await repo.recoverInterruptedDeletes();
        final saved = (await db.select(db.localFiles).get()).single;
        expect(saved.id, completedBytes ? completed.id : old.id);
        expect(await storage.file(saved.relativePath).readAsString(), 'keep');
        expect(await journal.exists(), isFalse);
        expect(await storage.file(old.relativePath).exists(), !completedBytes);
      },
    );
  }
  for (final stage in ['before move', 'after move', 'after index']) {
    test(
      'import recovery is idempotent $stage and preserves indexed files',
      () async {
        final root = await Directory.systemTemp.createTemp('filo-import-');
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() async {
          await db.close();
          await root.delete(recursive: true);
        });
        final storage = FileStorage(root);
        await storage.createFolder('blobs');
        final now = DateTime.utc(2026, 11, 15);
        final row = LocalFileRecord(
          id: 'import',
          name: 'note.importing',
          relativePath: 'blobs/import.importing',
          size: 4,
          source: 'personal_upload',
          createdAt: now,
          updatedAt: now,
        );
        final target = storage.file(row.relativePath);
        final journal = File('${target.parent.path}/.${row.id}.importing');
        final writing = File('${journal.path}.writing');
        await writing.writeAsString('{');
        await journal.writeAsString(jsonEncode(row.toJson()), flush: true);
        if (stage != 'before move') await target.writeAsString('keep');
        if (stage == 'after index') await db.into(db.localFiles).insert(row);
        final repo = FilesRepository(db, storage);
        await repo.recoverInterruptedDeletes();
        await repo.recoverInterruptedDeletes();
        expect(await journal.exists(), isFalse);
        expect(await writing.exists(), isFalse);
        expect(
          await repo.get(row.id),
          stage == 'before move' ? isNull : isNotNull,
        );
        if (stage != 'before move') expect(await target.readAsString(), 'keep');
      },
    );
  }
  test('renaming edits only the stem, preserves extension/bytes and resolves collisions', () async {
    final root = await Directory.systemTemp.createTemp('filo-rename-');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final repository = FilesRepository(db, FileStorage(root));
    await repository.storage.createFolder('blobs');
    var index = 0;
    Future<LocalFileRecord> add(String name) async {
      final temporary = File('${root.path}/picked-${index++}');
      await temporary.writeAsString('Unchanged bytes');
      return repository.commit(
        temporary,
        name: name,
        source: 'personal_upload',
      );
    }

    final pdf = await add('Report.PDF');
    await add('Notes.v2.PDF');
    await repository.renameFile(pdf, ' Notes.v2 ');
    final renamed = (await repository.get(pdf.id))!;
    expect(renamed.name, 'Notes.v2 (1).PDF');
    expect(renamed.relativePath, pdf.relativePath);
    expect(
      await repository.storage.file(renamed.relativePath).readAsString(),
      'Unchanged bytes',
    );
    for (final item in [
      ('README', 'Overview', 'Overview'),
      ('.env', '.config', '.config'),
      ('archive.tar.gz', 'archive.v2.tar', 'archive.v2.tar.gz'),
    ]) {
      final file = await add(item.$1);
      await repository.renameFile(file, item.$2);
      expect((await repository.get(file.id))!.name, item.$3);
    }
    await expectLater(
      repository.renameFile(renamed, ''),
      throwsA(isA<FileProblem>()),
    );
    await expectLater(
      repository.renameFile(renamed, List.filled(255, 'x').join()),
      throwsA(isA<FileProblem>()),
    );
    expect((await repository.get(pdf.id))!.name, renamed.name);
  });

  test(
    'moves retain disk paths and deleting the former folder keeps moved files',
    () async {
      final root = await Directory.systemTemp.createTemp('filo-move-');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        await root.delete(recursive: true);
      });
      final storage = FileStorage(root);
      final repository = FilesRepository(db, storage);
      final first = await repository.newFolder('First', null);
      final second = await repository.newFolder('Second', null);
      final temporary = File('${root.path}/picked.txt');
      await temporary.writeAsString('Keep these bytes');
      final file = await repository.commit(
        temporary,
        name: 'note.txt',
        source: 'personal_upload',
        folderId: first.id,
      );
      await repository.moveFile(file, second.id);
      var saved = (await repository.get(file.id))!;
      expect(saved.folderId, second.id);
      expect(saved.relativePath, file.relativePath);
      await repository.deleteFolder(first);
      await FilesRepository(db, storage).recoverInterruptedDeletes();
      expect(
        await storage.file(saved.relativePath).readAsString(),
        'Keep these bytes',
      );
      await repository.moveFile(saved, null);
      saved = (await repository.get(file.id))!;
      expect(saved.folderId, isNull);
      expect(saved.relativePath, file.relativePath);
      expect(
        await storage.file(saved.relativePath).readAsString(),
        'Keep these bytes',
      );
      await repository.deleteFile(saved);
      expect(await storage.file(saved.relativePath).exists(), isFalse);
    },
  );
}
