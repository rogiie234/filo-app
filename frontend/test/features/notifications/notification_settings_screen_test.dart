import 'dart:async';

import 'package:filo/core/notifications/push_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/presentation/notification_settings_screen.dart';
import 'package:filo/features/onboarding/application/notification_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/notifications/push_registration_test.dart' show Fixture;
import 'notification_settings_test_support.dart';

class FakePermission extends NotificationPermission {
  bool allowed = false, failStatus = false, failOpen = false;
  int opened = 0;
  Future<bool>? waiting;
  @override
  Future<bool> enabled() async {
    if (waiting != null) return waiting!;
    if (failStatus) throw StateError('synthetic private error');
    return allowed;
  }

  @override
  Future<void> openSettings() async {
    opened++;
    if (failOpen) throw StateError('synthetic private error');
    allowed = true;
  }
}

const blocked =
    'Notifications are off for Filo. Turn them on in your phone settings.';

void main() {
  Future<void> launch(
    WidgetTester tester,
    FakePermission permission,
    Fixture push, {
    double scale = 1,
  }) async {
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPermissionProvider.overrideWithValue(permission),
          pushRegistrationProvider.overrideWithValue(push.service),
          connectivityProvider.overrideWithValue(const AsyncData(true)),
          notificationSettingsRepositoryProvider.overrideWith(
            (ref) async => settings,
          ),
          notificationPreferencesProvider.overrideWith(
            (ref) => settings.watch(),
          ),
          notificationPreferencesRefreshProvider.overrideWith((ref) async {}),
          classCardsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      push.service.dispose();
      await tester.pump();
      await settings.changes.close();
    });
  }

  testWidgets(
    'blocked banner opens settings and registers when enabled at 130% text',
    (tester) async {
      final permission = FakePermission();
      final push = Fixture();
      await launch(tester, permission, push, scale: 1.3);
      await tester.pumpAndSettle();
      expect(find.text(blocked), findsOneWidget);
      expect(push.events, isEmpty);
      final toggle = find.widgetWithText(SwitchListTile, 'Announcements');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.ensureVisible(find.text('Open settings'));
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(permission.opened, 1);
      expect(find.text(blocked), findsNothing);
      expect(find.text('Notifications are on for Filo.'), findsOneWidget);
      expect(push.events.single, startsWith('register:'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown loading and failed status are not blocked; Retry recovers',
    (tester) async {
      final gate = Completer<bool>();
      final permission = FakePermission()..waiting = gate.future;
      final push = Fixture();
      await launch(tester, permission, push);
      await tester.pump();
      expect(find.text('Checking notification access…'), findsOneWidget);
      expect(find.text(blocked), findsNothing);
      gate.completeError(StateError('synthetic private error'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not check notification access. Try again.'),
        findsOneWidget,
      );
      expect(find.text(blocked), findsNothing);
      permission.waiting = null;
      permission.allowed = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications are on for Filo.'), findsOneWidget);
      expect(push.events.single, startsWith('register:'));
    },
  );

  testWidgets(
    'resume rechecks revoked permission; settings failures stay actionable',
    (tester) async {
      final permission = FakePermission()..allowed = true;
      final push = Fixture();
      await launch(tester, permission, push);
      await tester.pumpAndSettle();
      permission.allowed = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(blocked), findsOneWidget);
      permission.failOpen = true;
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open phone settings. Try again.'),
        findsOneWidget,
      );
      expect(find.text(blocked), findsOneWidget);
      expect(find.textContaining('synthetic private'), findsNothing);
    },
  );
}
