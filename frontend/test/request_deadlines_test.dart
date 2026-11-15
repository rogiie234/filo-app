import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/core/sync/outbox_processor.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/data/class_remote.dart';

void main() {
  for (final action in [
    'notification_read',
    'class mutation',
    'create class',
  ]) {
    test('$action stops waiting after 20 seconds without replaying', () async {
      final receipt = Completer<http.Response>();
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) {
          requests++;
          return receipt.future;
        }),
      );
      final db = AppDatabase(NativeDatabase.memory());
      final sync = SyncCoordinator(db, client, 'user', () => true);
      final remote = SupabaseClassRemote(client);
      addTearDown(() async {
        sync.dispose();
        await db.close();
        await client.dispose();
      });
      final Future<dynamic> work = switch (action) {
        'notification_read' => sync.dispatch(
          const QueuedAction('read', 'notification_read', {
            'notification_id': 'notice',
            'read_at': '2026-11-15T00:00:00Z',
          }, 0),
        ),
        'class mutation' => remote.call('archive_class', {'p_class': 'class'}),
        _ => remote.createClass({'course': 'Course'}),
      };
      await expectLater(work, throwsA(isA<TimeoutException>()));
      expect(requests, 1);
      receipt.complete(
        http.Response('{}', 200, headers: {'content-type': 'application/json'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
    });
  }
}
