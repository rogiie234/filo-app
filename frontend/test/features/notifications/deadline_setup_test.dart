import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SetupBridge extends DeadlineBridge {
  final opened = <String>[];
  @override
  bool get supported => true;
  @override
  Future<void> openSettings(String section) async {
    opened.add(section);
  }
}

void main() {
  for (final state in ['ready', 'approximate', 'blocked', 'failed']) {
    testWidgets(
      'deadline setup $state state and explicit settings actions at enlarged text',
      (tester) async {
        final bridge = SetupBridge();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deadlineBridgeProvider.overrideWithValue(bridge),
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
        await tester.ensureVisible(find.text('Open alarm settings'));
        await tester.tap(find.text('Open alarm settings'));
        await tester.pumpAndSettle();
        expect(bridge.opened, ['alarm']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
