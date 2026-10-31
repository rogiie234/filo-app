import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/lesson_text_extractor.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/study/application/study_source_reader.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

class TextFixtureExtractor extends LessonTextExtractor {
  TextFixtureExtractor({this.started, this.release});
  final Completer<void>? started, release;
  @override
  Future<LessonText> extract(
    String path,
    String fileType, {
    String? attachmentId,
    String? draftQuizId,
    AiCancelToken? cancel,
    void Function(ExtractionProgress)? onProgress,
  }) async {
    started?.complete();
    if (release != null) await release!.future;
    cancel?.check();
    final bytes = await File(path).readAsBytes();
    final text = String.fromCharCodes(bytes);
    if (text.trim().isEmpty) throw noLessonText;
    return LessonText(
      text: text,
      sourceKey: attachmentId == null
          ? 'sha:${sha256.convert(bytes)}'
          : 'att:$attachmentId',
    );
  }
}

Future<LocalFileRecord> sourceFixture(
  AppDatabase db,
  Directory root,
  String id, {
  String? attachment,
  String name = 'notes.txt',
  String text = 'Local text',
  int? size,
}) async {
  final path = '$id.txt';
  await File('${root.path}/$path').writeAsString(text);
  final now = DateTime.now();
  final file = LocalFileRecord(
    id: id,
    folderId: null,
    name: name,
    relativePath: path,
    mimeType: null,
    size: size ?? text.length,
    source: attachment == null ? 'personal' : 'class',
    sourceAttachmentId: attachment,
    classId: null,
    sourcePostId: null,
    backedUpAt: null,
    createdAt: now,
    updatedAt: now,
  );
  await db.into(db.localFiles).insert(file);
  return file;
}

void main() {
  late AppDatabase db;
  late Directory root;
  late StudySourceReader reader;
  late String notebook;
  var current = true;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('study-source-');
    current = true;
    reader = StudySourceReader(
      files: FilesRepository(db, FileStorage(root)),
      sources: NotebookSourceRepository(db),
      cache: FileTextCache(db),
      extractor: TextFixtureExtractor(),
      cancel: AiCancelToken(),
      isCurrent: () => current,
    );
    notebook = await NotebookRepository(db).create('Notebook');
  });
  tearDown(() async {
    reader.cancel.cancel();
    await db.close();
    await root.delete(recursive: true);
  });

  test('selection enforces supported types, exact size boundary, capacity and duplicate attachment', () async {
    for (final type in [
      'PDF',
      'docx',
      'pptx',
      'txt',
      'jpg',
      'jpeg',
      'png',
      'webp',
    ]) {
      final file = await sourceFixture(
        db,
        root,
        type,
        name: 'notes.$type',
        size: 10 * 1024 * 1024,
      );
      expect(StudySourceReader.selectionError(file, []), isNull);
    }
    final large = await sourceFixture(
      db,
      root,
      'large',
      size: 10 * 1024 * 1024 + 1,
    );
    expect(StudySourceReader.selectionError(large, []), lessonTooLarge.message);
    final unsupported = await sourceFixture(db, root, 'zip', name: 'notes.zip');
    expect(
      StudySourceReader.selectionError(unsupported, []),
      contains('not supported'),
    );
    final valid = await sourceFixture(
      db,
      root,
      'valid',
      attachment: 'attachment',
    );
    expect(
      StudySourceReader.selectionError(valid, [], pending: 3),
      studySourceLimitMessage,
    );
    await reader.add(notebook, valid, operation: AiCancelToken());
    final saved = await reader.sources.watch(notebook).first;
    expect(StudySourceReader.selectionError(valid, saved), contains('already'));
    final copy = valid.copyWith(id: 'copy');
    expect(StudySourceReader.selectionError(copy, saved), contains('already'));
  });

  test('offline local class and personal text survive file deletion and cache cleanup', () async {
    final classFile = await sourceFixture(
      db,
      root,
      'class',
      attachment: 'download',
      text: 'Class text',
    );
    final personal = await sourceFixture(
      db,
      root,
      'personal',
      text: 'Personal text',
    );
    for (final file in [classFile, personal]) {
      await reader.add(notebook, file, operation: AiCancelToken());
    }
    final saved = await reader.sources.watch(notebook).first;
    expect(
      saved.map((s) => s.extractedText),
      containsAll(['Class text', 'Personal text']),
    );
    expect(saved.map((s) => s.sourceKey), contains('att:download'));
    expect(await reader.cache.find(saved.first.sourceKey), isNotNull);
    await File('${root.path}/${classFile.relativePath}').delete();
    await reader.cache.deleteForDraft('unrelated-draft');
    expect(
      (await reader.sources.watch(notebook).first).map((s) => s.extractedText),
      containsAll(['Class text', 'Personal text']),
    );
    await NotebookRepository(db).delete(notebook);
    expect(await reader.sources.watch(notebook).first, isEmpty);
    expect(
      await File('${root.path}/${personal.relativePath}').exists(),
      isTrue,
    );
  });

  test(
    'one unreadable source does not block the next source or consume capacity',
    () async {
      final bad = await sourceFixture(db, root, 'bad', text: '');
      final good = await sourceFixture(db, root, 'good');
      await expectLater(
        reader.add(notebook, bad, operation: AiCancelToken()),
        throwsA(isA<LessonReadException>()),
      );
      await reader.add(notebook, good, operation: AiCancelToken());
      expect((await reader.sources.watch(notebook).first).length, 1);
    },
  );

  test(
    'missing originals and duplicate personal content do not create sources',
    () async {
      final original = await sourceFixture(db, root, 'original');
      await reader.add(notebook, original, operation: AiCancelToken());
      final copy = await sourceFixture(db, root, 'copy');
      await expectLater(
        reader.add(notebook, copy, operation: AiCancelToken()),
        throwsA(isA<LessonReadException>()),
      );
      await File('${root.path}/${copy.relativePath}').delete();
      await expectLater(
        reader.add(notebook, copy, operation: AiCancelToken()),
        throwsA(isA<LessonReadException>()),
      );
      expect((await reader.sources.watch(notebook).first).length, 1);
    },
  );

  test('cancel and account changes prevent writes', () async {
    final file = await sourceFixture(db, root, 'cancel');
    final operation = AiCancelToken()..cancel();
    await expectLater(
      reader.add(notebook, file, operation: operation),
      throwsA(isA<AiCancelled>()),
    );
    current = false;
    await expectLater(
      reader.add(notebook, file, operation: AiCancelToken()),
      throwsA(isA<AiCancelled>()),
    );
    expect(await reader.sources.watch(notebook).first, isEmpty);
  });

  test(
    'an account change while extraction is pending prevents persistence',
    () async {
      final file = await sourceFixture(db, root, 'pending');
      final started = Completer<void>(), release = Completer<void>();
      reader = StudySourceReader(
        files: reader.files,
        sources: reader.sources,
        cache: reader.cache,
        extractor: TextFixtureExtractor(started: started, release: release),
        cancel: reader.cancel,
        isCurrent: () => current,
      );
      final work = reader.add(notebook, file, operation: AiCancelToken());
      final assertion = expectLater(work, throwsA(isA<AiCancelled>()));
      await started.future;
      current = false;
      release.complete();
      await assertion;
      expect(await reader.sources.watch(notebook).first, isEmpty);
    },
  );

  test(
    'actual oversized bytes are refused even when file metadata says small',
    () async {
      final file = await sourceFixture(db, root, 'oversized', size: 1);
      final handle = await File('${root.path}/${file.relativePath}')
          .open(mode: FileMode.write);
      try {
        await handle.truncate(LessonTextExtractor.maxFileBytes + 1);
      } finally {
        await handle.close();
      }
      await expectLater(
        reader.add(notebook, file, operation: AiCancelToken()),
        throwsA(
          isA<LessonReadException>().having((e) => e.code, 'code', 'TOO_LARGE'),
        ),
      );
      expect(await reader.sources.watch(notebook).first, isEmpty);
    },
  );
}
