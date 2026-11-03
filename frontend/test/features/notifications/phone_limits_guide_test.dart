import '../../support/accessibility.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/data/alarm_repository.dart';
import 'package:filo/features/notifications/presentation/phone_limits_guide_screen.dart';
import 'package:filo/features/onboarding/application/notification_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class GuideUiBridge extends DeadlineBridge {
  PhoneGuideCapabilities caps = const PhoneGuideCapabilities(31, true);
  bool failCapabilities = false;
  Completer<PhoneGuideCapabilities>? pending;
  String result = 'direct';
  final opened = <String>[];
  @override
  bool get supported => true;
  @override
  Future<PhoneGuideCapabilities> guideCapabilities() async {
    if (pending != null) return pending!.future;
    if (failCapabilities) throw StateError('fixture');
    return caps;
  }

  @override
  Future<String> guideOpenSettings(String section) async {
    opened.add(section);
    return result;
  }
}

class GuideMarkerRepo extends AlarmRepository {
  GuideMarkerRepo(AppDatabase db, bool Function() current)
    : super(db, current, userId: 'student');
  int seen = 0;
  @override
  Future<void> dismissPhoneGuide() async {
    if (!isCurrent()) throw StateError('Account changed');
    seen++;
  }
}

void main() {
  for (final palette in [AppTheme.light, AppTheme.dark]) {
    group('${palette.brightness.name} / 130%', () {
      late AppDatabase db;
      late GuideUiBridge bridge;
      late GuideMarkerRepo repo;
      late bool current;
      late int statusReads;
      setUp(() {
        db = AppDatabase(NativeDatabase.memory());
        bridge = GuideUiBridge();
        current = true;
        statusReads = 0;
        repo = GuideMarkerRepo(db, () => current);
      });
      Future<void> launch(
        WidgetTester tester, {
        String? expected,
        bool settle = true,
      }) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              alarmRepositoryProvider.overrideWith((ref) async => repo),
              deadlineBridgeProvider.overrideWithValue(bridge),
              deadlineStatusProvider.overrideWith((ref) async {
                statusReads++;
                return {'exact': true, 'enabled': true, 'error': false};
              }),
              notificationAccessProvider.overrideWith((ref) async => true),
            ],
            child: MaterialApp(
              theme: palette,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PhoneLimitsGuideScreen(expectedUserId: expected),
                      ),
                    ),
                    child: const Text('Open guide'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open guide'));
        if (settle)
          await tester.pumpAndSettle();
        else
          await tester.pump(const Duration(milliseconds: 100));
      }

      Future<void> finish(WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.close();
      }

      Future<void> reveal(WidgetTester tester, String text) async {
        await tester.scrollUntilVisible(
          find.text(text).hitTestable(),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(text));
        await tester.pumpAndSettle();
      }

      for (final sdk in [30, 31]) {
        for (final xiaomi in [false, true]) {
          a11yScreenTest(
            'filters steps for API $sdk Xiaomi $xiaomi with approved copy',
            (tester) async {
              bridge.caps = PhoneGuideCapabilities(sdk, xiaomi);
              await launch(tester);
              expect(find.text(phoneGuideHeading), findsOneWidget);
              expect(find.text(phoneGuideIntroduction), findsOneWidget);
              if (sdk >= 31) {
                await reveal(tester, 'Open alarm settings');
                expect(
                  find.text('3. Allow Filo under Alarms & reminders.'),
                  findsOneWidget,
                );
              } else
                expect(find.text('Open alarm settings'), findsNothing);
              if (xiaomi) {
                await reveal(tester, 'Open autostart settings');
                expect(
                  find.text(
                    '2. Find Filo under Autostart or Background autostart.',
                  ),
                  findsOneWidget,
                );
                await reveal(tester, 'Open battery settings');
                expect(
                  find.text(
                    '3. Open its battery settings and choose No restrictions.',
                  ),
                  findsOneWidget,
                );
              } else {
                expect(find.text('Open autostart settings'), findsNothing);
                expect(find.text('Open battery settings'), findsNothing);
              }
              expect(bridge.opened, isEmpty);
              expect(repo.seen, 0);
              expect(tester.takeException(), isNull);
              await finish(tester);
            },
          );
        }
      }
      a11yScreenTest(
        'fallback and failed launch show manual copy, retry and no permission certification',
        (tester) async {
          bridge.result = 'app_details';
          await launch(tester);
          await reveal(tester, 'Open battery settings');
          await tester.tap(find.text('Open battery settings'));
          await tester.pumpAndSettle();
          await reveal(tester, phoneGuideFallback);
          expect(find.text(phoneGuideFallback), findsOneWidget);
          bridge.result = 'failed';
          await reveal(tester, 'Open battery settings');
          await tester.tap(find.text('Open battery settings'));
          await tester.pumpAndSettle();
          await reveal(tester, 'Try again');
          bridge.result = 'direct';
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(bridge.opened, ['battery', 'battery', 'battery']);
          expect(find.text(phoneGuideFallback), findsNothing);
          expect(repo.seen, 0);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(statusReads, greaterThan(1));
          await finish(tester);
        },
      );
      for (final action in ['Done', 'Not now', 'Back']) {
        a11yScreenTest('$action marks only a displayed current-account guide', (
          tester,
        ) async {
          bridge.caps = const PhoneGuideCapabilities(30, false);
          await launch(tester);
          if (action == 'Back')
            await tester.pageBack();
          else {
            await reveal(tester, action);
            await tester.tap(find.text(action));
          }
          await tester.pumpAndSettle();
          expect(repo.seen, 1);
          expect(find.text('Open guide'), findsOneWidget);
          await finish(tester);
        });
      }
      a11yScreenTest(
        'capability failure is retryable, interruption does not mark seen',
        (tester) async {
          bridge.failCapabilities = true;
          await launch(tester);
          expect(
            find.text('Could not check phone setup steps. Try again.'),
            findsOneWidget,
          );
          bridge.failCapabilities = false;
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(find.text('Open alarm settings'), findsOneWidget);
          await finish(tester);
          expect(repo.seen, 0);
        },
      );
      a11yScreenTest('loading capabilities never assumes a non-Xiaomi phone', (
        tester,
      ) async {
        bridge.pending = Completer<PhoneGuideCapabilities>();
        await launch(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.scrollUntilVisible(
          find.byType(CircularProgressIndicator),
          200,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Open autostart settings'), findsNothing);
        bridge.pending!.complete(const PhoneGuideCapabilities(31, true));
        await tester.pumpAndSettle();
        await reveal(tester, 'Open autostart settings');
        expect(find.text('Open autostart settings'), findsOneWidget);
        await finish(tester);
      });
      a11yScreenTest(
        'foreign or switched account cannot write the guide marker',
        (tester) async {
          await launch(tester, expected: 'another-student');
          expect(find.text(phoneGuideHeading), findsNothing);
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(repo.seen, 0);
          await finish(tester);
        },
      );
      a11yScreenTest(
        'account switch after display does not write a late marker',
        (tester) async {
          bridge.caps = const PhoneGuideCapabilities(30, false);
          await launch(tester);
          current = false;
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(repo.seen, 0);
          await finish(tester);
        },
      );
    });
  }
}
