import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/notifications/push_events.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_icons.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/data/inbox_repository.dart';
import 'package:filo/features/notifications/presentation/inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const account = '10000000-0000-4000-8000-000000000001';
const notification = '20000000-0000-4000-8000-000000000001';

CacheNotification row({
  String id = notification,
  DateTime? created,
  bool read = false,
  String? title,
}) => CacheNotification(
  id: id,
  recipientId: account,
  type: 'announcement',
  title: title ?? 'Saved announcement',
  body: 'Saved message body',
  createdAt: created ?? DateTime.now(),
  readAt: read ? DateTime.now() : null,
);

class FakeInbox extends InboxRepository {
  FakeInbox(AppDatabase db) : super(db, account, () => true);
  bool fail = false;
  int marks = 0;
  Future<void>? waiting;
  @override
  Future<void> markAllRead() async {
    marks++;
    await waiting;
    if (fail) throw StateError('fixture');
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  test('failed inbox dispatch releases the caller and permits Retry', () async {
    final events = PushEvents();
    addTearDown(events.dispose);
    final failed = expectLater(
      events.openInbox(notification, account),
      throwsStateError,
    );
    events.failInboxOpen();
    await failed;
    final retry = events.openInbox(notification, account);
    final event = events.take(account, allowOpen: true)!;
    events.finishOpen(event);
    await retry;
  });
  test('explicit inbox opens bypass callback dedupe, serialize and clear on account change', () async {
    final events = PushEvents();
    addTearDown(events.dispose);
    events.receive(
      {'notification_id': notification},
      open: true,
      accountId: account,
    );
    events.take(account, allowOpen: true);
    var finished = false;
    final first = events.openInbox(notification, account)
      ..then((_) => finished = true);
    final duplicate = events.openInbox(notification, account);
    expect(identical(first, duplicate), isTrue);
    expect(events.take(account, allowOpen: false), isNull);
    final event = events.take(account, allowOpen: true)!;
    expect(events.take(account, allowOpen: true), isNull);
    expect(finished, isFalse);
    events.finishOpen(event);
    await first;
    final again = events.openInbox(notification, account);
    expect(events.take('another account', allowOpen: true), isNull);
    await again;
    final cleared = events.openInbox(notification, account);
    events.clear();
    await cleared;
    expect(events.take(account, allowOpen: true), isNull);
  });

  Future<
    ({
      FakeInbox repo,
      PushEvents events,
      StreamController<List<CacheNotification>> rows,
    })
  >
  launch(
    WidgetTester tester, {
    List<CacheNotification>? initial,
    bool loading = false,
    bool error = false,
    bool refreshError = false,
    bool offline = true,
    String userId = account,
    double scale = 1,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = FakeInbox(db);
    final events = PushEvents();
    final rows = StreamController<List<CacheNotification>>.broadcast();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxRepositoryProvider.overrideWith((ref) async => repo),
          inboxProvider.overrideWith((ref) async* {
            if (error) throw StateError('fixture');
            if (!loading) yield initial ?? [];
            yield* rows.stream;
          }),
          inboxRefreshProvider.overrideWith((ref) async {
            if (refreshError) throw StateError('fixture network');
          }),
          connectivityProvider.overrideWithValue(AsyncData(!offline)),
          pushEventsProvider.overrideWithValue(events),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: InboxScreen(userId: userId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      events.clear();
      events.dispose();
      await rows.close();
      await db.close();
    });
    return (repo: repo, events: events, rows: rows);
  }

  testWidgets(
    'calendar headings handle year boundary and icons have a fallback',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final now = DateTime(2027, 1, 1, 0, 1);
      expect(inboxDayLabel(context, DateTime(2027, 1, 1), now), 'Today');
      expect(
        inboxDayLabel(context, DateTime(2026, 12, 31, 23, 59), now),
        'Yesterday',
      );
      expect(
        inboxDayLabel(context, DateTime(2026, 12, 30), now),
        contains('2026'),
      );
      expect(inboxDayLabel(context, now.toUtc(), now), 'Today');
      expect(inboxTypeIcon('grade_returned'), FiloIcons.grades);
      expect(inboxTypeIcon('second_chance'), FiloIcons.assessment);
      expect(inboxTypeIcon('unknown'), FiloIcons.notifications);
    },
  );

  testWidgets(
    'saved offline rows wrap at enlarged text; read rows are not empty',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final title = List.filled(8, 'Long title').join(' ');
      await launch(
        tester,
        initial: [row(read: true, title: title)],
        scale: 1.3,
      );
      expect(find.text(title), findsOneWidget);
      expect(find.text('Saved message body'), findsOneWidget);
      expect(
        find.text("You're offline. Showing saved content."),
        findsOneWidget,
      );
      expect(find.text("You're all caught up."), findsNothing);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Mark all as read'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successful empty is separate from loading, error and account mismatch',
    (tester) async {
      await launch(tester, initial: []);
      expect(find.text("You're all caught up."), findsOneWidget);
    },
  );
  testWidgets('loading never shows caught up', (tester) async {
    await launch(tester, loading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("You're all caught up."), findsNothing);
  });
  testWidgets('same-day rows share a heading and retain repository order', (
    tester,
  ) async {
    await launch(
      tester,
      initial: [
        row(title: 'Newest'),
        row(id: '20000000-0000-4000-8000-000000000002', title: 'Next'),
      ],
    );
    expect(find.text('Today'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newest')).dy,
      lessThan(tester.getTopLeft(find.text('Next')).dy),
    );
  });
  testWidgets('storage error offers Retry without empty state', (tester) async {
    await launch(tester, error: true);
    expect(
      find.text('Could not load saved notifications. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text("You're all caught up."), findsNothing);
  });
  testWidgets('another account cannot display old rows', (tester) async {
    await launch(tester, initial: [row()], userId: 'different account');
    expect(find.text('Saved announcement'), findsNothing);
    expect(
      find.text('Notifications are unavailable for this account.'),
      findsOneWidget,
    );
  });
  testWidgets('refresh failure keeps saved content and exposes Retry', (
    tester,
  ) async {
    await launch(tester, initial: [row()], refreshError: true, offline: false);
    expect(find.text('Saved announcement'), findsOneWidget);
    expect(
      find.text('Could not refresh notifications. Showing saved content.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Saved announcement'), findsOneWidget);
  });
  testWidgets(
    'mark-all disables while saving, retries failure and follows new read state',
    (tester) async {
      final h = await launch(tester, initial: [row()]);
      final gate = Completer<void>();
      h.repo.waiting = gate.future;
      h.repo.fail = true;
      await tester.tap(find.text('Mark all as read'));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Could not save read status. Try again.'),
        findsOneWidget,
      );
      h.repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(h.repo.marks, 2);
      h.rows.add([row(read: true)]);
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Mark all as read'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'row opens only once while pending and can reopen after completion',
    (tester) async {
      final h = await launch(tester, initial: [row()]);
      await tester.tap(find.text('Saved announcement'));
      await tester.pump();
      await tester.tap(find.text('Saved announcement'));
      final event = h.events.take(account, allowOpen: true)!;
      expect(h.events.take(account, allowOpen: true), isNull);
      h.events.finishOpen(event);
      await tester.pump();
      await tester.tap(find.text('Saved announcement'));
      expect(h.events.take(account, allowOpen: true)?.id, notification);
    },
  );
}
