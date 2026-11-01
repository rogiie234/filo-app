import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/presentation/phone_limits_guide_screen.dart';
import 'package:filo/features/onboarding/application/notification_permission.dart';

import 'phone_limits_guide_test.dart' show GuideMarkerRepo;

class SetupBridge extends DeadlineBridge {
  final opened = <String>[];
  @override
  bool get supported => true;
  @override
  Future<String> guideOpenSettings(String section) async {
    opened.add(section);
    return 'direct';
  }
}

void main() {
  for (final state in ['ready', 'approximate', 'blocked', 'failed']) {
    testWidgets(
      'deadline setup $state state and explicit settings actions at enlarged text',
      (tester) async {
        final bridge = SetupBridge();
        final db = AppDatabase(NativeDatabase.memory());
        final repo = GuideMarkerRepo(db, () => true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deadlineBridgeProvider.overrideWithValue(bridge),
              alarmRepositoryProvider.overrideWith((ref) async => repo),
              phoneGuideCapabilitiesProvider.overrideWith(
                (ref) async => const PhoneGuideCapabilities(31, false),
              ),
              notificationAccessProvider.overrideWith((ref) async => true),
              deadlineStatusProvider.overrideWith(
                (ref) async => {
                  'enabled': state != 'blocked',
                  'exact': state != 'approximate',
                  'error': state == 'failed',
                },
              ),
              deadlineSessionProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: DeadlineReminderSetup(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final expected = switch (state) {
          'ready' => 'Deadline reminders are ready.',
          'approximate' => 'Deadline reminders are approximate and may arrive late. Allow Alarms & reminders for more precise timing.',
          'blocked' => 'Notifications are off. Enable notifications in your phone settings to see deadline reminders.',
          _ => 'Could not update deadline reminders. Retry.',
        };
        expect(find.text(expected), findsOneWidget);
        expect(bridge.opened, isEmpty);
        expect(find.text('Open autostart settings'), findsNothing);
        await tester.ensureVisible(find.text('Alarm setup'));
        await tester.tap(find.text('Alarm setup'));
        await tester.pumpAndSettle();
        expect(find.byType(PhoneLimitsGuideScreen), findsOneWidget);
        await tester.ensureVisible(find.text('Open alarm settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open alarm settings'));
        await tester.pumpAndSettle();
        expect(bridge.opened, ['alarm']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.close();
      },
    );
  }
}
