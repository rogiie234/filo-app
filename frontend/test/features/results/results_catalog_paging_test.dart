import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/features/results/data/results_remote.dart';
import 'package:filo/features/exams/data/exam_remote.dart';

String key(String prefix, int i) => '$prefix${i.toString().padLeft(4, '0')}';
http.Response response(http.Request request, Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
void main() {
  test(
    'monitoring pages every table through short pages and concurrent deletion',
    () async {
      final tables = <String, List<Map<String, dynamic>>>{
        for (final name in [
          'exam_sessions',
          'class_members',
          'second_chances',
          'exam_answers',
        ])
          name: List.generate(
            205,
            (i) => {'id': key('r', i), 'session_id': key('s', i)},
          ),
      };
      final counts = <String, int>{};
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          if (table == 'classes')
            return response(request, {
              'owner_id': 'teacher',
              'deleted_at': null,
            });
          final params = request.url.queryParameters;
          expect(params['order'], 'id.asc.nullslast');
          expect(params['offset'], isNull);
          final count = counts.update(table, (n) => n + 1, ifAbsent: () => 1);
          if (count == 2) tables[table]!.removeAt(0);
          final after = params['id']?.substring(3);
          return response(
            request,
            tables[table]!
                .where(
                  (row) =>
                      after == null ||
                      (row['id'] as String).compareTo(after) > 0,
                )
                .take(73)
                .toList(),
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await SupabaseResultsRemote(
        client,
        'teacher',
      ).monitoring({'id': 'quiz', 'class_id': 'class'});
      for (final field in [
        'sessions',
        'members',
        'second_chances',
        'essay_answers',
      ]) {
        expect(
          (result[field] as List).map((row) => row['id']).toList(),
          List.generate(205, (i) => key('r', i)),
        );
      }
      expect(counts.values, everyElement(4));
    },
  );

  for (final fail in [false, true]) {
    test('catalog exceeds API cap; late page failure=$fail', () async {
      var membershipPages = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          final params = request.url.queryParameters;
          expect(params['order'], 'id.asc.nullslast');
          expect(params['offset'], isNull);
          final after = params['id']?.substring(3);
          if (request.url.pathSegments.last == 'class_members') {
            membershipPages++;
            return response(
              request,
              List.generate(
                    1001,
                    (i) => {
                      'id': key('m', i),
                      'class_id': key('c', i),
                      'classes': {
                        'id': key('c', i),
                        'archived_at': i == 0 ? '2026-01-01T00:00:00Z' : null,
                      },
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
          }
          if (fail && after != null)
            return response(request, {
              'code': '503',
              'message': 'fixture unavailable',
            }, 503);
          final ids = params['class_id']!;
          return response(
            request,
            List.generate(
                  1001,
                  (i) => {
                    'id': key('q', i),
                    'class_id': key('c', i),
                    'opens_at': '2026-11-11T00:00:00.123456Z',
                  },
                )
                .where(
                  (row) =>
                      ids.contains(row['class_id'] as String) &&
                      (after == null ||
                          (row['id'] as String).compareTo(after) > 0),
                )
                .take(73)
                .toList(),
          );
        }),
      );
      addTearDown(client.dispose);
      final future = SupabaseExamRemote(client, 'student').quizzes();
      if (fail) {
        await expectLater(future, throwsA(isA<ExamFailure>()));
      } else {
        final rows = await future;
        expect(rows, hasLength(1001));
        expect(
          rows.map((r) => r['id']).toList(),
          List.generate(1001, (i) => key('q', i)),
        );
        expect(rows.first['class_archived'], isTrue);
      }
      expect(membershipPages, 15);
    });
  }
}
