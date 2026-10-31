import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../assessments/data/ai_source_loader.dart'
    show checkAiSource, extension;
import '../../assessments/data/file_text_cache.dart';
import '../../assessments/data/lesson_text_extractor.dart';
import '../../assessments/domain/ai_sources.dart';
import '../../files/application/files_providers.dart';
import '../../files/data/files_repository.dart';
import '../data/study_repositories.dart';
import 'study_providers.dart';

const studySourceLimitMessage =
    'You can add up to 3 files. Remove a source to add another.';

final studySourceReaderProvider =
    FutureProvider.autoDispose<StudySourceReader?>((ref) async {
      final db = await ref.watch(accountDatabaseProvider.future);
      final files = await ref.watch(filesRepositoryProvider.future);
      if (db == null || files == null || !ref.mounted) return null;
      final cache = FileTextCache(db);
      final cancel = AiCancelToken();
      ref.onDispose(cancel.cancel);
      return StudySourceReader(
        files: files,
        sources: NotebookSourceRepository(db),
        cache: cache,
        extractor: LessonTextExtractor(cache: cache),
        cancel: cancel,
        isCurrent: () =>
            ref.mounted &&
            ref.read(accountDatabaseProvider).asData?.value == db,
      );
    });

/// Reads only account-local bytes; class downloads never require a server lookup.
class StudySourceReader {
  StudySourceReader({
    required this.files,
    required this.sources,
    required this.cache,
    required this.extractor,
    required this.cancel,
    required this.isCurrent,
  });
  final FilesRepository files;
  final NotebookSourceRepository sources;
  final FileTextCache cache;
  final LessonTextExtractor extractor;
  final AiCancelToken cancel;
  final bool Function() isCurrent;

  static String? selectionError(
    LocalFileRecord file,
    List<StudySource> saved, {
    int pending = 0,
  }) {
    try {
      checkAiSource(file.name, file.size);
    } on LessonReadException catch (error) {
      return error.message;
    }
    if (saved.any(
      (s) =>
          s.fileId == file.id ||
          (file.sourceAttachmentId != null &&
              s.sourceKey == 'att:${file.sourceAttachmentId}'),
    )) {
      return 'This file is already in this notebook.';
    }
    if (saved.length + pending >= 3) return studySourceLimitMessage;
    return null;
  }

  Future<void> add(
    String notebookId,
    LocalFileRecord selected, {
    required AiCancelToken operation,
  }) async {
    void check() {
      cancel.check();
      operation.check();
      if (!isCurrent()) throw const AiCancelled();
    }

    check();
    final file = await files.get(selected.id);
    check();
    if (file == null) throw lessonReadFailed;
    final saved = await sources.watch(notebookId).first;
    final problem = selectionError(file, saved);
    if (problem != null) throw LessonReadException('SELECTION', problem);
    final local = files.storage.file(file.relativePath);
    if (!await local.exists()) throw lessonReadFailed;
    if (await local.length() > LessonTextExtractor.maxFileBytes)
      throw lessonTooLarge;
    final extraction = AiCancelToken();
    cancel.cancelled.then((_) => extraction.cancel());
    operation.cancelled.then((_) => extraction.cancel());
    final text = await extractor.extract(
      local.path,
      extension(file.name),
      attachmentId: file.sourceAttachmentId,
      cancel: extraction,
    );
    check();
    final latest = await sources.watch(notebookId).first;
    if (latest.any((s) => s.sourceKey == text.sourceKey)) {
      throw const LessonReadException(
        'DUPLICATE',
        'This file is already in this notebook.',
      );
    }
    await cache.save(text);
    check();
    await sources.add(
      notebookId: notebookId,
      fileId: file.id,
      name: file.name,
      text: text,
      extractedAt: DateTime.now(),
    );
  }
}

final studyMissingSourcesProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, id) async {
      final sourceRows = ref.watch(studySourcesProvider(id));
      final fileRows = ref.watch(localFilesProvider);
      final repository = await ref.watch(filesRepositoryProvider.future);
      if (repository == null || !ref.mounted) return {};
      if (sourceRows.isLoading || fileRows.isLoading) return {};
      final sources = sourceRows.requireValue;
      final files = fileRows.requireValue;
      final missing = <String>{};
      for (final source in sources) {
        final matches = files.where((file) => file.id == source.fileId);
        if (matches.isEmpty ||
            !await repository.storage
                .file(matches.first.relativePath)
                .exists()) {
          missing.add(source.id);
        }
      }
      return missing;
    });
