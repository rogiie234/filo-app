import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/data/question_bank_repository.dart';

const stamp = '2026-11-11T00:00:00.123456Z';
String rowId(int i) => 'q${i.toString().padLeft(3, '0')}';
Map<String, dynamic> quizRow(String id) => {
  'id': id,
  'class_id': 'class',
  'author_id': 'owner',
  'title': id,
  'updated_at': stamp,
  'locked_at': null,
  'deleted_at': null,
  'questions': [
    {'count': 0},
  ],
};
Future<SupabaseClient> signedClient(
  Future<http.Response> Function(http.Request) handle,
) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final response = await handle(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': 'test-token',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      'user': {
        'id': 'owner',
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': stamp,
      },
    }),
  );
  return client;
}

http.Response reply(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
Future<AppDatabase> database() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await db.customStatement(
    "INSERT INTO cache_profiles(id,role,display_name) VALUES ('owner','instructor','Owner')",
  );
  await db.customStatement(
    "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','owner','Course','A','2026','ABC123')",
  );
  return db;
}

void main() {
  test('bank cursor keeps full precision and tie order across deletion and short pages', () async {
    var pages = 0;
    final rows = List.generate(
      205,
      (i) => <String, dynamic>{
        'id': rowId(i),
        'created_at': stamp,
        'course': 'Course',
        'type': 'essay',
        'prompt': rowId(i),
        'points': 1,
      },
    );
    final client = await signedClient((request) async {
      if (request.url.pathSegments.last == 'profiles')
        return reply({'role': 'instructor', 'deleted_at': null});
      expect(request.url.pathSegments.last, 'bank_questions');
      final params = request.url.queryParameters;
      expect(params['offset'], isNull);
      expect(params['order'], 'created_at.desc.nullslast,id.asc.nullslast');
      expect(params['course_key'], 'eq.course');
      final filter = params['or'];
      String? after;
      if (filter != null) {
        expect(filter, contains(stamp));
        after = RegExp(r'id.gt.(q[0-9]+)').firstMatch(filter)!.group(1);
      }
      if (++pages == 2) rows.removeAt(0);
      return reply(
        rows
            .where(
              (row) =>
                  after == null || (row['id'] as String).compareTo(after) > 0,
            )
            .take(73)
            .toList(),
      );
    });
    final result = await QuestionBankRepository(
      client,
      'owner',
      () => true,
    ).list(course: 'Course');
    expect(result.map((q) => q.id).toList(), List.generate(205, rowId));
    expect(pages, 4);
  });

  for (final fail in [false, true]) {
    test(
      'assessment cursor and cache preservation; second page fails=$fail',
      () async {
        final db = await database();
        const previous = '[{"id":"previous"}]';
        await db.customStatement(
          'INSERT INTO instructor_quiz_lists VALUES (?,?)',
          ['class', previous],
        );
        await db.customStatement(
          'INSERT INTO instructor_quiz_details VALUES (?,?,?)',
          [rowId(204), 'class', '{}'],
        );
        final rows = List.generate(205, (i) => quizRow(rowId(i)));
        var pages = 0;
        final client = await signedClient((request) async {
          if (request.url.pathSegments.last == 'classes')
            return reply({
              'owner_id': 'owner',
              'archived_at': null,
              'deleted_at': null,
            });
          final params = request.url.queryParameters;
          expect(params['order'], 'id.asc.nullslast');
          expect(params['offset'], isNull);
          if (++pages == 2) {
            if (fail)
              return reply({
                'code': 'XX000',
                'message': 'fixture failure',
              }, 500);
            rows.removeAt(0);
          }
          final after = params['id']?.substring(3);
          return reply(
            rows
                .where(
                  (row) =>
                      after == null ||
                      (row['id'] as String).compareTo(after) > 0,
                )
                .take(73)
                .toList(),
          );
        });
        final repository = InstructorQuizRepository(
          db,
          client,
          'owner',
          () => true,
        );
        if (fail) {
          await expectLater(
            repository.refreshList('class'),
            throwsA(isA<PostgrestException>()),
          );
          final cached = await db
              .customSelect('SELECT payload FROM instructor_quiz_lists')
              .getSingle();
          expect(cached.read<String>('payload'), previous);
        } else {
          final result = await repository.refreshList('class');
          expect(
            result.map((q) => q['id']).toList(),
            List.generate(205, rowId),
          );
          expect(pages, 4);
        }
        expect(
          await db.customSelect('SELECT id FROM instructor_quiz_details').get(),
          hasLength(1),
        );
      },
    );
  }

  test(
    'detail refresh supersedes an in-flight list before cache replacement',
    () async {
      final db = await database();
      final rows = List.generate(205, (i) => quizRow(rowId(i)));
      var runs = 0;
      var superseded = false;
      late InstructorQuizRepository repository;
      final client = await signedClient((request) async {
        final params = request.url.queryParameters;
        final table = request.url.pathSegments.last;
        if (table == 'classes')
          return reply({
            'owner_id': 'owner',
            'archived_at': null,
            'deleted_at': null,
          });
        if (table == 'questions') return reply([]);
        if (params['id']?.startsWith('eq.') == true)
          return reply(quizRow(rowId(204)));
        final after = params['id']?.substring(3);
        if (after == null) runs++;
        if (after != null && !superseded) {
          superseded = true;
          await repository.refreshQuiz('class', rowId(204));
        }
        return reply(
          rows
              .where(
                (row) =>
                    after == null || (row['id'] as String).compareTo(after) > 0,
              )
              .take(73)
              .toList(),
        );
      });
      repository = InstructorQuizRepository(db, client, 'owner', () => true);
      expect(await repository.refreshList('class'), hasLength(205));
      expect(runs, 2);
      expect(
        await db.customSelect('SELECT id FROM instructor_quiz_details').get(),
        hasLength(1),
      );
    },
  );

  for (final changed in [false, true]) {
    test(
      'question cursor handles equal positions and refuses changed snapshot=$changed',
      () async {
        final db = await database();
        var pages = 0;
        final client = await signedClient((request) async {
          final params = request.url.queryParameters;
          switch (request.url.pathSegments.last) {
            case 'classes':
              return reply({
                'owner_id': 'owner',
                'archived_at': null,
                'deleted_at': null,
              });
            case 'quizzes':
              return reply({
                ...quizRow('quiz'),
                if (changed && params['select'] != '*') 'updated_at': 'changed',
              });
            case 'questions':
              expect(
                params['order'],
                'position.asc.nullslast,id.asc.nullslast',
              );
              expect(params['offset'], isNull);
              final filter = params['or'];
              final after = filter == null
                  ? null
                  : RegExp(r'id.gt.(q[0-9]+)').firstMatch(filter)!.group(1);
              if (filter != null) expect(filter, contains('position.eq.7'));
              pages++;
              return reply(
                List.generate(
                      205,
                      (i) => {
                        'id': rowId(i),
                        'position': 7,
                        'type': 'essay',
                        'prompt': rowId(i),
                        'points': 1,
                        'question_options': [],
                        'answer_keys': null,
                      },
                    )
                    .where(
                      (row) =>
                          after == null ||
                          (row['id'] as String).compareTo(after) > 0,
                    )
                    .take(73)
                    .toList(),
              );
            default:
              throw StateError('Unexpected request ${request.url}');
          }
        });
        final repository = InstructorQuizRepository(
          db,
          client,
          'owner',
          () => true,
        );
        if (changed) {
          await expectLater(
            repository.refreshQuiz('class', 'quiz'),
            throwsStateError,
          );
          expect(
            await db
                .customSelect('SELECT id FROM instructor_quiz_details')
                .get(),
            isEmpty,
          );
        } else {
          final result = await repository.refreshQuiz('class', 'quiz');
          expect(
            result.questions.map((q) => q.id).toList(),
            List.generate(205, rowId),
          );
        }
        expect(pages, 4);
      },
    );
  }
}
