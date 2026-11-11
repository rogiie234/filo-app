import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/results/data/results_cache.dart';
import 'package:filo/features/results/data/results_remote.dart';
import 'package:filo/features/results/data/quiz_grades_repository.dart';
import 'package:filo/features/results/data/student_results_repository.dart';
import 'package:filo/features/results/domain/results.dart';

class GradeRemote extends SupabaseResultsRemote {
  GradeRemote(SupabaseClient client) : super(client, 'student');
  int active = 0, peak = 0, quizReads = 0, sessionReads = 0, resultReads = 0;
  bool fail = false, released = true;
  @override
  Future<ResultJson> quiz(String id, {required bool instructor}) async {
    quizReads++;
    throw StateError('Class refresh must reuse fresh metadata');
  }

  @override
  Future<List<ResultJson>> classQuizzes(String id) async => List.generate(
    7,
    (i) => {
      'id': 'q$i',
      'class_id': 'class',
      'status': 'published',
      'title': 'Quiz $i',
    },
  );
  @override
  Future<ResultJson?> mySession(String id) async {
    sessionReads++;
    active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    active--;
    if (fail && id == 'q1')
      throw const PostgrestException(
        message: 'Class access denied',
        code: '42501',
      );
    return {
      'session_id': 's$id',
      'status': 'submitted',
      'results_released': released,
    };
  }

  @override
  Future<ResultJson> result(String id) async {
    resultReads++;
    return {
      'score': 7,
      'total_points': 10,
      'percent': 70,
      'passed': true,
      'review': null,
    };
  }
}

void main() {
  for (final fail in [false, true]) {
    test(
      'student grades reuse metadata; bounded flights; access failure=$fail',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.customStatement(
          "INSERT INTO cache_profiles(id,role,display_name) VALUES ('teacher','instructor','Teacher'),('student','student','Ada')",
        );
        await db.customStatement(
          "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','teacher','Course','A','2026','ABC123')",
        );
        await db.customStatement(
          "INSERT INTO cache_class_members(id,class_id,student_id,status) VALUES ('m','class','student','active')",
        );
        var classReads = 0, memberReads = 0;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            Object body;
            if (request.url.pathSegments.last == 'classes') {
              classReads++;
              body = {'owner_id': 'teacher', 'deleted_at': null};
            } else {
              memberReads++;
              body = {'id': 'm'};
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
        final cache = ResultsCache(db, 'student', () => true);
        final remote = GradeRemote(client)..fail = fail;
        await expectLater(
          StudentResultsRepository(
            cache,
            remote,
            () => true,
          ).refresh('q0', knownQuiz: {'id': 'other', 'class_id': 'class'}),
          throwsA(isA<Exception>()),
        );
        expect(remote.sessionReads, 0);
        final repository = QuizGradesRepository(cache, remote);
        if (fail) {
          await expectLater(
            repository.refresh('class'),
            throwsA(isA<Exception>()),
          );
          expect(remote.active, 0);
          expect(
            await db.customSelect('SELECT id FROM results_snapshots').get(),
            isEmpty,
          );
        } else {
          await repository.refresh('class');
          expect(
            (await repository.read(
              'class',
              instructor: false,
            ))!['quiz_attempts'],
            hasLength(7),
          );
          expect(remote.sessionReads, 7);
          expect(remote.resultReads, 7);
          remote.released = false;
          await repository.refresh('class');
          expect(remote.resultReads, 7);
          expect((await cache.student('q0'))!.result, isNull);
        }
        expect(remote.quizReads, 0);
        expect(remote.peak, 3);
        expect(classReads, fail ? 1 : 2);
        expect(memberReads, fail ? 1 : 2);
      },
    );
  }
}
