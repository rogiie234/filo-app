import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/notifications/push_events.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/exams/application/exam_providers.dart';
import 'package:filo/features/exams/presentation/student_exam_screen.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/data/notification_destination_repository.dart';
import 'package:filo/features/notifications/presentation/push_notification_host.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, AuthClientOptions;

import 'push_destinations_test.dart' as fixtures;

class FakeDestinationRepository extends NotificationDestinationRepository {
  FakeDestinationRepository(
    AppDatabase db,
    SupabaseClient client,
    SyncCoordinator sync,
  ) : super(
        db: db,
        client: client,
        sync: sync,
        userId: fixtures.userId,
        online: () => false,
        isCurrent: () => true,
        prepare: (_) async {},
      );
  Future<void>? waiting;
  bool failReceipt = false;
  bool failOpen = false;
  final received = <String?>[], opened = <String?>[];
  @override
  Future<CacheNotification> notice(String? id) async {
    received.add(id);
    await waiting;
    if (failReceipt) throw const NotificationNeedsConnection();
    return noticeFixture(id);
  }

  CacheNotification noticeFixture(String? id) =>
      // Each row is synthetic authorized content; push payload text is never used.
      CacheNotification(
        id: id!,
        recipientId: fixtures.userId,
        type: 'material',
        title: id == fixtures.noticeId
            ? 'First stored title'
            : 'Second stored title',
        body: 'Stored body',
        createdAt: DateTime.utc(2026),
      );
  @override
  Future<NotificationDestination> resolve(
    String? id, {
    required bool instructor,
  }) async {
    opened.add(id);
    if (failOpen) throw const NotificationNeedsConnection();
    throw const NotificationUnavailable();
  }

  @override
  Future<NotificationDestination> resolveAssignment(String postId) =>
      resolve(postId, instructor: false);
}

class ReadyPage extends StatelessWidget {
  const ReadyPage({super.key, required this.role});
  final AccountRole role;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        child: const Text('Finish setup'),
        onPressed: () => NotificationHomeReady(
          AccountProfile.fromJson({
            'id': fixtures.userId,
            'role': role.name,
            'display_name': 'Fixture',
          }),
        ).dispatch(context),
      ),
    ),
  );
}

void main() {
  Future<
    ({
      PushEvents events,
      FakeDestinationRepository repository,
      ExamNavigation exam,
    })
  >
  launch(
    WidgetTester tester, {
    bool accessible = false,
    bool student = false,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    final sync = SyncCoordinator(db, client, fixtures.userId, () => true);
    final repository = FakeDestinationRepository(db, client, sync);
    final events = PushEvents();
    final exam = ExamNavigation();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushEventsProvider.overrideWithValue(events),
          verifiedUserIdProvider.overrideWith((ref) async => fixtures.userId),
          accountDatabaseProvider.overrideWith((ref) async => db),
          connectivityProvider.overrideWithValue(const AsyncData(false)),
          notificationDestinationRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          studentExamRepositoryProvider.overrideWith((ref) async => null),
          examNavigationProvider.overrideWithValue(exam),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              accessibleNavigation: accessible,
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: PushNotificationHost(
            userId: fixtures.userId,
            child: ReadyPage(
              role: student ? AccountRole.student : AccountRole.instructor,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      events.dispose();
      sync.dispose();
      await (() async {
        await db.close();
        await tester.runAsync(() => client.dispose());
      })();
    });
    return (events: events, repository: repository, exam: exam);
  }

  testWidgets('failed opening stays unread and Retry resolves again', (
    tester,
  ) async {
    final h = await launch(tester);
    h.repository.failOpen = true;
    h.events.receive(
      {'notification_id': fixtures.noticeId},
      open: true,
      accountId: fixtures.userId,
    );
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();
    expect(
      find.text('Connect to the internet to open this notification.'),
      findsOneWidget,
    );
    expect(
      await tester.runAsync(
        () => h.repository.db.select(h.repository.db.outbox).get(),
      ),
      isEmpty,
    );
    h.repository.failOpen = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(h.repository.opened, [fixtures.noticeId, fixtures.noticeId]);
    expect(find.text('This item is no longer available.'), findsOneWidget);
  });

  testWidgets(
    'local reminder waits for Home and resolves assignment without an inbox read mark',
    (tester) async {
      final h = await launch(tester);
      h.events.receiveReminder({
        'accountId': fixtures.userId,
        'postId': fixtures.targetId,
        'nonce': 'reminder',
      });
      await tester.pumpAndSettle();
      expect(h.repository.opened, isEmpty);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect(h.repository.opened, [fixtures.targetId]);
      expect(h.repository.received, isEmpty);
      expect(find.text('This item is no longer available.'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => h.repository.db.select(h.repository.db.outbox).get(),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'explicit inbox opens use the same resolver and can reopen after a callback',
    (tester) async {
      final h = await launch(tester);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      h.events.receive(
        {'notification_id': fixtures.noticeId},
        open: true,
        accountId: fixtures.userId,
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        final opening = h.events.openInbox(fixtures.noticeId, fixtures.userId);
        await tester.pumpAndSettle();
        await opening;
      }
      expect(h.repository.opened, List.filled(3, fixtures.noticeId));
      expect(find.text('This item is no longer available.'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => h.repository.db.select(h.repository.db.outbox).get(),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'cold tap waits for Home readiness and unavailable target uses exact message',
    (tester) async {
      final h = await launch(tester);
      h.events.receive({'notification_id': fixtures.noticeId}, open: true);
      await tester.pumpAndSettle();
      expect(h.repository.opened, isEmpty);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect(h.repository.opened, [fixtures.noticeId]);
      expect(find.text('This item is no longer available.'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => h.repository.db.select(h.repository.db.outbox).get(),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'foreground banners queue, expire in order, Open shares resolver and receipt stays unread',
    (tester) async {
      final h = await launch(tester);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      for (final id in [fixtures.noticeId, fixtures.targetId]) {
        h.events.receive(
          {'notification_id': id, 'title': 'Untrusted private title'},
          open: false,
          accountId: fixtures.userId,
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('First stored title'), findsOneWidget);
      expect(find.text('Second stored title'), findsNothing);
      expect(find.text('Untrusted private title'), findsNothing);
      expect(h.repository.opened, isEmpty);
      expect(
        await tester.runAsync(
          () => h.repository.db.select(h.repository.db.outbox).get(),
        ),
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Second stored title'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(h.repository.opened, [fixtures.targetId]);
      expect(find.text('Second stored title'), findsNothing);
    },
  );

  testWidgets(
    'accessibility retains banner until Dismiss; missing authorization is neutral',
    (tester) async {
      final h = await launch(tester, accessible: true);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      h.repository.failReceipt = true;
      h.events.receive(
        {'notification_id': fixtures.noticeId, 'title': 'Do not expose'},
        open: false,
        accountId: fixtures.userId,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('New notification. Connect to view it.'),
        findsOneWidget,
      );
      expect(find.text('Do not expose'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(
        find.text('New notification. Connect to view it.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(PushForegroundBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exam defers opens and banners but still receives canonical data',
    (tester) async {
      final h = await launch(tester, student: true);
      h.exam.open = true;
      h.events.receive(
        {'notification_id': fixtures.noticeId},
        open: true,
        accountId: fixtures.userId,
      );
      h.events.receive(
        {'notification_id': fixtures.noticeId},
        open: false,
        accountId: fixtures.userId,
      );
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      expect(h.repository.received, [fixtures.noticeId]);
      expect(h.repository.opened, isEmpty);
      expect(find.byType(PushForegroundBanner), findsNothing);
      h.exam.open = false;
      h.events.receive(
        {'notification_id': fixtures.targetId},
        open: false,
        accountId: fixtures.userId,
      );
      await tester.pumpAndSettle();
      expect(h.repository.opened, [fixtures.noticeId]);
      expect(find.byType(PushForegroundBanner), findsOneWidget);
    },
  );

  testWidgets(
    'late receipt cannot show a banner after signed-in host is removed',
    (tester) async {
      final h = await launch(tester);
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      h.repository.waiting = gate.future;
      h.events.receive(
        {'notification_id': fixtures.noticeId},
        open: false,
        accountId: fixtures.userId,
      );
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('Signed out')));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('First stored title'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
