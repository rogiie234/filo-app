import 'package:filo/app.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/supabase/auth_providers.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:filo/core/supabase/supabase_provider.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/auth/presentation/session_screen.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NewAccountProfiles extends ProfileRepository {
  _NewAccountProfiles(super.client);
  @override
  Future<AccountProfile?> fetch() async => null;
}

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

  Future<void> launch(
    WidgetTester tester, {
    bool verified = false,
    SupabaseClient? client,
    DateTime Function()? now,
    bool throughApp = false,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SupabaseClient? profileClient;
    if (verified) {
      profileClient = await tester.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
      addTearDown(() => tester.runAsync(profileClient!.dispose));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserIdProvider.overrideWith(
            (ref) => Stream.value(session.user.id),
          ),
          if (now != null) otpClockProvider.overrideWithValue(now),
          if (client != null) supabaseClientProvider.overrideWithValue(client),
          if (verified)
            accountDatabaseProvider.overrideWith((ref) async => null),
          if (verified)
            profileRepositoryProvider.overrideWithValue(
              _NewAccountProfiles(profileClient!),
            ),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          deviceHashProvider.overrideWith((ref) async => "device-hash"),
          loginSessionProvider.overrideWith((ref) => Stream.value(session)),
          verifiedUserIdProvider.overrideWith(
            (ref) async => verified ? 'test-user' : null,
          ),
        ],
        child: throughApp
            ? const App()
            : MaterialApp(
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
  Future<void> finishRequest(WidgetTester tester) async {
    // Supabase decodes responses in a real isolate, outside the fake test clock.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.text('Sending code…').evaluate().isEmpty &&
          find.text('Please wait…').evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('OTP request did not finish');
  }

  for (final error in ['OTP_WRONG', 'OTP_EXPIRED', 'OTP_LOCKED']) {
    testWidgets('OTP maps $error and respects backend resend timing', (
      tester,
    ) async {
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('send-otp')) {
              return http.Response(
                jsonEncode({
                  'challenge_id': 'challenge',
                  'resend_after': 60,
                  'expires_in': 600,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({
                'error': {'code': error},
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      addTearDown(() => tester.runAsync(client.dispose));
      var now = DateTime(2026);
      await launch(tester, client: client, now: () => now, throughApp: true);
      expect(
        find.ancestor(
          of: find.text('Send code'),
          matching: find.byType(Overlay),
        ),
        findsWidgets,
      );
      await tester.ensureVisible(find.text('Send code'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Send code'));
      });
      await finishRequest(tester);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Resend in 60s'),
            )
            .onPressed,
        isNull,
      );
      if (error == 'OTP_WRONG') {
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.autofillHints, isNull);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
        expect(field.enableIMEPersonalizedLearning, isFalse);
        expect(field.enableInlinePrediction, isFalse);
        await tester.showKeyboard(find.byType(TextField));
        // Use incremental platform editing updates, including backspace.
        for (final text in ['1', '12', '1', '13', '1', '15', '', '654321']) {
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            ),
          );
          await tester.pump();
          expect(field.controller!.text, text);
          // Rebuilding for the resend timer must not restore deleted text.
          await tester.pump(const Duration(seconds: 1));
          expect(field.controller!.text, text);
        }
        // A delayed OS autofill response must not restore an erased OTP.
        await tester.enterText(find.byType(TextField), '038909');
        await tester.enterText(find.byType(TextField), '03');
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        tester.binding.channelBuffers.push(
          'flutter/textinput',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('TextInputClient.updateEditingStateWithTag', [
              -1,
              {
                editable.autofillId: const TextEditingValue(
                  text: '038909',
                  selection: TextSelection.collapsed(offset: 6),
                ).toJSON(),
              },
            ]),
          ),
          (_) {},
        );
        await tester.pump();
        expect(field.controller!.text, '03');
        // Pasting remains supported and still enforces six numeric digits.
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '12a3456',
            selection: TextSelection.collapsed(offset: 7),
          ),
        );
        await tester.pump();
        expect(field.controller!.text, '123456');
      }
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.text('Verify code'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Verify code'));
      });
      await finishRequest(tester);
      final expected = {
        'OTP_WRONG': 'That code is incorrect. Check your email and try again.',
        'OTP_EXPIRED': 'Your code has expired. Request a new code to continue.',
        'OTP_LOCKED': "You've reached the limit of 5 incorrect attempts. Wait until this code expires, then request a new code.",
      };
      expect(find.text(expected[error]!), findsOneWidget);
      now = now.add(const Duration(seconds: 59));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump();
      expect(find.text('Resend in 1s'), findsOneWidget);
      now = now.add(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Resend code'))
            .onPressed,
        error == 'OTP_LOCKED' ? isNull : isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('verified state proceeds to profile setup with no OTP actions', (
    tester,
  ) async {
    await launch(tester, verified: true, throughApp: true);
    expect(find.text('Choose your role'), findsOneWidget);
    expect(find.text('Send code'), findsNothing);
    expect(find.text('Verify code'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
