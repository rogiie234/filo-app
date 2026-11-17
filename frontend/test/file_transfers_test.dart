import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/core/sync/outbox_processor.dart';
import 'package:filo/core/sync/sqlite_outbox.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/drive_backup/data/drive_api.dart';
import 'package:filo/features/drive_backup/data/drive_backup_service.dart';
import 'package:filo/features/files/data/download_manager.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected headers');
}

class _Drive implements DriveApi {
  final failed = <String>{};
  final uploaded = <String, List<int>>{};
  final started = <String>[];
  bool confirm = true;
  bool permissionDenied = false;
  DriveResponse response(int status, Map<String, Object?> body) =>
      DriveResponse(status, _Headers(), jsonEncode(body));
  @override
  Future<DriveResponse> metadata(String id) async {
    if (permissionDenied) {
      throw const DrivePermissionRequired('Reconnect Drive.');
    }
    if (id == 'folder') {
      return response(200, {'mimeType': 'application/vnd.google-apps.folder'});
    }
    if (failed.contains(id)) throw const DriveFailure('This file was refused.');
    final bytes = uploaded[id];
    return bytes == null
        ? response(404, {})
        : response(200, {
            'size': '${bytes.length}',
            'md5Checksum': confirm ? md5.convert(bytes).toString() : 'wrong',
          });
  }

  @override
  Future<Uri> startUpload({
    required String fileId,
    required String folderId,
    required String name,
    required String digest,
    required int size,
    bool update = false,
  }) async {
    started.add(fileId);
    return Uri.https('www.googleapis.com', '/$fileId');
  }

  @override
  Future<DriveResponse> uploadChunk(
    Uri uri,
    List<int> bytes,
    int start,
    int total,
  ) async {
    uploaded[uri.pathSegments.last] = bytes;
    return response(200, {});
  }

  @override
  void requireSuccess(DriveResponse value) {
    if (value.status != 200) throw const DriveFailure('Request failed.');
  }

  @override
  void close() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected Drive call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase db;
  late FilesRepository files;
  late SupabaseClient client;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('filo-transfers-');
    db = AppDatabase(NativeDatabase.memory());
    final storage = FileStorage(Directory('${root.path}/files/account'));
    await storage.createFolder('blobs');
    await storage.createFolder('temporary');
    files = FilesRepository(db, storage);
    FlutterSecureStorage.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.filo.filo/storage'),
      (_) async => 100000000,
    );
    client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.pathSegments.last == 'posts'
                ? {'id': 'post'}
                : {
                    'id': 'attachment',
                    'post_id': 'post',
                    'kind': 'link',
                    'name': 'note.txt',
                    'url': 'https://drive.google.com/file/d/file/view',
                  },
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  });
  tearDown(() async {
    await client.dispose();
    await db.close();
    await root.delete(recursive: true);
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'dev.fluttercommunity.plus/connectivity',
      'com.filo.filo/storage',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  for (final cancelled in [false, true]) {
    test(
      'real download cleans partial bytes after ${cancelled ? 'cancellation' : 'stream failure'} and retries',
      () async {
        final dio = Dio();
        var fail = true;
        late DownloadManager manager;
        Stream<Uint8List> body() async* {
          yield Uint8List.fromList([65, 66]);
          if (fail) {
            if (cancelled) {
              manager.cancel('attachment');
            } else {
              throw const SocketException('interrupted');
            }
          }
          yield Uint8List.fromList([67]);
        }

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: ResponseBody(
                    body(),
                    200,
                    headers: {
                      'content-type': ['text/plain'],
                    },
                  ),
                ),
              );
            },
          ),
        );
        manager = DownloadManager(files, client, () => true, dio: dio);
        addTearDown(manager.dispose);
        final attachment = CachePostAttachment.fromJson({
          'id': 'attachment',
          'postId': 'post',
          'kind': 'link',
          'name': 'note.txt',
          'url': 'https://drive.google.com/file/d/file/view',
          'sortOrder': 0,
          'createdAt': 0,
          'updatedAt': 0,
        });
        expect(await manager.download(attachment, 'class', 'post'), isNull);
        expect(
          await Directory('${files.storage.root.path}/temporary')
              .list()
              .toList(),
          isEmpty,
        );
        expect(await db.select(db.localFiles).get(), isEmpty);
        fail = false;
        // A fresh authorized read succeeds; the failed transfer holds no stale lease.
        // Class folder creation needs the real cached class only for its display name.
        final result = await manager.download(attachment, 'class', 'post');
        expect(result, isNotNull);
        expect(
          await files.storage.file(result!.relativePath).readAsString(),
          'ABC',
        );
      },
    );
  }

  Future<LocalFileRecord> add(String name) async {
    final picked = File('${root.path}/$name');
    await picked.writeAsString(name);
    return files.commit(picked, name: name, source: 'personal_upload');
  }

  Future<DriveBackupService> backup(
    _Drive api,
    List<LocalFileRecord> rows,
  ) async {
    await db.customStatement(
      "UPDATE drive_backup_settings SET enabled=1,folder_id='folder'",
    );
    final service = DriveBackupService(
      db,
      'account',
      GoogleSignIn.instance,
      client,
      () => true,
      managedByOutbox: true,
      api: api,
    );
    addTearDown(service.dispose);
    await service.reload();
    for (final row in rows) {
      await service.enqueue(
        files.storage.file(row.relativePath),
        row.name,
        localFileId: row.id,
      );
    }
    await db.customStatement(
      'UPDATE drive_backup_jobs SET file_id=local_file_id',
    );
    return service;
  }

  test(
    'Drive permission recovery survives reload until explicitly disabled',
    () async {
      final row = await add('keep.txt');
      final service = await backup(_Drive()..permissionDenied = true, [row]);
      await service.run(localFileId: row.id);
      expect(service.permissionRequired, isTrue);
      expect(service.enabled, isFalse);
      final reopened = await backup(_Drive(), []);
      expect(reopened.permissionRequired, isTrue);
      await reopened.disable();
      await service.reload();
      expect(service.permissionRequired, isFalse);
      expect((await files.get(row.id))!.backedUpAt, isNull);
      expect(await files.storage.file(row.relativePath).exists(), isTrue);
    },
  );

  for (final confirmed in [true, false]) {
    test(
      'real backup marks completion only with matching Drive receipt: $confirmed',
      () async {
        final row = await add('keep.txt');
        final api = _Drive()..confirm = confirmed;
        final service = await backup(api, [row]);
        if (confirmed) {
          await service.backupLocalFile(row, files);
        } else {
          await expectLater(
            service.backupLocalFile(row, files),
            throwsA(isA<DriveFailure>()),
          );
        }
        final job =
            (await db
                    .customSelect('SELECT * FROM drive_backup_jobs')
                    .getSingle())
                .data;
        expect(job['status'], confirmed ? 'complete' : 'queued');
        expect(
          (await files.get(row.id))!.backedUpAt,
          confirmed ? isNotNull : isNull,
        );
        expect(await File(job['local_path'] as String).exists(), !confirmed);
        expect(
          await files.storage.file(row.relativePath).readAsString(),
          'keep.txt',
        );
      },
    );
  }

  test(
    'failed backup consumes only its own retry; next outbox file completes',
    () async {
      final bad = await add('bad.txt'), good = await add('good.txt');
      final api = _Drive()..failed.add(bad.id);
      final service = await backup(api, [bad, good]);
      final coordinator = SyncCoordinator(
        db,
        client,
        'account',
        () => true,
        backup: service,
        files: files,
      );
      addTearDown(coordinator.dispose);
      final outbox = SqliteOutbox(db);
      await outbox.enqueue('first', 'drive_backup', {'file_id': bad.id});
      await outbox.enqueue('second', 'drive_backup', {'file_id': good.id});
      await OutboxProcessor(outbox, coordinator.dispatch).flush();
      final records = await db.select(db.outbox).get();
      expect(records.singleWhere((r) => r.id == 'first').attempts, 1);
      expect(records.singleWhere((r) => r.id == 'second').status, 'complete');
      expect((await files.get(bad.id))!.backedUpAt, isNull);
      expect((await files.get(good.id))!.backedUpAt, isNotNull);
      expect(api.started, [good.id]);
    },
  );
}
