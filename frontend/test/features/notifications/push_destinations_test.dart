import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:filo/core/notifications/push_events.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/data/inbox_repository.dart';
import 'package:filo/features/notifications/data/notification_destination_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

const userId = '00000000-0000-4000-8000-000000000001';
const classId = '00000000-0000-4000-8000-000000000002';
const targetId = '00000000-0000-4000-8000-000000000003';
const noticeId = '00000000-0000-4000-8000-000000000004';
const stamp = '2026-11-01T12:00:00.123456Z';

CacheNotification notice({
  String target = 'post',
  String type = 'announcement',
  String? id,
}) => CacheNotification(
  id: id ?? noticeId,
  recipientId: userId,
  classId: classId,
  type: type,
  title: 'Fixture title',
  body: 'Fixture body',
  targetType: target,
  targetId: target == 'class' || target == 'class_members' ? classId : targetId,
  createdAt: DateTime.utc(2026, 11, 1),
);

void main() {
  final cases = [
    (
      name: 'post',
      target: 'post',
      type: 'material',
      kind: 'material',
      screen: NotificationScreen.post,
    ),
    (
      name: 'assignment',
      target: 'post',
      type: 'assignment',
      kind: 'assignment',
      screen: NotificationScreen.assignment,
    ),
    (
      name: 'quiz',
      target: 'quiz',
      type: 'quiz_published',
      kind: '',
      screen: NotificationScreen.quiz,
    ),
    (
      name: 'result',
      target: 'quiz',
      type: 'results_released',
      kind: '',
      screen: NotificationScreen.result,
    ),
    (
      name: 'class',
      target: 'class',
      type: 'join_approved',
      kind: '',
      screen: NotificationScreen.classroom,
    ),
    (
      name: 'requests',
      target: 'class_members',
      type: 'join_request',
      kind: '',
      screen: NotificationScreen.requests,
    ),
  ];
  for (final state in ['terminated', 'background', 'foreground']) {
    for (final entry in cases) {
      test('${entry.name} canonical destination from $state event', () {
        final events = PushEvents();
        addTearDown(events.dispose);
        events.receive(
          {
            'notification_id': noticeId,
            'target_type': 'forged',
            'target_id': 'forged',
          },
          open: state != 'foreground',
          accountId: userId,
        );
        if (state == 'foreground') {
          expect(events.take(userId, allowOpen: false)?.open, isFalse);
          expect(events.take(userId, allowOpen: true), isNull);
          events.retry(
            const PushEvent(noticeId, open: true, accountId: userId),
          );
        }
        expect(events.take(userId, allowOpen: true)?.id, noticeId);
        final n = notice(target: entry.target, type: entry.type);
        final destination = notificationDestination(n, {
          'id': n.targetId,
          'class_id': classId,
          'kind': entry.kind,
        }, instructor: entry.name == 'requests');
        expect(destination.screen, entry.screen);
        expect(destination.classId, classId);
        expect(destination.targetId, n.targetId);
      });
    }
  }

  test(
    'grade-returned and second-chance variants use assignment and overview',
    () {
      expect(
        notificationDestination(notice(type: 'grade_returned'), {
          'id': targetId,
          'class_id': classId,
          'kind': 'assignment',
        }, instructor: false).screen,
        NotificationScreen.assignment,
      );
      expect(
        notificationDestination(notice(target: 'quiz', type: 'second_chance'), {
          'id': targetId,
          'class_id': classId,
        }, instructor: false).screen,
        NotificationScreen.quiz,
      );
    },
  );

  test(
    'unsupported, mismatched, removed and wrong-role targets are unavailable',
    () {
      for (final item in [
        {'id': targetId, 'class_id': userId, 'kind': 'material'},
        {'id': userId, 'class_id': classId, 'kind': 'material'},
        {
          'id': targetId,
          'class_id': classId,
          'kind': 'material',
          'deleted_at': stamp,
        },
      ]) {
        expect(
          () => notificationDestination(notice(), item, instructor: false),
          throwsA(isA<NotificationUnavailable>()),
        );
      }
      expect(
        () => notificationDestination(notice(target: 'unknown'), {
          'id': targetId,
        }, instructor: false),
        throwsA(isA<NotificationUnavailable>()),
      );
      expect(
        () => notificationDestination(
          notice(target: 'class_members', type: 'join_request'),
          {'id': classId},
          instructor: false,
        ),
        throwsA(isA<NotificationUnavailable>()),
      );
    },
  );

  test(
    'cold intent waits, receipt/open dedupe separately, exam defers only opens',
    () {
      final events = PushEvents();
      addTearDown(events.dispose);
      events.receive({'notification_id': noticeId}, open: true);
      events.receive({'notification_id': noticeId}, open: true);
      events.receive(
        {'notification_id': noticeId},
        open: true,
        accountId: userId,
      );
      expect(events.take(userId, allowOpen: false), isNull);
      events.receive(
        {'notification_id': targetId},
        open: false,
        accountId: userId,
      );
      expect(events.take(userId, allowOpen: false)?.id, targetId);
      expect(events.take(userId, allowOpen: true)?.id, noticeId);
      expect(events.take(userId, allowOpen: true), isNull);
      events.receive(
        {'notification_id': targetId},
        open: true,
        accountId: userId,
      );
      expect(events.take(userId, allowOpen: true)?.open, isTrue);
      events.clear();
      expect(events.take(userId, allowOpen: true), isNull);
      events.receive(
        {'notification_id': noticeId},
        open: true,
        accountId: userId,
      );
      expect(events.take(classId, allowOpen: true), isNull);
    },
  );

  test(
    'malformed IDs never become routes and anonymous receipts are ignored',
    () {
      final events = PushEvents();
      addTearDown(events.dispose);
      events.receive({'notification_id': noticeId}, open: false);
      events.receive(
        {'notification_id': '/classes/evil'},
        open: false,
        accountId: userId,
      );
      expect(events.take(userId, allowOpen: true), isNull);
      events.receive(
        {'notification_id': '/classes/evil'},
        open: true,
        accountId: userId,
      );
      expect(events.take(userId, allowOpen: true)?.id, isNull);
    },
  );

  for (final mode in [
    'online',
    'missing',
    'denied',
    'cross class',
    'transport',
    'late account',
  ]) {
    test('authorized canonical row/cache and read semantics: $mode', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.saveProfile(
        CacheProfilesCompanion.insert(
          id: userId,
          role: 'student',
          displayName: 'Fixture',
        ),
      );
      var current = true;
      final gate = Completer<void>();
      final started = Completer<void>();
      var prepared = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          if (mode == 'transport')
            throw StateError('synthetic transport failure');
          if (mode == 'late account' && table == 'notifications') {
            if (!started.isCompleted) started.complete();
            await gate.future;
          }
          Object? data;
          if (table == 'notifications') {
            expect(request.url.queryParameters['recipient_id'], 'eq.$userId');
            data = {
              'id': noticeId,
              'recipient_id': userId,
              'type': 'assignment',
              'title': 'Stored title',
              'target_type': 'post',
              'target_id': targetId,
              'class_id': mode == 'cross class' ? userId : classId,
              'created_at': stamp,
              'updated_at': stamp,
            };
          } else if (table == 'posts') {
            data = mode == 'missing'
                ? null
                : {'id': targetId, 'class_id': classId, 'kind': 'assignment'};
          } else if (table == 'classes') {
            data = {'id': classId, 'owner_id': classId};
          } else if (table == 'class_members') {
            data = mode == 'denied'
                ? []
                : [
                    {'id': targetId},
                  ];
          }
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final sync = SyncCoordinator(db, client, userId, () => current);
      final repository = NotificationDestinationRepository(
        db: db,
        client: client,
        sync: sync,
        userId: userId,
        online: () => true,
        isCurrent: () => current,
        prepare: (_) async {
          prepared = true;
        },
      );
      try {
        final resolution = repository.resolve(noticeId, instructor: false);
        if (mode == 'late account') {
          await started.future;
          current = false;
          gate.complete();
        }
        if (mode == 'online') {
          expect((await resolution).screen, NotificationScreen.assignment);
          expect(prepared, isTrue);
          expect(
            (await db.select(db.cacheNotifications).get()).single.readAt,
            isNull,
          );
          await InboxRepository(db, userId, () => current).markRead(noticeId);
          await repository.notice(noticeId);
          expect(
            (await db.select(db.cacheNotifications).get()).single.readAt,
            isNotNull,
          );
          expect(
            (await db.select(db.outbox).get()).single.id,
            'read:$noticeId',
          );
        } else if (mode == 'missing' ||
            mode == 'denied' ||
            mode == 'cross class') {
          await expectLater(
            resolution,
            throwsA(isA<NotificationUnavailable>()),
          );
          expect(
            (await db.select(db.cacheNotifications).get()).single.readAt,
            isNull,
          );
        } else {
          await expectLater(resolution, throwsStateError);
          expect(await db.select(db.cacheNotifications).get(), isEmpty);
        }
      } finally {
        sync.dispose();
        await db.close();
        await client.dispose();
      }
    });
  }

  test(
    'offline uncached notice requests connection, not unavailable',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final client = SupabaseClient('https://example.supabase.co', 'test-key');
      final sync = SyncCoordinator(db, client, userId, () => true);
      try {
        final repository = NotificationDestinationRepository(
          db: db,
          client: client,
          sync: sync,
          userId: userId,
          online: () => false,
          isCurrent: () => true,
          prepare: (_) async {},
        );
        await expectLater(
          repository.resolve(noticeId, instructor: false),
          throwsA(isA<NotificationNeedsConnection>()),
        );
      } finally {
        sync.dispose();
        await db.close();
        await client.dispose();
      }
    },
  );

  test('offline cached destination requires cached class access and never prepares remotely', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final client = SupabaseClient('https://example.supabase.co', 'test-key');
    final sync = SyncCoordinator(db, client, userId, () => true);
    try {
      await db.saveProfile(
        CacheProfilesCompanion.insert(
          id: userId,
          role: 'student',
          displayName: 'Student',
        ),
      );
      await db.saveProfile(
        CacheProfilesCompanion.insert(
          id: targetId,
          role: 'instructor',
          displayName: 'Instructor',
        ),
      );
      await db
          .into(db.cacheClasses)
          .insert(
            CacheClassesCompanion.insert(
              id: classId,
              ownerId: targetId,
              course: 'Fixture',
              section: 'A',
              schoolYear: '2026',
              joinCode: 'ABCDEF',
            ),
          );
      await db
          .into(db.cacheClassMembers)
          .insert(
            CacheClassMembersCompanion.insert(
              id: noticeId,
              classId: classId,
              studentId: userId,
              status: const Value('active'),
            ),
          );
      await db
          .into(db.cachePosts)
          .insert(
            CachePostsCompanion.insert(
              id: targetId,
              classId: classId,
              authorId: targetId,
              kind: 'material',
              title: 'Fixture',
            ),
          );
      await db.into(db.cacheNotifications).insert(notice().toCompanion(false));
      final repository = NotificationDestinationRepository(
        db: db,
        client: client,
        sync: sync,
        userId: userId,
        online: () => false,
        isCurrent: () => true,
        prepare: (_) async => fail('Offline resolution must not load remotely'),
      );
      expect(
        (await repository.resolve(noticeId, instructor: false)).screen,
        NotificationScreen.post,
      );
      await db
          .update(db.cachePosts)
          .write(
            CachePostsCompanion(
              kind: const Value('assignment'),
              points: const Value(10),
              dueAt: Value(DateTime.utc(2026, 11, 2)),
            ),
          );
      expect(
        (await repository.resolveAssignment(targetId)).screen,
        NotificationScreen.assignment,
      );
      expect((await db.select(db.cacheNotifications).get()).length, 1);
      await db.delete(db.cacheClassMembers).go();
      await expectLater(
        repository.resolve(noticeId, instructor: false),
        throwsA(isA<NotificationNeedsConnection>()),
      );
    } finally {
      sync.dispose();
      await db.close();
      await client.dispose();
    }
  });
}
