import 'dart:convert';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/domain/quiz_publish.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiTestRepository extends InstructorQuizRepository {
  AiTestRepository(AppDatabase database, SupabaseClient client)
    : super(database, client, 'owner', () => true);
  final row = <String, dynamic>{
    'id': 'quiz',
    'class_id': 'class',
    'title': 'Draft',
    'status': 'draft',
    'locked_at': null,
  };
  final remote = <QuizQuestion>[];
  bool failFinalRefresh = false;
  @override
  Future<InstructorQuiz> refreshQuiz(String classId, String quizId) async {
    if (failFinalRefresh && remote.isNotEmpty)
      throw StateError('Refresh failed');
    return InstructorQuiz(row, remote.map((q) => q.copy()).toList());
  }

  @override
  Future<List<Map<String, dynamic>>> refreshList(String classId) async => [];
}

QuizQuestion aiQuestion(String name) => QuizQuestion(
  localId: name,
  aiGenerated: true,
  payload: {
    'type': 'essay',
    'prompt': name,
    'points': 5,
    'explanation': 'Reason',
  },
);
const sourceContext = AiSourceContext(
  sources: [SourcePrefix('att:one', 'lesson.txt', 4)],
  difficulty: 'medium',
);

void main() {
  for (final mode in [
    'partial',
    'lost-response',
    'lost-no-match',
    'failed-replacement',
    'replacement',
    'final-refresh-failure',
    'locked',
  ]) {
    test('AI writer $mode keeps provenance and confirmed outcomes', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO cache_profiles(id,role,display_name) VALUES('owner','instructor','Owner')",
      );
      await db.customStatement(
        "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES('class','owner','Course','A','2026','ABC123')",
      );
      late AiTestRepository repo;
      var inserts = 0;
      var rejectSecond = true;
      final positions = <String, int>{};
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object? body;
          final route = request.url.pathSegments.last;
          if (route == 'classes') {
            body = {
              'owner_id': 'owner',
              'archived_at': null,
              'deleted_at': null,
            };
          } else if (route == 'questions') {
            if (request.url.queryParameters.containsKey('id')) {
              final id = request.url.queryParameters['id']!.substring(3);
              body = {'position': positions[id] ?? 0};
            } else if (request.url.queryParameters.containsKey('position')) {
              final n = int.parse(
                request.url.queryParameters['position']!.substring(3),
              );
              body = positions.entries
                  .where((e) => e.value == n)
                  .map((e) => {'id': e.key})
                  .toList();
            } else {
              final values = positions.values.toList()..sort();
              body = values.isEmpty
                  ? []
                  : [
                      {'position': values.last},
                    ];
            }
          } else if (route == 'save_question') {
            final q = Map<String, dynamic>.from(
              (jsonDecode(request.body) as Map)['p_question'] as Map,
            );
            if (mode == 'failed-replacement' ||
                (mode == 'partial' &&
                    q['prompt'] == 'Second' &&
                    rejectSecond)) {
              return http.Response(
                jsonEncode({'code': '22023', 'message': 'Known rejection'}),
                400,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            inserts++;
            final id = q['id'] as String? ?? 'saved-$inserts';
            positions[id] = q['position'] as int;
            final payload = Map<String, dynamic>.from(q)
              ..remove('id')
              ..remove('position')
              ..remove('ai_generated');
            if (mode == 'lost-no-match')
              throw const FormatException('Unconfirmed transport outcome');
            repo.remote.removeWhere((old) => old.id == id);
            repo.remote.add(
              QuizQuestion(
                localId: id,
                id: id,
                aiGenerated: true,
                payload: payload,
              ),
            );
            if (mode == 'lost-response')
              throw const FormatException('Response lost after remote commit');
            body = {'question_id': id, 'option_ids': []};
          } else {
            throw StateError('Unexpected route');
          }
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
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
            'role': 'authenticated',
            'email': 'test@example.com',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      repo = AiTestRepository(db, client);
      if (mode == 'locked') {
        repo.row['locked_at'] = '2026-01-01T00:00:00Z';
        await expectLater(
          repo.saveAiBatch('class', 'quiz', [
            aiQuestion('First'),
          ], sourceContext),
          throwsA(isA<AiDraftSaveFailure>()),
        );
        expect(inserts, 0);
        return;
      }
      if (mode == 'failed-replacement' || mode == 'replacement') {
        final original = aiQuestion('Original');
        original.payload['points'] = 9;
        repo.remote.add(
          QuizQuestion(
            localId: 'original',
            id: 'original',
            aiGenerated: true,
            payload: original.payload,
          ),
        );
        positions['original'] = 7;
        final operation = repo.replaceAiQuestion(
          'class',
          'quiz',
          'original',
          aiQuestion('Replacement'),
          sourceContext,
        );
        if (mode == 'failed-replacement') {
          await expectLater(
            operation,
            throwsA(isA<QuizReconciliationRequired>()),
          );
          expect(repo.remote.single.prompt, 'Original');
        } else {
          final saved = await operation;
          expect(saved.questions.single.id, 'original');
          expect(saved.questions.single.prompt, 'Replacement');
          expect(saved.questions.single.points, 9);
          expect(positions['original'], 7);
          expect(await FileTextCache(db).contextFor('original'), isNotNull);
        }
        expect(repo.remote.single.aiGenerated, true);
        return;
      }
      if (mode == 'final-refresh-failure') {
        repo.failFinalRefresh = true;
        await expectLater(
          repo.saveAiBatch('class', 'quiz', [
            aiQuestion('First'),
          ], sourceContext),
          throwsA(
            isA<AiDraftSaveFailure>().having(
              (e) => e.staged,
              'journaled',
              true,
            ),
          ),
        );
        repo.failFinalRefresh = false;
        final checked = await repo.saveAiBatch('class', 'quiz', [], null);
        expect(checked.saved.questions.single.prompt, 'First');
        expect(checked.pending, 0);
        expect(inserts, 1);
        return;
      }
      final first = await repo.saveAiBatch(
        'class',
        'quiz',
        mode == 'partial'
            ? [aiQuestion('First'), aiQuestion('Second')]
            : [aiQuestion('First')],
        sourceContext,
      );
      if (mode == 'partial') {
        expect(first.added, 1);
        expect(first.pending, 1);
        expect(first.uncertain, 0);
        rejectSecond = false;
        final retry = await repo.saveAiBatch('class', 'quiz', [], null);
        expect(retry.added, 1);
        expect(retry.pending, 0);
        expect(inserts, 2);
      } else {
        expect(first.uncertain, 1);
        expect(inserts, 1);
        final retry = await repo.saveAiBatch('class', 'quiz', [], null);
        expect(retry.pending, mode == 'lost-no-match' ? 1 : 0);
        expect(inserts, 1);
      }
      expect(repo.remote.every((q) => q.aiGenerated), true);
      expect(
        await FileTextCache(db)
            .contextFor(mode == 'lost-no-match' ? 'First' : 'saved-1'),
        isNotNull,
      );
    });
  }
  test(
    'AI counts include edited/duplicated AI questions and exclude manual ones',
    () {
      final generated = aiQuestion('Generated');
      generated.payload['prompt'] = 'Edited';
      final manual = QuizQuestion.newQuestion('essay');
      expect(aiQuestionCount([generated, generated.duplicate(), manual]), 2);
      final draft = QuizDraft.create('class')
        ..questions.addAll([generated, generated.duplicate(), manual]);
      expect(
        quizPublishSummary(draft),
        contains('2 questions were written by AI. Have you checked them?'),
      );
    },
  );
}
