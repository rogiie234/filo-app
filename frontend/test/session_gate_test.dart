import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/core/supabase/supabase_provider.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'offline cache authorization stays bound to verified session and device',
    () {
      final saved = jsonEncode({
        'session_id': 'verified-session',
        'device_hash': 'this-device',
      });
      expect(
        offlineSessionMatches(saved, 'verified-session', 'this-device'),
        isTrue,
      );
      expect(
        offlineSessionMatches(saved, 'new-unverified-session', 'this-device'),
        isFalse,
      );
      expect(
        offlineSessionMatches(saved, 'verified-session', 'another-device'),
        isFalse,
      );
      expect(
        offlineSessionMatches(
          'invalid-json',
          'verified-session',
          'this-device',
        ),
        isFalse,
      );
    },
  );
  String token(Map<String, dynamic> claims) =>
      'header.${base64UrlEncode(utf8.encode(jsonEncode(claims)))}.signature';

  test('requires a UUID session_id, even when a user ID is present', () {
    expect(
      () => sessionIdFromToken(token({'sub': 'user'})),
      throwsFormatException,
    );
    expect(
      () => sessionIdFromToken(token({'session_id': 'bad'})),
      throwsFormatException,
    );
    const id = '12345678-1234-1234-1234-123456789abc';
    expect(sessionIdFromToken(token({'session_id': id})), id);
  });

  test(
    'verification loss closes cached account data; verification reopens it',
    () async {
      final directory = await Directory.systemTemp.createTemp('filo-otp-gate-');
      final manager = UserDatabaseManager(
        directoryProvider: () async => directory,
      );
      String? verifiedUser;
      final container = ProviderContainer(
        overrides: [
          verifiedUserIdProvider.overrideWith((ref) async => verifiedUser),
          userDatabaseManagerProvider.overrideWithValue(manager),
        ],
      );
      final subscription = container.listen(accountDatabaseProvider, (_, _) {});
      try {
        expect(await container.read(accountDatabaseProvider.future), isNull);
        expect(await directory.list().isEmpty, isTrue);
        verifiedUser = 'verified-account';
        container.invalidate(verifiedUserIdProvider);
        await Future<void>.delayed(Duration.zero);
        final database = await container.read(accountDatabaseProvider.future);
        expect(database, isNotNull);
        verifiedUser = null;
        container.invalidate(verifiedUserIdProvider);
        await Future<void>.delayed(Duration.zero);
        expect(await container.read(accountDatabaseProvider.future), isNull);
      } finally {
        subscription.close();
        container.dispose();
        await manager.close();
        await directory.delete(recursive: true);
      }
    },
  );
  for (final monitorFailure in [
    StateError('platform unavailable'),
    TimeoutException('monitor'),
    null,
  ]) {
    for (final marker in [
      'matching',
      'missing',
      'wrong-session',
      'wrong-device',
    ]) {
      test(
        'monitor $monitorFailure uses only $marker verified marker',
        () async {
          var requests = 0;
          final client = SupabaseClient(
            'https://example.supabase.co',
            'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              requests++;
              return http.Response('false', 200, request: request);
            }),
          );
          addTearDown(client.dispose);
          const sessionId = '12345678-1234-1234-1234-123456789abc';
          await client.auth.recoverSession(
            jsonEncode({
              'access_token': token({'session_id': sessionId}),
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_at':
                  DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
              'user': {
                'id': 'user',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-10-15T00:00:00Z',
              },
            }),
          );
          FlutterSecureStorage.setMockInitialValues({
            if (marker != 'missing')
              'filo.offline_verified.user': jsonEncode({
                'session_id': marker == 'wrong-session' ? 'other' : sessionId,
                'device_hash': marker == 'wrong-device' ? 'other' : 'device',
              }),
          });
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              supabaseClientProvider.overrideWithValue(client),
              loginSessionProvider.overrideWith(
                (ref) => Stream.value(client.auth.currentSession),
              ),
              deviceHashProvider.overrideWith((ref) async => 'device'),
              connectivityProvider.overrideWith(
                (ref) => monitorFailure == null
                    ? Stream.value(true)
                    : Stream.error(monitorFailure),
              ),
            ],
          );
          addTearDown(container.dispose);
          final subscription = container.listen(
            verifiedUserIdProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          expect(
            await container
                .read(verifiedUserIdProvider.future)
                .timeout(const Duration(seconds: 3)),
            monitorFailure != null && marker == 'matching' ? 'user' : null,
          );
          if (monitorFailure == null) {
            expect(requests, greaterThan(0));
            expect(
              await const FlutterSecureStorage().read(
                key: 'filo.offline_verified.user',
              ),
              isNull,
            );
          } else {
            expect(requests, 0);
          }
        },
      );
    }
  }
}
