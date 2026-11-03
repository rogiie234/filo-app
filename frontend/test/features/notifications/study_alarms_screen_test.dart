import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/data/alarm_repository.dart';
import 'package:filo/features/notifications/presentation/study_alarms_screen.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/presentation/phone_limits_guide_screen.dart';
import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/features/onboarding/application/notification_permission.dart';

import 'study_alarms_test.dart' show StudyBridgeFixture, accountId;

class ScreenStudyBridge extends StudyBridgeFixture {
  @override
  Future<Map<String, dynamic>> status() async => {
    'enabled': true,
    'exact': false,
    'error': false,
    'studyEnabled': true,
    'studyError': false,
  };
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
  for (final previousSetup in [false, true]) {
    testWidgets(
      'first save opens new guide after temporary setup=$previousSetup, including scheduling failure',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final bridge = ScreenStudyBridge()..fail = previousSetup;
        final repo = AlarmRepository(
          db,
          () => true,
          userId: accountId,
          bridge: bridge,
        );
        await repo.setSetting('deadline_lease', 'fixture');
        if (previousSetup) await repo.setSetting('study_onboarded', '1');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyAlarmRepositoryProvider.overrideWith((ref) async => repo),
              alarmRepositoryProvider.overrideWith((ref) async => repo),
              deadlineBridgeProvider.overrideWithValue(bridge),
              deadlineSessionProvider.overrideWith((ref) async => null),
              deadlineStatusProvider.overrideWith(
                (ref) async => {'exact': true, 'enabled': true, 'error': false},
              ),
              notificationAccessProvider.overrideWith((ref) async => true),
              phoneGuideCapabilitiesProvider.overrideWith(
                (ref) async => const PhoneGuideCapabilities(30, false),
              ),
              connectivityProvider.overrideWith((ref) async* {
                yield false;
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const StudyAlarmsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('New alarm'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Biology');
        await tester.scrollUntilVisible(
          find.text('Save'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text(phoneGuideHeading), findsOneWidget);
        expect((await tester.runAsync(repo.readAlarms))!, hasLength(1));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(await tester.runAsync(repo.needsPhoneGuide), isFalse);
        if (!previousSetup) {
          await tester.tap(find.text('Biology'));
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(
          find.text('Save'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text(phoneGuideHeading), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        var closed = false;
        final closing = db.close().then((_) => closed = true);
        for (var i = 0; i < 20 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(closed, isTrue);
        await closing;
      },
    );
  }
  testWidgets(
    'empty offline list, editor validation, save, toggle and delete at enlarged text',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final bridge = ScreenStudyBridge();
      final repo = AlarmRepository(
        db,
        () => true,
        userId: accountId,
        bridge: bridge,
      );
      await repo.setSetting('deadline_lease', 'fixture');
      await repo.dismissPhoneGuide();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyAlarmRepositoryProvider.overrideWith((ref) async => repo),
            deadlineSessionProvider.overrideWith((ref) async => null),
            connectivityProvider.overrideWith((ref) async* {
              yield false;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const StudyAlarmsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No study alarms yet.'), findsOneWidget);
      expect(
        find.text('Approximate alarms. Delivery may be delayed.'),
        findsOneWidget,
      );
      await tester.tap(find.text('New alarm'));
      await tester.pumpAndSettle();
      expect(find.text('New study alarm'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextFormField),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter a subject.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Purposive Communication study time',
      );
      await tester.scrollUntilVisible(
        find.text('Save'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(await repo.readAlarms(), hasLength(1));
      expect(find.byType(Switch), findsOneWidget);
      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect((await tester.runAsync(repo.readAlarms))!.single.enabled, isFalse);
      await tester.tap(find.text('Purposive Communication study time'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete alarm'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete alarm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No study alarms yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      var closed = false;
      final closing = db.close().then((_) => closed = true);
      for (var i = 0; i < 20 && !closed; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(
        closed,
        isTrue,
        reason: 'Drift cleanup must drain before ending the widget test',
      );
      await closing;
    },
  );
  testWidgets(
    'loading and failed storage do not render a successful empty list',
    (tester) async {
      final pending = Completer<AlarmRepository>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyAlarmRepositoryProvider.overrideWith((ref) => pending.future),
            connectivityProvider.overrideWith((ref) async* {
              yield false;
            }),
          ],
          child: const MaterialApp(home: StudyAlarmsScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('No study alarms yet.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.completeError(StateError('Fixture storage unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('No study alarms yet.'), findsNothing);
      expect(
        find.text('Could not load study alarms. Sign in or retry.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
