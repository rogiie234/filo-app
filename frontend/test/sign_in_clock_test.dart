import 'dart:io';

import 'package:filo/features/auth/application/sign_in_clock.dart';
import 'package:filo/features/auth/presentation/sign_in_screen.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/supabase/supabase_provider.dart';
import 'package:filo/core/supabase/native_google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final server = DateTime.utc(2026, 10, 23, 8);
  test('clock diagnosis accepts accurate time in any timezone and tolerates small skew', () {
    final date = HttpDate.format(server);
    expect(signInClockMismatch(date, server, Duration.zero), isFalse);
    expect(signInClockMismatch(date, server.toLocal(), Duration.zero), isFalse);
    expect(
      signInClockMismatch(
        date,
        DateTime.parse('2026-10-23T16:00:00+08:00'),
        Duration.zero,
      ),
      isFalse,
    );
    expect(
      signInClockMismatch(
        date,
        server.add(const Duration(minutes: 4)),
        Duration.zero,
      ),
      isFalse,
    );
    expect(
      signInClockMismatch(
        date,
        server.subtract(const Duration(hours: 1)),
        Duration.zero,
      ),
      isTrue,
    );
    expect(
      signInClockMismatch(
        date,
        server.add(const Duration(days: 1)),
        Duration.zero,
      ),
      isTrue,
    );
  });
  test(
    'absent, malformed, cached and slow samples cannot confirm a mismatch',
    () {
      expect(signInClockMismatch(null, server, Duration.zero), isNull);
      expect(signInClockMismatch('invalid', server, Duration.zero), isNull);
      expect(
        signInClockMismatch(
          HttpDate.format(server),
          server,
          const Duration(seconds: 6),
        ),
        isNull,
      );
      expect(
        signInClockMismatch(
          HttpDate.format(server),
          server,
          Duration.zero,
          age: '30',
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'unavailable clock check preserves login error and shows a hint, not a diagnosis',
    (tester) async {
      final client = SupabaseClient('https://example.supabase.co', 'key');
      addTearDown(client.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            signInClockCheckProvider.overrideWithValue(() async => null),
            supabaseClientProvider.overrideWithValue(client),
            nativeGoogleSignInProvider.overrideWith(
              (ref) async => throw StateError('Could not sign in.'),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Could not sign in.'), findsOneWidget);
      expect(
        find.text(
          'If this keeps happening, check that automatic date and time is enabled on your phone.',
        ),
        findsOneWidget,
      );
      expect(find.text("Check your phone's date and time"), findsNothing);
      expect(find.text('Open settings'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'confirmed mismatch offers settings and rechecks on return without signing in',
    (tester) async {
      var checks = 0, opened = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            signInClockCheckProvider.overrideWithValue(
              () async => ++checks == 1,
            ),
            openDateTimeSettingsProvider.overrideWithValue(() async {
              opened++;
            }),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text("Check your phone's date and time"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.ensureVisible(find.text('Open settings'));
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 2);
      expect(
        find.text('Date and time look correct. Try signing in again.'),
        findsOneWidget,
      );
      expect(find.text("Check your phone's date and time"), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
