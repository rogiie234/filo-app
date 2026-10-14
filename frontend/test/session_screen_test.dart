import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/auth/presentation/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final session = Session(
    accessToken: 'not-a-real-token',
    tokenType: 'bearer',
    user: User(
      id: 'test-user',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-10-15T00:00:00Z',
      email: 'person@example.com',
    ),
  );

  Future<void> launch(WidgetTester tester, {bool verified = false}) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginSessionProvider.overrideWith((ref) => Stream.value(session)),
          verifiedUserIdProvider.overrideWith(
            (ref) async => verified ? 'test-user' : null,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SessionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'new device shows full email and fits a small phone with larger text',
    (tester) async {
      await launch(tester);
      expect(find.text('Let’s make sure\nit’s you.'), findsOneWidget);
      expect(find.text('person@example.com'), findsOneWidget);
      expect(find.text('p***@example.com'), findsNothing);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Session ID present: false'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('verified state has friendly success copy and no OTP actions', (
    tester,
  ) async {
    await launch(tester, verified: true);
    expect(find.text('You’re all set.'), findsOneWidget);
    expect(find.text('Device confirmed'), findsOneWidget);
    expect(find.text('Send code'), findsNothing);
    expect(find.text('Verify code'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
