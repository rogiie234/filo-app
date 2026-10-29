import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../files/application/files_providers.dart';
import '../../files/data/files_repository.dart';
import '../domain/ai_sources.dart';
import 'file_text_cache.dart';
import 'lesson_text_extractor.dart';

class AiSourceLoader {
  AiSourceLoader(
    this.files,
    this.client,
    this.extractor,
    this.cache,
    this.isCurrent, {
    this.createDio,
  });
  final FilesRepository files;
  final SupabaseClient client;
  final LessonTextExtractor extractor;
  final FileTextCache cache;
  final bool Function() isCurrent;
  final Dio Function()? createDio;

  Future<LessonText> classMaterial(
    ClassFileEntry entry,
    String classId,
    String quizId,
    AiCancelToken cancel,
    void Function(ExtractionProgress) progress,
  ) async {
    final id = entry.attachment.id;
    cancel.check();
    await client
        .from('posts')
        .select('id')
        .eq('id', entry.post.id)
        .eq('class_id', classId)
        .isFilter('deleted_at', null)
        .single();
    final metadata = await client
        .from('post_attachments')
        .select('id,name,size_bytes,kind,storage_path')
        .eq('id', id)
        .eq('post_id', entry.post.id)
        .isFilter('deleted_at', null)
        .single();
    final name = metadata['name'] as String;
    checkAiSource(name, (metadata['size_bytes'] as num?)?.toInt() ?? 0);
    if (metadata['kind'] != 'file')
      throw const LessonReadException(
        'UNSUPPORTED',
        'This file type is not supported.',
      );
    cancel.check();
    if (!isCurrent()) throw const AiCancelled();
    final hit = await cache.find('att:$id');
    if (hit != null) {
      await cache.associate(quizId, hit.sourceKey);
      return hit;
    }
    final local = await files.source(id);
    if (local != null &&
        await files.storage.file(local.relativePath).exists()) {
      return extractor.extract(
        files.storage.file(local.relativePath).path,
        extension(name),
        attachmentId: id,
        draftQuizId: quizId,
        cancel: cancel,
        onProgress: progress,
      );
    }
    File? temporary;
    var deferCleanup = false;
    var extractionStarted = false;
    final dio =
        createDio?.call() ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 40),
          ),
        );
    final downloadCancel = CancelToken();
    cancel.cancelled.then((_) => downloadCancel.cancel());
    try {
      progress(const ExtractionProgress('Downloading file...'));
      final expected =
          (metadata['size_bytes'] as num?)?.toInt() ??
          LessonTextExtractor.maxFileBytes;
      await files.storage.ensureSpace(expected);
      final address = await client.storage
          .from('materials')
          .createSignedUrl(metadata['storage_path'] as String, 120);
      cancel.check();
      temporary = files.storage.file('temporary/ai-${const Uuid().v4()}');
      final response = await dio.get<ResponseBody>(
        address,
        options: Options(responseType: ResponseType.stream),
        cancelToken: downloadCancel,
      );
      final total = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (total != null && total > LessonTextExtractor.maxFileBytes)
        throw lessonTooLarge;
      var count = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in response.data!.stream) {
          cancel.check();
          if (!isCurrent()) throw const AiCancelled();
          count += chunk.length;
          if (count > LessonTextExtractor.maxFileBytes) throw lessonTooLarge;
          sink.add(chunk);
          progress(
            ExtractionProgress(
              'Downloading file...',
              completed: count,
              total: total,
            ),
          );
        }
      } finally {
        await sink.close();
      }
      cancel.check();
      extractionStarted = true;
      return await extractor.extract(
        temporary.path,
        extension(name),
        attachmentId: id,
        draftQuizId: quizId,
        cancel: cancel,
        onProgress: progress,
      );
    } on AiCancelled {
      deferCleanup = true;
      rethrow;
    } on LessonReadException catch (e) {
      deferCleanup = e.code == 'TIMEOUT';
      rethrow;
    } finally {
      dio.close(force: true);
      if (temporary != null) {
        if (extractionStarted && (cancel.isCancelled || deferCleanup)) {
          unawaited(_removeTemporaryAfterDrain(temporary));
        } else {
          await _removeTemporary(temporary);
        }
      }
    }
  }
}

Future<void> _removeTemporaryAfterDrain(File file) async {
  await LessonTextExtractor.waitUntilIdle();
  await _removeTemporary(file);
}

Future<void> _removeTemporary(File file) async {
  try {
    await file.delete();
  } catch (_) {}
}

String extension(String name) => name.split('.').last.toLowerCase();
void checkAiSource(String name, int size) {
  if (size > LessonTextExtractor.maxFileBytes) throw lessonTooLarge;
  if (!LessonTextExtractor.supported.contains(extension(name))) {
    throw const LessonReadException(
      'UNSUPPORTED',
      'This file type is not supported.',
    );
  }
}
