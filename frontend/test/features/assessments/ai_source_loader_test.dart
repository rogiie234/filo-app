import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/ai_source_loader.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/lesson_text_extractor.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SourcePost implements CachePost {
  @override
  String get id => 'post';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SourceAttachment implements CachePostAttachment {
  @override
  String get id => 'attachment';
  @override
  String get name => 'lesson.txt';
  @override
  int? get sizeBytes => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SourceAdapter implements HttpClientAdapter {
  SourceAdapter(this.stream);
  final Stream<Uint8List> Function() stream;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(stream(), 200);
  @override
  void close({bool force = false}) {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.filo.filo/storage'),
      (_) async => 1024 * 1024 * 1024,
    ),
  );
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.filo.filo/storage'),
      null,
    ),
  );
  for (final oversized in [false, true]) {
    test('temporary class download cleanup; oversized=$oversized', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dir = await Directory.systemTemp.createTemp('filo-ai-source');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/temporary').create();
      final original = await File('${dir.path}/original.txt')
          .writeAsString('User download');
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          final Object body = path.contains('/sign/')
              ? {'signedURL': '/object/sign/materials/lesson.txt?token=test'}
              : path.endsWith('/posts')
              ? {'id': 'post'}
              : {
                  'id': 'attachment',
                  'name': 'lesson.txt',
                  'kind': 'file',
                  'storage_path': 'lesson.txt',
                  'size_bytes': null,
                };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final files = FilesRepository(db, FileStorage(dir));
      final cache = FileTextCache(db);
      final loader = AiSourceLoader(
        files,
        client,
        LessonTextExtractor(cache: cache),
        cache,
        () => true,
        createDio: () => Dio()
          ..httpClientAdapter = SourceAdapter(() async* {
            if (oversized) {
              for (var i = 0; i < 11; i++) {
                yield Uint8List(1024 * 1024);
              }
            } else {
              yield Uint8List.fromList(utf8.encode('A readable rule.'));
            }
          }),
      );
      final operation = loader.classMaterial(
        ClassFileEntry(SourcePost(), SourceAttachment()),
        'class',
        'quiz',
        AiCancelToken(),
        (_) {},
      );
      if (oversized) {
        await expectLater(
          operation,
          throwsA(
            isA<LessonReadException>().having(
              (e) => e.code,
              'code',
              'TOO_LARGE',
            ),
          ),
        );
        expect(await cache.find('att:attachment'), isNull);
      } else {
        expect((await operation).text, 'A readable rule.');
        expect(await cache.find('att:attachment'), isNotNull);
      }
      expect(await Directory('${dir.path}/temporary').list().toList(), isEmpty);
      expect(await original.readAsString(), 'User download');
    });
  }
}
