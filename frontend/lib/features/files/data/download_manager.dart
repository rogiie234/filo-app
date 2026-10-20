import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, StorageException, PostgrestException;
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import 'file_storage.dart';
import 'files_repository.dart';

class DownloadState {
  const DownloadState({
    this.received = 0,
    this.total = 0,
    this.running = false,
    this.error,
  });
  final int received, total;
  final bool running;
  final FileProblem? error;
  double? get progress =>
      total > 0 ? (received / total).clamp(0, 1).toDouble() : null;
}

class DownloadManager extends ChangeNotifier {
  DownloadManager(this.files, this.client, this.isCurrent);
  final FilesRepository files;
  final SupabaseClient client;
  final bool Function() isCurrent;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );
  final states = <String, DownloadState>{};
  final _tokens = <String, CancelToken>{};
  final _pending = <String, Future<LocalFileRecord?>>{};
  final _progress = StreamController<Map<String, DownloadState>>.broadcast();
  Stream<Map<String, DownloadState>> get progressStream => _progress.stream;
  bool _disposed = false;

  void _publish(String id, DownloadState state) {
    if (_disposed || !isCurrent()) {
      return;
    }
    states[id] = state;
    _progress.add(Map.unmodifiable(states));
    notifyListeners();
  }

  void cancel(String id) => _tokens[id]?.cancel('cancelled');
  static bool video(String name) => RegExp(
    r'\.(mp4|mov|avi|mkv|webm|m4v|3gp|wmv)(?:$|[?#])',
    caseSensitive: false,
  ).hasMatch(name);
  static String? driveId(String address) {
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.scheme != 'https' ||
        !['drive.google.com', 'www.drive.google.com'].contains(uri.host) ||
        uri.path.contains('/folders/')) {
      return null;
    }
    final match = RegExp(r'^/file/d/([A-Za-z0-9_-]+)').firstMatch(uri.path);
    final id =
        match?[1] ??
        (['/open', '/uc', '/download'].contains(uri.path)
            ? uri.queryParameters['id']
            : null);
    return id != null && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ? id : null;
  }

  Future<LocalFileRecord?> download(
    CachePostAttachment attachment,
    String classId,
    String postId,
  ) {
    return _pending.putIfAbsent(
      attachment.id,
      () => _download(
        attachment,
        classId,
        postId,
      ).whenComplete(() => _pending.remove(attachment.id)),
    );
  }

  Future<LocalFileRecord?> _download(
    CachePostAttachment attachment,
    String classId,
    String postId,
  ) async {
    final id = attachment.id;
    File? temporary;
    final token = CancelToken();
    _tokens[id] = token;
    try {
      final existing = await files.source(id);
      if (existing != null &&
          await files.storage.file(existing.relativePath).exists()) {
        return existing;
      }
      final networks = await Connectivity().checkConnectivity();
      if (!networks.any((n) => n != ConnectivityResult.none)) {
        throw const FileProblem(
          "You're offline. Connect to download.",
          kind: 'offline',
        );
      }
      _publish(id, const DownloadState(running: true));
      // Re-read live source metadata under RLS before requesting any URL.
      await client
          .from('posts')
          .select('id')
          .eq('id', postId)
          .eq('class_id', classId)
          .isFilter('deleted_at', null)
          .single();
      final source = await client
          .from('post_attachments')
          .select()
          .eq('id', id)
          .eq('post_id', postId)
          .isFilter('deleted_at', null)
          .single();
      final drive = source['kind'] == 'link';
      final original = source['url'] as String?;
      final googleId = drive ? driveId(original ?? '') : null;
      if (drive && (googleId == null || video(original ?? ''))) {
        throw const FileProblem(
          'This link opens in your browser.',
          kind: 'browser',
        );
      }
      var name = source['name'] as String;
      final expected =
          (source['size_bytes'] as num?)?.toInt() ?? maxLocalFileBytes;
      await files.storage.ensureSpace(expected);
      temporary = files.storage.file('temporary/${const Uuid().v4()}');
      String? mime;
      for (var attempt = 0; attempt < 2; attempt++) {
        if (token.isCancelled || !isCurrent()) {
          throw const FileProblem('', kind: 'cancelled');
        }
        final address = drive
            ? Uri.https('drive.usercontent.google.com', '/download', {
                'id': googleId!,
                'export': 'download',
              }).toString()
            : await client.storage
                  .from('materials')
                  .createSignedUrl(source['storage_path'] as String, 3600);
        try {
          final response = await _dio.get<ResponseBody>(
            address,
            cancelToken: token,
            options: Options(responseType: ResponseType.stream),
          );
          final body = response.data!;
          mime = response.headers.value('content-type')?.split(';').first;
          if (drive && mime?.startsWith('video/') == true) {
            token.cancel();
            throw const FileProblem(
              'This link opens in your browser.',
              kind: 'browser',
            );
          }
          final wireTotal =
              int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
          final total =
              (source['size_bytes'] as num?)?.toInt() ??
              (response.headers.value('content-encoding') == null
                  ? wireTotal
                  : 0);
          if (total > 0) {
            await files.storage.ensureSpace(total);
          }
          if (drive) {
            final disposition =
                response.headers.value('content-disposition') ?? '';
            final encoded = RegExp(
              "filename\\*=UTF-8''([^;]+)",
              caseSensitive: false,
            ).firstMatch(disposition);
            final plain = RegExp(
              r'filename="?([^";]+)',
              caseSensitive: false,
            ).firstMatch(disposition);
            name = encoded != null
                ? Uri.decodeComponent(encoded[1]!)
                : plain?[1] ?? name;
            name = name.split(RegExp(r'[/\\]')).last.trim();
            if (name.isEmpty) name = 'Drive file';
            if (video(name)) {
              token.cancel();
              throw const FileProblem(
                'This link opens in your browser.',
                kind: 'browser',
              );
            }
          }
          final output = temporary.openWrite();
          var received = 0;
          try {
            await for (final bytes in body.stream) {
              if (token.isCancelled || !isCurrent()) {
                throw const FileProblem('', kind: 'cancelled');
              }
              if (drive && received == 0) {
                final prefix = utf8
                    .decode(bytes.take(8192).toList(), allowMalformed: true)
                    .toLowerCase();
                if (mime == 'text/html' ||
                    prefix.trimLeft().startsWith('<!doctype html') ||
                    prefix.trimLeft().startsWith('<html')) {
                  if (prefix.contains('download anyway') ||
                      prefix.contains('virus scan') ||
                      prefix.contains('download-form')) {
                    throw const FileProblem(
                      'This file needs to be downloaded in your browser. Open the link to continue.',
                      kind: 'browser',
                    );
                  }
                  throw const FileProblem(
                    "Can't download this file. Ask your instructor to share it with anyone with the link.",
                    kind: 'locked',
                  );
                }
              }
              output.add(bytes);
              received += bytes.length;
              if (received % 1048576 < bytes.length) {
                await files.storage.ensureSpace(1048576);
              }
              _publish(
                id,
                DownloadState(running: true, received: received, total: total),
              );
            }
            await output.flush();
          } finally {
            await output.close();
          }
          if (token.isCancelled || !isCurrent()) {
            throw const FileProblem('', kind: 'cancelled');
          }
          // Content-Length may describe compressed transfer bytes; Dio exposes decompressed bytes.
          if (received == 0 ||
              (!drive &&
                  source['size_bytes'] != null &&
                  received != source['size_bytes'])) {
            throw const FileProblem('Download failed. Tap to retry.');
          }
          break;
        } on DioException catch (error) {
          final code = error.response?.statusCode;
          if (!drive && [400, 401].contains(code) && attempt == 0) continue;
          if (drive && [401, 403, 404].contains(code)) {
            throw const FileProblem(
              "Can't download this file. Ask your instructor to share it with anyone with the link.",
              kind: 'locked',
            );
          }
          if (error.type == DioExceptionType.connectionError) {
            throw const FileProblem(
              "You're offline. Connect to download.",
              kind: 'offline',
            );
          }
          if (CancelToken.isCancel(error)) {
            throw const FileProblem('', kind: 'cancelled');
          }
          if ([403, 404].contains(code)) {
            throw const FileProblem(
              'This item is no longer available.',
              kind: 'denied',
            );
          }
          if ([400, 401].contains(code)) {
            throw const FileProblem(
              'The download link expired. Tap to retry.',
              kind: 'expired',
            );
          }
          throw const FileProblem('Download failed. Tap to retry.');
        }
      }
      final row = await files.commit(
        temporary,
        name: name,
        source: 'class_material',
        attachmentId: id,
        classId: classId,
        postId: postId,
        mimeType: mime,
      );
      _publish(id, const DownloadState());
      return row;
    } on FileProblem catch (error) {
      _publish(
        id,
        DownloadState(error: error.kind == 'cancelled' ? null : error),
      );
      return null;
    } on FileSystemException catch (error) {
      _publish(
        id,
        DownloadState(
          error: FileProblem(
            [28, 112].contains(error.osError?.errorCode)
                ? 'Not enough space on your phone.'
                : 'Download failed. Tap to retry.',
            kind: [28, 112].contains(error.osError?.errorCode)
                ? 'space'
                : 'failed',
          ),
        ),
      );
      return null;
    } on StorageException {
      _publish(
        id,
        const DownloadState(
          error: FileProblem(
            'This item is no longer available.',
            kind: 'denied',
          ),
        ),
      );
      return null;
    } on PostgrestException {
      _publish(
        id,
        const DownloadState(
          error: FileProblem(
            'This item is no longer available.',
            kind: 'denied',
          ),
        ),
      );
      return null;
    } catch (_) {
      _publish(
        id,
        const DownloadState(
          error: FileProblem('Download failed. Tap to retry.'),
        ),
      );
      return null;
    } finally {
      token.cancel();
      _tokens.remove(id);
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _tokens.values) {
      token.cancel();
    }
    _dio.close(force: true);
    unawaited(_progress.close());
    super.dispose();
  }
}
