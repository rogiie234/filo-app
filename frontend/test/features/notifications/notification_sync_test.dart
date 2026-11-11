import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/core/sync/sqlite_outbox.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/data/inbox_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

const user = '56c8a059-a110-45a7-804f-ff1e0d8b2da9';
const stamp = '2026-11-01T01:00:00.123456Z';
Map<String, Object?> notice(String id) => {
  'id': id,
  'recipient_id': user,
  'class_id': null,
  'type': 'announcement',
  'title': id,
  'created_at': stamp,
  'updated_at': stamp,
  'read_at': null,
};

void main() {
  for (final outcome in ['success', 'failed ids page', 'switched account']) {
    test('delta cursor and paginated deletion reconciliation: $outcome', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.saveProfile(
        CacheProfilesCompanion.insert(
          id: user,
          role: 'student',
          displayName: 'Fixture',
        ),
      );
      await db
          .into(db.cacheNotifications)
          .insert(
            CacheNotificationsCompanion.insert(
              id: 'stale',
              recipientId: user,
              type: 'material',
              title: 'Stale',
            ),
          );
      await db.customStatement(
        "INSERT INTO sync_cursors(table_name,stamp) VALUES('notifications',?)",
        [stamp],
      );
      var current = true;
      var deltaPages = 0;
      var idPages = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          http.Response json(Object? value, [int status = 200]) =>
              http.Response(
                jsonEncode(value),
                status,
                request: request,
                headers: {'content-type': 'application/json'},
              );
          if (request.url.pathSegments.last != 'notifications') return json([]);
          final p = request.url.queryParameters;
          if (p['select'] == 'id') {
            idPages++;
            if (p.containsKey('id')) {
              if (outcome == 'failed ids page') {
                return json({'message': 'temporary', 'code': 'XX000'}, 500);
              }
              if (outcome == 'switched account') current = false;
              return json([]);
            }
            return json(
              List.generate(
                200,
                (i) => {'id': 'n${i.toString().padLeft(3, '0')}'},
              ),
            );
          }
          deltaPages++;
          expect(p['updated_at'], 'gte.$stamp');
          expect(p['recipient_id'], 'eq.$user');
          if (p.containsKey('or')) {
            expect(p['or'], contains(stamp));
            expect(p['or'], contains('n199'));
            return json([]);
          }
          return json(
            List.generate(
              200,
              (i) => notice('n${i.toString().padLeft(3, '0')}'),
            ),
          );
        }),
      );
      final sync = SyncCoordinator(db, client, user, () => current);
      try {
        await sync.run();
        expect(deltaPages, 2);
        expect(idPages, 2);
        final stale = await (db.select(
          db.cacheNotifications,
        )..where((n) => n.id.equals('stale'))).get();
        expect(stale.isEmpty, outcome == 'success');
        if (outcome == 'failed ids page') {
          expect(sync.errors, contains('notifications'));
        }
      } finally {
        sync.dispose();
        await db.close();
        await client.dispose();
      }
    });
  }

  test('failed read upload survives pull, retries unchanged and tolerates server deletion', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.saveProfile(
      CacheProfilesCompanion.insert(
        id: user,
        role: 'student',
        displayName: 'Fixture',
      ),
    );
    await db
        .into(db.cacheNotifications)
        .insert(
          CacheNotificationsCompanion.insert(
            id: 'notice',
            recipientId: user,
            type: 'material',
            title: 'Fixture',
          ),
        );
    await InboxRepository(db, user, () => true).markRead('notice');
    var fail = true;
    var deleted = false;
    final timestamps = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        http.Response json(Object? value, [int status = 200]) => http.Response(
          jsonEncode(value),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
        if (request.url.pathSegments.last != 'notifications') return json([]);
        final p = request.url.queryParameters;
        if (request.method == 'PATCH') {
          expect(p['recipient_id'], 'eq.$user');
          timestamps.add(
            (jsonDecode(request.body) as Map)['read_at'] as String,
          );
          return fail
              ? json({'message': 'offline', 'code': 'XX000'}, 500)
              : json(null);
        }
        if (deleted || p.containsKey('or') || p.containsKey('id')) {
          return json([]);
        }
        return json([
          p['select'] == 'id' ? {'id': 'notice'} : notice('notice'),
        ]);
      }),
    );
    final sync = SyncCoordinator(db, client, user, () => true);
    try {
      await sync.run();
      expect(
        (await db.select(db.cacheNotifications).get()).single.readAt,
        isNotNull,
      );
      expect((await db.select(db.outbox).get()).single.status, 'pending');
      await (db.update(db.outbox)..where((o) => o.id.equals('read:notice')))
          .write(const OutboxCompanion(status: Value('failed')));
      await sync.run();
      expect(
        (await db.select(db.cacheNotifications).get()).single.readAt,
        isNotNull,
      );
      fail = false;
      deleted = true;
      await SqliteOutbox(db).retryFailed();
      await sync.run();
      expect(timestamps.length, 2);
      expect(timestamps.toSet().length, 1);
      expect((await db.select(db.outbox).get()).single.status, 'complete');
      expect(await db.select(db.cacheNotifications).get(), isEmpty);
    } finally {
      sync.dispose();
      await db.close();
      await client.dispose();
    }
  });
}
