import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:filo/core/sync/outbox_processor.dart';

import 'exam_test_support.dart';

void main() {
  test(
    'batch adapter sends exact fields and parses success and item errors',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'question_id': 'bool',
                'revision': 2,
                'saved_at': examEpoch.toIso8601String(),
              },
              {
                'question_id': 'q',
                'revision': 3,
                'error_code': '22001',
                'error_message': 'Answer must be at most 10000 characters',
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final receipts = await SupabaseExamRemote(client, 'student').saveBatch(
        'session',
        [
          const StoredAnswer(
            ExamAnswer(questionId: 'bool', boolean: false),
            2,
            false,
          ),
          const StoredAnswer(ExamAnswer(questionId: 'q', text: ''), 3, false),
        ],
      );
      expect(requests.single.url.pathSegments.last, 'save_answers');
      expect(jsonDecode(requests.single.body), {
        'p_session': 'session',
        'p_answers': [
          {
            'question_id': 'bool',
            'revision': 2,
            'option_id': null,
            'bool_answer': false,
            'text_answer': null,
          },
          {
            'question_id': 'q',
            'revision': 3,
            'option_id': null,
            'bool_answer': null,
            'text_answer': '',
          },
        ],
      });
      expect(receipts.first.savedAt, examEpoch);
      expect(
        receipts.last.failure!.message,
        'Keep your answer within 10,000 characters.',
      );
    },
  );

  test('duplicate receipts cannot acknowledge a different question', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            List.filled(2, {
              'question_id': 'q',
              'revision': 1,
              'saved_at': examEpoch.toIso8601String(),
            }),
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseExamRemote(client, 'student').saveBatch('session', [
        const StoredAnswer(
          ExamAnswer(questionId: 'q', text: 'Answer'),
          1,
          false,
        ),
        const StoredAnswer(
          ExamAnswer(questionId: 'bool', boolean: false),
          1,
          false,
        ),
      ]),
      throwsA(
        isA<ExamFailure>().having((e) => e.retryable, 'retryable', isTrue),
      ),
    );
  });

  for (final response in [
    [],
    [
      {
        'question_id': 'q',
        'revision': 99,
        'saved_at': examEpoch.toIso8601String(),
      },
    ],
    [
      {'question_id': 'q', 'revision': 1, 'saved_at': 'invalid'},
    ],
    [
      {
        'question_id': 'q',
        'revision': 1,
        'saved_at': examEpoch.toIso8601String(),
        'error_code': '22023',
        'error_message': 'Invalid',
      },
    ],
  ]) {
    test(
      'malformed or mismatched batch receipt is never confirmation: $response',
      () async {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode(response),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(client.dispose);
        await expectLater(
          SupabaseExamRemote(client, 'student').saveBatch('session', [
            const StoredAnswer(
              ExamAnswer(questionId: 'q', text: 'Answer'),
              1,
              false,
            ),
          ]),
          throwsA(
            isA<ExamFailure>().having((e) => e.retryable, 'retryable', isTrue),
          ),
        );
      },
    );
  }

  test('leave retries keep RPC event parameters and friendly errors', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"message":"Class access denied","code":"42501"}',
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final db = AppDatabase(NativeDatabase.memory());
    final coordinator = SyncCoordinator(db, client, 'student', () => true);
    addTearDown(() async {
      coordinator.dispose();
      await db.close();
      await client.dispose();
    });
    final event = QueuedAction('event', 'leave_event', {
      'session_id': 'session',
      'left_at': examEpoch.toIso8601String(),
    }, 0);
    for (var i = 0; i < 2; i++) {
      await expectLater(
        coordinator.dispatch(event),
        throwsA(
          isA<OutboxActionFailure>().having(
            (e) => e.message,
            'message',
            'You no longer have access to this exam.',
          ),
        ),
      );
    }
    expect(requests.map((r) => r.url.pathSegments.last), [
      'log_leave',
      'log_leave',
    ]);
    expect(
      requests.map((r) => jsonDecode(r.body)),
      everyElement({
        'p_event': 'event',
        'p_session': 'session',
        'p_left_at': examEpoch.toIso8601String(),
      }),
    );
  });
  test(
    'RPC adapter uses exact keys and preserves false and empty text',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final rpc = request.url.pathSegments.last;
          return http.Response(
            jsonEncode(switch (rpc) {
              'start_exam' => {'id': 'session'},
              'get_exam' => examPayload(),
              'get_my_session' => sessionPayload(),
              'submit_exam' => {'status': 'submitted'},
              _ => examEpoch.toIso8601String(),
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final remote = SupabaseExamRemote(client, 'student');
      await remote.start('quiz');
      await remote.exam('session');
      await remote.session('quiz');
      await remote.save(
        'session',
        const ExamAnswer(questionId: 'bool', boolean: false),
      );
      await remote.save('session', const ExamAnswer(questionId: 'q', text: ''));
      await remote.submit('session');
      expect(jsonDecode(requests[0].body), {'p_quiz': 'quiz'});
      expect(jsonDecode(requests[1].body), {'p_session': 'session'});
      expect(jsonDecode(requests[2].body), {'p_quiz': 'quiz'});
      expect(jsonDecode(requests[3].body), {
        'p_session': 'session',
        'p_question': 'bool',
        'p_option': null,
        'p_bool': false,
        'p_text': null,
      });
      expect((jsonDecode(requests[4].body) as Map)['p_text'], '');
      expect(jsonDecode(requests[5].body), {'p_session': 'session'});
    },
  );
  test(
    'discovery includes archived read-only classes and only published quizzes',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          requests.add(request);
          final rows = request.url.pathSegments.last == 'class_members'
              ? [
                  {
                    'class_id': 'class',
                    'classes': {
                      'id': 'class',
                      'archived_at': '2026-10-23T00:00:00Z',
                    },
                  },
                ]
              : [
                  {'id': 'quiz', 'title': 'Quiz', 'class_id': 'class'},
                ];
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final quizzes = await SupabaseExamRemote(client, 'student').quizzes();
      expect(quizzes, hasLength(1));
      expect(quizzes.single['class_archived'], isTrue);
      expect(
        requests.first.url.queryParameters,
        containsPair('student_id', 'eq.student'),
      );
      expect(
        requests.first.url.queryParameters,
        containsPair('status', 'eq.active'),
      );
      expect(
        requests.first.url.queryParameters,
        isNot(contains('classes.archived_at')),
      );
      expect(
        requests.first.url.queryParameters,
        containsPair('classes.deleted_at', 'is.null'),
      );
      expect(
        requests.last.url.queryParameters,
        containsPair('status', 'eq.published'),
      );
      expect(
        requests.last.url.queryParameters,
        containsPair('class_id', 'in.("class")'),
      );
    },
  );
  test('friendly errors distinguish permissions and transport retries', () {
    for (final message in [
      'This quiz has not opened yet',
      'This quiz has closed',
      'You have already taken this quiz',
      'This class is archived',
      'This attempt is closed',
      'Answer must be at most 10000 characters',
    ]) {
      final failure = examFailure(
        PostgrestException(message: message, code: 'P0001'),
      );
      expect(failure.message, isNotEmpty);
      expect(failure.retryable, isFalse);
    }
    final denied = examFailure(
      const PostgrestException(
        message: 'Private database details',
        code: '42501',
      ),
    );
    expect(denied.message, "You can't access this exam right now.");
    expect(denied.reconcile, isTrue);
    expect(examFailure(http.ClientException('network')).retryable, isTrue);
    expect(
      examFailure(
        const PostgrestException(
          message: 'Private database details',
          code: 'P0001',
        ),
      ).message,
      "We couldn't complete that request. Try again.",
    );
  });
}
