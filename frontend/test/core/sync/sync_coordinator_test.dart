import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/data/local/app_database.dart';

void main() {
  for (final scenario in [
    'deleted',
    'empty',
    'failed page',
    'account changed',
  ]) {
    test('notification next-sync reconciliation: $scenario', () async {
      const user = '56c8a059-a110-45a7-804f-ff1e0d8b2da9';
      const stamp = '2026-10-18T12:00:00.123456Z';
      var secondSync = false;
      var current = true;
      var secondSnapshotRequested = false;
      Map<String, Object?> notice(String id) => {
        'id': id,
        'recipient_id': user,
        'class_id': null,
        'type': 'announcement',
        'title': id,
        'created_at': stamp,
        'updated_at': stamp,
      };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          http.Response json(Object? value, [int status = 200]) =>
              http.Response(
                jsonEncode(value),
                status,
                headers: {'content-type': 'application/json'},
                request: request,
              );
          final table = request.url.pathSegments.last;
          final nextPage =
              request.url.queryParameters.containsKey('or') ||
              request.url.queryParameters['id']?.startsWith('gt.') == true;
          if (table == 'finalize_accessible_exams') return json(null);
          if (table == 'notifications') {
            if (secondSync) {
              secondSnapshotRequested |=
                  request.url.queryParameters['updated_at'] ==
                  'gte.1970-01-01T00:00:00Z';
              if (scenario == 'failed page' && nextPage) {
                return json({
                  'message': 'temporary failure',
                  'code': 'XX000',
                }, 500);
              }
              if (scenario == 'account changed') current = false;
              return json(
                nextPage || scenario == 'empty' ? [] : [notice('recent')],
              );
            }
            return json(nextPage ? [] : [notice('expired'), notice('recent')]);
          }
          if (nextPage ||
              request.url.queryParameters['id']?.startsWith('gt.') == true) {
            return json([]);
          }
          if (table == 'profiles') {
            return json([
              {
                'id': user,
                'role': 'student',
                'display_name': 'Student',
                'created_at': stamp,
                'updated_at': stamp,
              },
            ]);
          }
          return json([]);
        }),
      );
      final db = AppDatabase(NativeDatabase.memory());
      final coordinator = SyncCoordinator(db, client, user, () => current);
      try {
        await coordinator.run();
        expect(coordinator.errors, isEmpty);
        expect((await db.select(db.cacheNotifications).get()).length, 2);
        secondSync = true;
        await coordinator.run();
        expect(secondSnapshotRequested, isFalse);
        final ids = (await db.select(db.cacheNotifications).get()).map(
          (n) => n.id,
        );
        expect(
          ids,
          unorderedEquals(switch (scenario) {
            'deleted' => ['recent'],
            'empty' => <String>[],
            _ => ['expired', 'recent'],
          }),
        );
        if (scenario == 'failed page') {
          expect(coordinator.errors, contains('notifications'));
        }
      } finally {
        coordinator.dispose();
        await db.close();
        await client.dispose();
      }
    });
  }

  test(
    'exam expiry failure does not block pulls and retries on next sync',
    () async {
      const user = '56c8a059-a110-45a7-804f-ff1e0d8b2da9';
      var expiryCalls = 0;
      var notificationPulls = 0;
      final transport = MockClient((request) async {
        final endpoint = request.url.pathSegments.last;
        if (endpoint == 'finalize_accessible_exams') {
          expiryCalls++;
          return http.Response(
            expiryCalls == 1
                ? '{"message":"temporary failure","code":"XX000"}'
                : 'null',
            expiryCalls == 1 ? 500 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (endpoint == 'notifications') notificationPulls++;
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: transport,
      );
      final db = AppDatabase(NativeDatabase.memory());
      final coordinator = SyncCoordinator(db, client, user, () => true);
      try {
        await coordinator.run();
        expect(expiryCalls, 1);
        expect(coordinator.errors, contains('exam_expiry'));
        expect(notificationPulls, greaterThan(0));
        await coordinator.run();
        expect(expiryCalls, 2);
        expect(coordinator.errors, isNot(contains('exam_expiry')));
      } finally {
        coordinator.dispose();
        await db.close();
        await client.dispose();
      }
    },
  );

  test(
    'a failed posts pull does not prevent notification cache updates',
    () async {
      const user = '56c8a059-a110-45a7-804f-ff1e0d8b2da9';
      const stamp = '2026-10-18T12:00:00.123456Z';
      final transport = MockClient((request) async {
        final table = request.url.pathSegments.last;
        final params = request.url.queryParameters;
        if (params.containsKey('or') ||
            params['id']?.startsWith('gt.') == true) {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (table == 'posts') {
          return http.Response(
            '{"message":"temporary failure","code":"XX000","details":null,"hint":null}',
            500,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final rows = table == 'profiles'
            ? [
                {
                  'id': user,
                  'role': 'student',
                  'display_name': 'Student',
                  'created_at': stamp,
                  'updated_at': stamp,
                },
              ]
            : table == 'notifications'
            ? [
                {
                  'id': 'test-notification',
                  'recipient_id': user,
                  'class_id': null,
                  'type': 'material',
                  'title': 'After failed table',
                  'created_at': stamp,
                  'updated_at': stamp,
                },
              ]
            : [];
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: transport,
      );
      final db = AppDatabase(NativeDatabase.memory());
      final coordinator = SyncCoordinator(db, client, user, () => true);
      try {
        await coordinator.run();
        expect(coordinator.errors, contains('posts'));
        final inbox = await db.select(db.cacheNotifications).get();
        expect(inbox.single.title, 'After failed table');
        final cursor = await db
            .customSelect(
              "SELECT stamp FROM sync_cursors WHERE table_name='notifications'",
            )
            .getSingle();
        expect(cursor.read<String>('stamp'), stamp);
      } finally {
        coordinator.dispose();
        await db.close();
        await client.dispose();
      }
    },
  );
}
