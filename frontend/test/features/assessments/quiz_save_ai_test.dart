import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';

// Isolate the save writer; SQL tests cover persistence and server authorization.
class SaveRepository extends InstructorQuizRepository {
  SaveRepository(AppDatabase database, SupabaseClient client, this.saved)
    : super(database, client, 'owner', () => true);
  InstructorQuiz saved;
  @override
  Future<InstructorQuiz> refreshQuiz(String classId, String quizId) async =>
      saved;
  @override
  Future<List<Map<String, dynamic>>> refreshList(String classId) async => [];
}

void main() {
  for (final generated in [false, true]) {
    for (final editing in [false, true]) {
      for (final failing in [false, true]) {
        test(
          'save AI=$generated; editing=$editing; failure=$failing',
          () async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            await db.customStatement(
              "INSERT INTO cache_profiles(id,role,display_name) VALUES ('owner','instructor','Owner')",
            );
            await db.customStatement(
              "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','owner','Course','A','2026','ABC123')",
            );
            final row = {'id': 'quiz', 'class_id': 'class', 'title': 'Draft'};
            final initial = InstructorQuiz(row, [
              if (editing)
                QuizQuestion(
                  localId: 'local',
                  id: 'question',
                  aiGenerated: generated,
                  payload: {'type': 'essay', 'prompt': 'Original', 'points': 1},
                ),
            ]);
            final requests = <http.Request>[];
            late SaveRepository repo;
            final client = SupabaseClient(
              'https://example.supabase.co',
              'test',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
              httpClient: MockClient((request) async {
                requests.add(request);
                final name = request.url.pathSegments.last;
                Object? body;
                if (name == 'classes' && request.method == 'GET') {
                  body = {
                    'owner_id': 'owner',
                    'archived_at': null,
                    'deleted_at': null,
                  };
                } else if (name == 'save_question') {
                  if (failing) {
                    return http.Response(
                      jsonEncode({'code': '22023', 'message': 'Save rejected'}),
                      400,
                      request: request,
                      headers: {'content-type': 'application/json'},
                    );
                  }
                  final parameters = jsonDecode(request.body) as Map;
                  final question = Map<String, dynamic>.from(
                    parameters['p_question'] as Map,
                  );
                  repo.saved = InstructorQuiz(row, [
                    QuizQuestion(
                      localId: 'server',
                      id: 'question',
                      payload: question,
                      aiGenerated: question['ai_generated'] == true,
                    ),
                  ]);
                  body = {'question_id': 'question', 'option_ids': []};
                } else if (name == 'reorder_questions') {
                  body = null;
                } else {
                  throw StateError(
                    'Unexpected request: ${request.method} ${request.url}',
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
            await client.auth.recoverSession(
              jsonEncode({
                'access_token': 'test-token',
                'refresh_token': 'test-refresh',
                'token_type': 'bearer',
                'expires_at':
                    DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                'user': {
                  'id': 'owner',
                  'aud': 'authenticated',
                  'app_metadata': {},
                  'user_metadata': {},
                  'created_at': '2026-10-15T00:00:00Z',
                },
              }),
            );
            repo = SaveRepository(db, client, initial);
            final draft = QuizDraft(initial);
            if (!editing) {
              draft.questions.add(
                QuizQuestion(
                  localId: 'local',
                  aiGenerated: generated,
                  payload: {'type': 'essay', 'prompt': 'Changed', 'points': 1},
                ),
              );
            } else {
              draft.questions.single.payload['prompt'] = 'Changed';
            }
            if (failing) {
              await expectLater(
                repo.save(draft),
                throwsA(isA<QuizReconciliationRequired>()),
              );
              expect(draft.reconciliationRequired, true);
              expect(draft.isDirty, true);
              expect(repo.saved, same(initial));
              await expectLater(
                repo.save(draft),
                throwsA(isA<QuizReconciliationRequired>()),
              );
            } else {
              final result = await repo.save(draft);
              expect(result.questions.single.aiGenerated, generated);
              expect(draft.isDirty, false);
              expect(draft.reconciliationRequired, false);
            }
            final saves = requests
                .where((r) => r.url.pathSegments.last == 'save_question')
                .toList();
            expect(saves, hasLength(1));
            expect(jsonDecode(saves.single.body), {
              'p_quiz': 'quiz',
              'p_question': {
                'type': 'essay',
                'prompt': 'Changed',
                'points': 1,
                'id': editing ? 'question' : null,
                'position': 0,
                'ai_generated': generated,
              },
            });
            expect(
              requests.any((r) => r.url.pathSegments.last == 'questions'),
              false,
            );
          },
        );
      }
    }
  }
}
