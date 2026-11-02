import 'dart:typed_data';
import 'dart:convert';

import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/onboarding/domain/profile_photo.dart';
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

  Map<String, dynamic> rowFor(String role) => {
    'id': 'user-1',
    'role': role,
    'display_name': 'Alex',
    'email': 'alex@example.com',
    'school': 'School',
    'avatar_path': 'user-1/old.png',
    'google_photo_url': 'https://example.invalid/google.png',
    'privacy_accepted_at': '2026-10-15T00:00:00Z',
    'privacy_version': 'original',
    'deleted_at': null,
    'created_at': '2026-10-15T00:00:00Z',
    'updated_at': '2026-11-02T01:00:00Z',
  };
  http.Response response(Object row, http.Request request) => http.Response(
    jsonEncode(row),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  for (final role in ['student', 'instructor']) {
    test(
      'edit $role sends only allowed fields and preserves photo/identity/consent',
      () async {
        var row = rowFor(role);
        Map<String, dynamic>? patch;
        final client = await signedIn(
          MockClient((request) async {
            if (request.method == 'PATCH') {
              patch = jsonDecode(request.body) as Map<String, dynamic>;
              row = {...row, ...patch!};
              return response(row, request);
            }
            return response([row], request);
          }),
        );
        final saved = await ProfileRepository(client)
            .edit(userId: 'user-1', name: ' Changed ', school: '  ');
        expect(patch, {'display_name': 'Changed', 'school': null});
        expect(saved.row['privacy_version'], 'original');
        expect(saved.row['privacy_accepted_at'], '2026-10-15T00:00:00Z');
        expect(saved.role.name, role);
        expect(saved.email, 'alex@example.com');
        expect(saved.avatarPath, 'user-1/old.png');
        expect(saved.photoUrl, 'https://example.invalid/google.png');
      },
    );
  }

  test(
    'failed photo upload preserves row; retry reuses the same owner path',
    () async {
      var row = rowFor('student');
      var fail = true;
      var patches = 0;
      final paths = <String>[];
      final photo = ProfilePhotoDraft.fromBytes(
        Uint8List.fromList([255, 216, 255, 0]),
      );
      final client = await signedIn(
        MockClient((request) async {
          if (request.url.path.contains('/storage/v1/object/avatars/')) {
            paths.add(request.url.path);
            if (fail) throw http.ClientException('upload failed');
            return response({'Key': 'avatars/user-1/${photo.id}.jpg'}, request);
          }
          if (request.method == 'PATCH') {
            patches++;
            final patch = jsonDecode(request.body) as Map<String, dynamic>;
            expect(patch.keys.toSet(), {
              'display_name',
              'school',
              'avatar_path',
            });
            row = {...row, ...patch};
            return response(row, request);
          }
          return response([row], request);
        }),
      );
      final repository = ProfileRepository(client);
      await expectLater(
        repository.edit(
          userId: 'user-1',
          name: 'Changed',
          school: 'School',
          photo: photo,
        ),
        throwsA(
          isA<ProfileEditException>().having(
            (e) => e.uncertain,
            'uncertain',
            false,
          ),
        ),
      );
      expect(patches, 0);
      expect(row['avatar_path'], 'user-1/old.png');
      fail = false;
      final saved = await repository.edit(
        userId: 'user-1',
        name: 'Changed',
        school: 'School',
        photo: photo,
      );
      expect(saved.avatarPath, 'user-1/${photo.id}.jpg');
      expect(paths.toSet(), hasLength(1));
      expect(patches, 1);
    },
  );

  test('lost PATCH response and failed reconciliation are resolved before retry mutations', () async {
    var row = rowFor('student');
    var readsUnavailable = false;
    var patches = 0;
    final client = await signedIn(
      MockClient((request) async {
        if (request.method == 'PATCH') {
          patches++;
          row = {...row, ...jsonDecode(request.body) as Map<String, dynamic>};
          readsUnavailable = true;
          throw http.ClientException('response lost');
        }
        if (readsUnavailable) throw http.ClientException('read unavailable');
        return response([row], request);
      }),
    );
    final repository = ProfileRepository(client);
    await expectLater(
      repository.edit(userId: 'user-1', name: 'Changed', school: 'School'),
      throwsA(
        isA<ProfileEditException>().having(
          (e) => e.uncertain,
          'uncertain',
          true,
        ),
      ),
    );
    readsUnavailable = false;
    final saved = await repository.edit(
      userId: 'user-1',
      name: 'Changed',
      school: 'School',
    );
    expect(saved.name, 'Changed');
    expect(patches, 1);
  });

  test('invalid edit and foreign user are refused before requests', () async {
    var requests = 0;
    final client = await signedIn(
      MockClient((request) async {
        requests++;
        return response([], request);
      }),
    );
    final repository = ProfileRepository(client);
    await expectLater(
      repository.edit(userId: 'user-1', name: ' ', school: ''),
      throwsArgumentError,
    );
    await expectLater(
      repository.edit(
        userId: 'user-1',
        name: List.filled(81, 'a').join(),
        school: '',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.edit(
        userId: 'user-1',
        name: 'Valid',
        school: List.filled(121, 'a').join(),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.edit(userId: 'foreign', name: 'Valid', school: ''),
      throwsStateError,
    );
    expect(requests, 0);
  });
}
