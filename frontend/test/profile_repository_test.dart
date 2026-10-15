import 'dart:convert';

import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<SupabaseClient> signedIn(http.Client httpClient) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        'user': {
          'id': 'user-1',
          'email': 'alex@example.com',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-15T00:00:00Z',
        },
      }),
    );
    addTearDown(client.dispose);
    return client;
  }

  test('missing profile is null; database errors propagate', () async {
    var fail = false;
    final client = await signedIn(
      MockClient(
        (request) async => fail
            ? http.Response(
                '{"code":"42501","message":"Access denied"}',
                403,
                headers: {'content-type': 'application/json'},
                request: request,
              )
            : http.Response(
                '[]',
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              ),
      ),
    );
    final repository = ProfileRepository(client);
    expect(await repository.fetch(), isNull);
    fail = true;
    await expectLater(repository.fetch(), throwsA(isA<PostgrestException>()));
  });

  test(
    'lost insert response retries by reading saved row without changing role',
    () async {
      Map<String, dynamic>? saved;
      var inserts = 0;
      final client = await signedIn(
        MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/profiles')) {
            inserts++;
            saved = jsonDecode(request.body) as Map<String, dynamic>;
            throw http.ClientException('response lost');
          }
          return http.Response(
            jsonEncode(saved == null ? [] : [saved]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = ProfileRepository(client);
      await expectLater(
        repository.create(
          role: AccountRole.student,
          name: ' Alex ',
          school: ' School ',
          consent: true,
        ),
        throwsA(isA<http.ClientException>()),
      );
      final profile = await repository.create(
        role: AccountRole.instructor,
        name: 'Alex',
        school: 'School',
        consent: true,
      );
      expect(profile.role, AccountRole.student);
      expect(inserts, 1);
      expect(saved!['id'], 'user-1');
      expect(saved!['email'], 'alex@example.com');
      expect(saved!['display_name'], 'Alex');
      expect(saved!['privacy_accepted_at'], isNotNull);
      expect(saved!['privacy_version'], '2026-10-15');
    },
  );

  test('unchecked consent fails before any database request', () async {
    var requests = 0;
    final client = await signedIn(
      MockClient((request) async {
        requests++;
        return http.Response('[]', 200, request: request);
      }),
    );
    await expectLater(
      ProfileRepository(client).create(
        role: AccountRole.student,
        name: 'Alex',
        school: '',
        consent: false,
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
  });
}
