import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/data/notification_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, AuthClientOptions;

Map<String, dynamic> setting(
  String type, {
  String? classId,
  bool enabled = false,
  String id = 'setting',
  String stamp = '2026-11-01T12:00:00.123456Z',
  String user = 'user',
}) => {
  'id': id,
  'user_id': user,
  'class_id': classId,
  'type': type,
  'enabled': enabled,
  'updated_at': stamp,
};

class SettingsFixture {
  SettingsFixture(
    FutureOr<http.Response> Function(http.Request) handler, {
    AppDatabase? database,
  }) : db = database ?? AppDatabase(NativeDatabase.memory()),
       client = SupabaseClient(
         'https://example.supabase.co',
         'fixture',
         httpClient: MockClient((request) async {
           final response = await handler(request);
           return http.Response.bytes(
             response.bodyBytes,
             response.statusCode,
             headers: response.headers,
             request: request,
           );
         }),
         authOptions: const AuthClientOptions(autoRefreshToken: false),
       ) {
    repo = NotificationSettingsRepository(
      db,
      client,
      'user',
      () => current,
      online: () => online,
    );
  }
  final AppDatabase db;
  final SupabaseClient client;
  late final NotificationSettingsRepository repo;
  bool current = true, online = true;
  Future<void> close() async {
    await db.close();
    await client.dispose();
  }
}

void main() {
  test('unknown cache differs from confirmed empty defaults; read survives file reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-preferences-',
    );
    final file = File('${directory.path}/account.sqlite');
    var f = SettingsFixture(
      (request) => http.Response(
        request.method == 'GET' ? '[]' : jsonEncode(setting('announcement')),
        200,
      ),
      database: AppDatabase(NativeDatabase(file)),
    );
    try {
      expect(await f.repo.read(), isNull);
      await f.repo.refresh();
      expect((await f.repo.read())!.enabled('announcement'), isTrue);
      await f.repo.set('announcement', null, false);
      await f.close();
      f = SettingsFixture(
        (_) => throw StateError('No network expected'),
        database: AppDatabase(NativeDatabase(file)),
      )..online = false;
      expect((await f.repo.read())!.classEnabled('class'), isTrue);
      expect((await f.repo.read())!.enabled('announcement'), isFalse);
      await expectLater(
        f.repo.set('announcement', null, false),
        throwsStateError,
      );
    } finally {
      await f.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'RPC parameters, confirmed cache and global/class independence',
    () async {
      final calls = <Map<String, dynamic>>[];
      final f = SettingsFixture((request) {
        if (request.method == 'GET') return http.Response('[]', 200);
        expect(request.url.path, endsWith('/rpc/set_notification_setting'));
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add(params);
        return http.Response(
          jsonEncode(
            setting(
              params['p_type'] as String,
              classId: params['p_class_id'] as String?,
              enabled: params['p_enabled'] as bool,
              id: params['p_class_id'] == null ? 'global' : 'class',
            ),
          ),
          200,
        );
      });
      addTearDown(f.close);
      await f.repo.refresh();
      await f.repo.set('announcement', null, false);
      await f.repo.set('announcement', 'class', true);
      expect(calls.first, {
        'p_type': 'announcement',
        'p_class_id': null,
        'p_enabled': false,
      });
      final saved = (await f.repo.read())!;
      expect(saved.enabled('announcement'), isFalse);
      expect(saved.classEnabled('class'), isTrue);
      f.online = false;
      expect((await f.repo.read())!.enabled('announcement'), isFalse);
    },
  );

  test('failed write preserves confirmed value; failed class retry targets only failures', () async {
    var fail = true;
    final calls = <String>[];
    final f = SettingsFixture((request) {
      if (request.method == 'GET') return http.Response('[]', 200);
      final p = jsonDecode(request.body) as Map<String, dynamic>;
      final type = p['p_type'] as String;
      calls.add(type);
      if (fail && type == 'announcement')
        return http.Response('{"message":"fixture","code":"42501"}', 403);
      return http.Response(
        jsonEncode(
          setting(
            type,
            classId: p['p_class_id'] as String?,
            enabled: p['p_enabled'] as bool,
            id: type,
          ),
        ),
        200,
      );
    });
    addTearDown(f.close);
    await f.repo.refresh();
    final failed = await f.repo.setClass('class', false);
    expect(failed, {'announcement'});
    expect(calls.length, 12);
    expect((await f.repo.read())!.classMixed('class'), isTrue);
    fail = false;
    calls.clear();
    expect(await f.repo.setClass('class', false, types: failed), isEmpty);
    expect(calls, ['announcement']);
    expect((await f.repo.read())!.classEnabled('class'), isFalse);
  });

  test(
    'separate repository refresh and write instances share the database queue',
    () async {
      final gate = Completer<void>(), started = Completer<void>();
      var posts = 0;
      final f = SettingsFixture((request) async {
        if (request.method == 'GET') {
          started.complete();
          await gate.future;
          return http.Response('[]', 200);
        }
        posts++;
        return http.Response(jsonEncode(setting('announcement')), 200);
      });
      addTearDown(f.close);
      final other = NotificationSettingsRepository(
        f.db,
        f.client,
        'user',
        () => true,
        online: () => true,
      );
      final pull = other.refresh();
      await started.future;
      final save = f.repo.set('announcement', null, false);
      await Future<void>.delayed(Duration.zero);
      expect(posts, 0);
      gate.complete();
      await pull;
      await save;
      expect((await f.repo.read())!.enabled('announcement'), isFalse);
    },
  );

  test('stale timestamp cannot overwrite confirmed setting; failed page cannot prune cache', () async {
    var mode = 'initial';
    final f = SettingsFixture((request) {
      if (mode == 'initial')
        return http.Response(jsonEncode([setting('announcement')]), 200);
      if (mode == 'old')
        return http.Response(
          jsonEncode([
            setting(
              'announcement',
              enabled: true,
              stamp: '2026-10-01T00:00:00Z',
            ),
          ]),
          200,
        );
      if (request.url.queryParameters.containsKey('id'))
        return http.Response('{"message":"fixture"}', 500);
      return http.Response(
        jsonEncode(
          List.generate(
            200,
            (i) => setting('material', id: i.toString().padLeft(4, '0')),
          ),
        ),
        200,
      );
    });
    addTearDown(f.close);
    await f.repo.refresh();
    mode = 'old';
    await f.repo.refresh();
    expect((await f.repo.read())!.enabled('announcement'), isFalse);
    mode = 'failed page';
    await expectLater(f.repo.refresh(), throwsA(anything));
    expect((await f.repo.read())!.enabled('announcement'), isFalse);
  });

  test(
    'late response after account change cannot establish a snapshot',
    () async {
      final gate = Completer<void>(), started = Completer<void>();
      final f = SettingsFixture((_) async {
        started.complete();
        await gate.future;
        return http.Response('[]', 200);
      });
      addTearDown(f.close);
      final pull = f.repo.refresh();
      final failed = expectLater(pull, throwsStateError);
      await started.future;
      f.current = false;
      gate.complete();
      await failed;
      f.current = true;
      expect(await f.repo.read(), isNull);
    },
  );

  test(
    'foreign recipient response is rejected, without caching private settings',
    () async {
      final f = SettingsFixture(
        (_) => http.Response(
          jsonEncode([setting('announcement', user: 'other')]),
          200,
        ),
      );
      addTearDown(f.close);
      await expectLater(f.repo.refresh(), throwsStateError);
      expect(await f.repo.read(), isNull);
    },
  );
}
