import 'dart:async';

import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/data/notification_settings_repository.dart';
import 'package:filo/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_settings_test_support.dart';

const room = ClassRoom(
  id: 'class',
  section: 'BSIT-3A',
  course: 'Computing',
  instructor: 'Teacher',
  color: 0xFF236B57,
  archived: true,
);
const pending = ClassRoom(
  id: 'pending',
  section: 'Pending',
  course: 'Course',
  instructor: 'Teacher',
  color: 0xFF236B57,
  pending: true,
);

void main() {
  Future<void> launch(
    WidgetTester tester,
    FakeSettingsRepository repo, {
    bool online = true,
    String? focus,
    bool failRefresh = false,
    bool failCache = false,
    Future<void>? load,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWithValue(AsyncData(online)),
          notificationSettingsRepositoryProvider.overrideWith((ref) async {
            await load;
            return repo;
          }),
          notificationPreferencesProvider.overrideWith((ref) async* {
            await load;
            if (failCache) throw StateError('fixture cache');
            yield* repo.watch();
          }),
          notificationPreferencesRefreshProvider.overrideWith((ref) async {
            if (failRefresh) throw StateError('fixture refresh');
          }),
          classCardsProvider.overrideWith(
            (ref) => Stream.value([room, pending]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: NotificationPreferenceControls(initialClassId: focus),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await repo.changes.close();
    });
  }

  testWidgets(
    'all 12 types wrap at enlarged text and permission-independent preferences render',
    (tester) async {
      final repo = FakeSettingsRepository();
      await launch(tester, repo, scale: 1.3);
      for (final label in notificationTypes.values) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Pending · Course'), findsNothing);
      expect(find.byType(SwitchListTile), findsNWidgets(13));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('type save is optimistic, busy, rolls back and retries', (
    tester,
  ) async {
    final repo = FakeSettingsRepository();
    final gate = Completer<void>();
    repo.waiting = gate.future;
    repo.fail.add('announcement');
    await launch(tester, repo);
    final toggle = find.widgetWithText(SwitchListTile, 'Announcements');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(
      find.text('Could not save notification setting. Try again.'),
      findsOneWidget,
    );
    repo.fail.clear();
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets(
    'class focus, archived label and partial-save retry keep actual mixed state',
    (tester) async {
      final repo = FakeSettingsRepository()..fail.add('announcement');
      await launch(tester, repo, focus: 'class');
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, 'BSIT-3A · Computing');
      expect(find.text('Selected class · Archived'), findsOneWidget);
      expect(tester.getTopLeft(toggle).dy, lessThan(844));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(repo.calls.length, 12);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(find.textContaining('Some types are muted'), findsOneWidget);
      expect(
        find.text('Some notification settings could not be saved'),
        findsOneWidget,
      );
      repo.fail.clear();
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.calls.length, 13);
      expect(find.textContaining('Some types are muted'), findsNothing);
    },
  );

  testWidgets('offline cached switches are visible and disabled', (
    tester,
  ) async {
    final repo = FakeSettingsRepository()
      ..rows.add({'type': 'announcement', 'class_id': null, 'enabled': false});
    await launch(tester, repo, online: false);
    final toggle = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Announcements'),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(find.textContaining('Connect to change them.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });
  testWidgets(
    'offline without successful snapshot never invents enabled defaults',
    (tester) async {
      await launch(
        tester,
        FakeSettingsRepository()..loaded = false,
        online: false,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(
        find.text('No saved notification preferences. Connect to load them.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('refresh error retains saved switches with Retry', (
    tester,
  ) async {
    await launch(tester, FakeSettingsRepository(), failRefresh: true);
    expect(find.text('Announcements'), findsOneWidget);
    expect(
      find.text(
        'Could not refresh notification settings. Saved preferences are unchanged.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('cache error and initial loading are distinct from defaults', (
    tester,
  ) async {
    await launch(tester, FakeSettingsRepository(), failCache: true);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(
      find.text('Could not load saved notification settings. Try again.'),
      findsOneWidget,
    );
  });
  testWidgets('initial loading has no editable defaults', (tester) async {
    final gate = Completer<void>();
    final repo = FakeSettingsRepository();
    await launch(tester, repo, load: gate.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Announcements'), findsOneWidget);
  });
  testWidgets(
    'late save after account invalidation cannot update another account view',
    (tester) async {
      final repo = FakeSettingsRepository();
      final gate = Completer<void>();
      repo.waiting = gate.future;
      await launch(tester, repo);
      await tester.ensureVisible(find.text('Announcements'));
      await tester.tap(find.text('Announcements'));
      await tester.pump();
      repo.current = false;
      await tester.pumpWidget(const MaterialApp(home: Text('Account changed')));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Announcements'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
