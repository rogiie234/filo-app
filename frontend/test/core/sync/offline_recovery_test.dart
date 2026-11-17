import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/core/sync/sqlite_outbox.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';

import '../../features/exams/exam_test_support.dart';

void main() {
  test('missing parents retain cursor and payload for recovery', () async {
    const stamp = '2026-11-17T00:00:00Z';
    var failPosts = true;
    final room = {
      'id': 'room',
      'owner_id': 'owner',
      'course': 'Course',
      'section': 'A',
      'school_year': '2026',
      'join_code': 'ABC123',
      'created_at': stamp,
      'updated_at': stamp,
    };
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final params = request.url.queryParameters;
        Object body = [];
        var status = 200;
        if (table == 'posts' && failPosts) {
          status = 500;
          body = {'message': 'temporary', 'code': 'XX000'};
        } else if (!params.containsKey('or') &&
            params['id']?.startsWith('gt.') != true) {
          body = switch (table) {
            'profiles' => [
              for (final id in ['student', 'owner'])
                {
                  'id': id,
                  'role': id == 'student' ? 'student' : 'instructor',
                  'display_name': id,
                  'created_at': stamp,
                  'updated_at': stamp,
                },
            ],
            'classes' => [room],
            'class_members' => [
              {
                'id': 'member',
                'class_id': 'room',
                'student_id': 'student',
                'status': 'active',
                'requested_at': stamp,
                'created_at': stamp,
                'updated_at': stamp,
              },
            ],
            'posts' => [
              for (var i = 0; i < 2; i++)
                {
                  'id': 'assignment-$i',
                  'class_id': 'room',
                  'author_id': 'owner',
                  'kind': 'assignment',
                  'title': 'Assignment',
                  'points': 10,
                  'accept_late': true,
                  'allow_files': true,
                  'max_files': 5,
                  'due_at': '2026-12-01T00:00:00Z',
                  'created_at': stamp,
                  'updated_at': stamp,
                },
            ],
            'submissions' => [
              for (var i = 0; i < 2; i++)
                {
                  'id': 'submission-$i',
                  'post_id': 'assignment-$i',
                  'student_id': 'student',
                  'status': 'draft',
                  'is_late': false,
                  'created_at': stamp,
                  'updated_at': '2026-11-17T00:00:0${i + 1}Z',
                },
            ],
            _ => [],
          };
        }
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final db = AppDatabase(NativeDatabase.memory());
    final sync = SyncCoordinator(db, client, 'student', () => true);
    addTearDown(() async {
      sync.dispose();
      await db.close();
      await client.dispose();
    });
    await db.customStatement(
      "INSERT INTO sync_cursors(table_name,stamp) VALUES('submissions',?)",
      [stamp],
    );
    await sync.run();
    expect(sync.errors, contains('submissions'));
    expect(await db.select(db.cacheSubmissions).get(), isEmpty);
    expect(
      (await db
              .customSelect(
                "SELECT stamp FROM sync_cursors WHERE table_name='submissions'",
              )
              .getSingle())
          .read<String>('stamp'),
      stamp,
    );
    expect(
      await db
          .customSelect(
            "SELECT id FROM sync_payloads WHERE table_name='submissions'",
          )
          .get(),
      isEmpty,
    );
    failPosts = false;
    await sync.run();
    expect(sync.errors, isNot(contains('submissions')));
    expect(
      (await db.select(db.cacheSubmissions).get()).map((s) => s.id),
      unorderedEquals(['submission-0', 'submission-1']),
    );
  });

  test(
    'leave flush bypasses stalled sync and preserves unrelated jobs and leases',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final sent = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          if (table == 'class_members' && !release.isCompleted) {
            if (!entered.isCompleted) entered.complete();
            await release.future;
          }
          if (table == 'log_leave') {
            sent.add((jsonDecode(request.body) as Map)['p_event'] as String);
          }
          return http.Response(
            table == 'log_leave' ? 'null' : '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final db = AppDatabase(NativeDatabase.memory());
      var foreground = true, current = true;
      final sync = SyncCoordinator(
        db,
        client,
        'student',
        () => current,
        canSendLeaveEvents: () => foreground,
      );
      final outbox = SqliteOutbox(db), exam = ExamStore(db);
      await exam.cache(
        ExamAttempt({...examPayload(), 'leave_limit': 1}),
        examEpoch,
        examEpoch,
      );
      await exam.queueLeave('ready', 'session', examEpoch.toIso8601String());
      await outbox.retry(
        'ready',
        0,
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
        failed: false,
        error: 'Waiting for connectivity or authorization.',
      );
      for (final id in ['leased', 'backoff', 'other-session']) {
        await outbox.enqueue(id, 'leave_event', {
          'session_id': id == 'other-session' ? 'other' : 'session',
          'left_at': examEpoch.toIso8601String(),
        });
      }
      await outbox.enqueue('drive', 'drive_backup', {'file_id': 'file'});
      await outbox.enqueue('read', 'notification_read', {
        'notification_id': 'n',
      });
      await db.customStatement(
        'INSERT INTO outbox_schedule(id,lease_until) VALUES(?,?)',
        [
          'leased',
          DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        ],
      );
      await outbox.retry(
        'backoff',
        1,
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
        failed: false,
        error: 'network',
      );
      final full = sync.run();
      try {
        await entered.future;
        await sync.flushLeaveEvents('session');
        expect(sent, isEmpty);
        await exam.mergeIntegrity('session', {'ready': true});
        foreground = false;
        await sync.flushLeaveEvents('session');
        expect(sent, isEmpty);
        foreground = true;
        await Future.wait([
          sync.flushLeaveEvents('session'),
          sync.flushLeaveEvents('session'),
        ]).timeout(const Duration(seconds: 3));
        expect(sent, ['ready']);
        expect(
          (await db.select(db.outbox).get())
              .where((r) => r.status == 'complete')
              .map((r) => r.id),
          ['ready'],
        );
        current = false;
        await sync.flushLeaveEvents('other');
        expect(sent, ['ready']);
      } finally {
        current = false;
        release.complete();
        await full;
        sync.dispose();
        await db.close();
        await client.dispose();
      }
    },
  );
}
