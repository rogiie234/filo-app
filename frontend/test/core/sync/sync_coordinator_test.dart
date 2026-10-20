import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/data/local/app_database.dart';

void main() {
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
          );
        }
        if (table == 'posts') {
          return http.Response(
            '{"message":"temporary failure","code":"XX000","details":null,"hint":null}',
            500,
            headers: {'content-type': 'application/json'},
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
