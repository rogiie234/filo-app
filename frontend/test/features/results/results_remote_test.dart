import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/features/results/data/results_remote.dart';
import 'package:filo/features/results/domain/results.dart';

void main() {
  test(
    'student reads and instructor writes preserve RPC wire parameters',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final name = request.url.pathSegments.last;
          final body = name == 'get_my_session'
              ? {
                  'session_id': 's',
                  'status': 'submitted',
                  'results_released': true,
                }
              : name == 'get_result'
              ? {
                  'score': 7,
                  'total_points': 10,
                  'percent': 70,
                  'passed': true,
                  'review': null,
                }
              : null;
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final remote = SupabaseResultsRemote(client, 'student');
      await remote.mySession('quiz');
      await remote.result('s');
      await remote.write('grade_essay', {
        'p_answer': 'answer',
        'p_points': 0,
        'p_feedback': null,
      });
      await remote.write('release_results', {'p_quiz': 'quiz'});
      await remote.write('grant_second_chance', {
        'p_quiz': 'quiz',
        'p_student': 'student',
        'p_reason': 'Phone restarted',
        'p_proof': null,
      });
      expect(requests.map((r) => r.url.pathSegments.last), [
        'get_my_session',
        'get_result',
        'grade_essay',
        'release_results',
        'grant_second_chance',
      ]);
      expect(requests.map((r) => jsonDecode(r.body)), [
        {'p_quiz': 'quiz'},
        {'p_session': 's'},
        {'p_answer': 'answer', 'p_points': 0, 'p_feedback': null},
        {'p_quiz': 'quiz'},
        {
          'p_quiz': 'quiz',
          'p_student': 'student',
          'p_reason': 'Phone restarted',
          'p_proof': null,
        },
      ]);
      expect(requests.every((r) => r.method == 'POST'), isTrue);
    },
  );

  test(
    'detail keeps unanswered questions, keys and attempt option order',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          final Object body = switch (request.url.pathSegments.last) {
            'exam_sessions' => {
              'id': 's',
              'quiz_id': 'quiz',
              'status': 'submitted',
              'grading_complete': false,
              'question_order': ['essay', 'mc'],
              'option_orders': {
                'mc': ['b', 'a'],
              },
            },
            'questions' => [
              {
                'id': 'mc',
                'type': 'multiple_choice',
                'question_options': [
                  {'id': 'a', 'position': 0},
                  {'id': 'b', 'position': 1},
                ],
                'answer_keys': {'correct_option_id': 'b'},
              },
              {
                'id': 'essay',
                'type': 'essay',
                'question_options': [],
                'answer_keys': null,
              },
            ],
            'exam_answers' => [],
            _ => throw StateError('Unexpected request ${request.url}'),
          };
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final detail = AttemptDetail(
        await SupabaseResultsRemote(
          client,
          'teacher',
        ).detail({'id': 'quiz'}, 's'),
      );
      expect(detail.questions.map((q) => q['id']), ['essay', 'mc']);
      expect(detail.questions.every((q) => q['answer'] == null), isTrue);
      expect(detail.pendingEssays, 0);
      expect(
        (detail.questions.last['question_options'] as List).map((o) => o['id']),
        ['b', 'a'],
      );
      expect(detail.questions.last['answer_keys'], {'correct_option_id': 'b'});
    },
  );

  test('active members paginate beyond 200 without accepting revoked-owner emptiness', () async {
    var owner = 'teacher';
    var pages = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        Object body;
        if (request.url.pathSegments.last == 'classes') {
          body = {'owner_id': owner, 'deleted_at': null};
        } else {
          pages++;
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          body = List.generate(
            offset == 0 ? 200 : 1,
            (i) => {'id': '${offset + i}', 'student_id': '${offset + i}'},
          );
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final remote = SupabaseResultsRemote(client, 'teacher');
    expect((await remote.members('class')).length, 201);
    expect(pages, 2);
    owner = 'someone-else';
    await expectLater(remote.members('class'), throwsA(isA<Exception>()));
    expect(pages, 2);
  });
}
