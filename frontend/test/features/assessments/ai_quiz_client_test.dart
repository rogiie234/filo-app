import 'dart:async';

import 'package:filo/features/assessments/data/ai_quiz_client.dart';
import 'package:filo/features/assessments/data/ai_quiz_response.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> validResult() => {
  'questions': [
    {
      'type': 'essay',
      'prompt': 'Explain the rule',
      'points': 10,
      'explanation': 'Explanation',
      'evidence': 'Source',
      'sample_answer': 'Example',
      'rubric': [
        {'key_point': 'Criterion', 'points': 10},
      ],
    },
  ],
  'missing_by_type': {for (final t in aiQuestionTypes) t: 0},
  'dropped_by_type': {for (final t in aiQuestionTypes) t: 0},
};
const ctx = AiSourceContext(
  sources: [SourcePrefix('att:one', 'lesson.txt', 4)],
  difficulty: 'hard',
  topicFocus: 'Focus',
);
final counts = {for (final t in aiQuestionTypes) t: t == 'essay' ? 1 : 0};
Future<AiGeneratedBatch> generate(
  AiQuizClient client, {
  AiCancelToken? token,
  String? type,
  List<String> prompts = const [],
}) => client.generate(
  classId: 'class',
  quizId: 'quiz',
  texts: [
    {'file_name': 'lesson.txt', 'text': 'Rule'},
  ],
  counts: counts,
  context: ctx,
  cancel: token ?? AiCancelToken(),
  regenerateType: type,
  currentPrompts: prompts,
);

void main() {
  test('one request uses public contract and SA points; no file bytes/context metadata sent', () async {
    final requests = <Map<String, dynamic>>[];
    final client = AiQuizClient(
      invoke: (r) async {
        requests.add(r);
        return validResult();
      },
      isOnline: () => true,
      currentUser: () => 'owner',
    );
    final result = await generate(client);
    expect(requests.length, 1);
    expect(requests.single['difficulty'], 'hard');
    expect(requests.single['topic_focus'], 'Focus');
    expect(requests.single.containsKey('source_key'), false);
    expect(result.questions.single.points, 5);
    expect(result.questions.single.aiGenerated, true);
  });
  for (final code in [
    'AI_BUSY',
    'AI_IN_PROGRESS',
    'AI_TIMEOUT',
    'AI_BAD_OUTPUT',
    'NO_TEXT',
    'TOO_LARGE',
    'NOT_ALLOWED',
    'INVALID_REQUEST',
    'AI_UNAVAILABLE',
  ]) {
    test('$code maps to friendly copy without raw data', () async {
      final client = AiQuizClient(
        invoke: (_) async => throw FunctionException(
          status: 503,
          details: {
            'error': {'code': code, 'message': 'PRIVATE_PAYLOAD'},
          },
        ),
        isOnline: () => true,
        currentUser: () => 'owner',
      );
      await expectLater(
        generate(client),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.message,
            'message',
            aiErrorMessages[code],
          ),
        ),
      );
      expect(aiErrorMessages[code], isNot(contains('PRIVATE_PAYLOAD')));
    });
  }
  test('offline/auth fail before invoking; unknown errors never show raw exception', () async {
    var calls = 0;
    for (final online in [false, true]) {
      final client = AiQuizClient(
        invoke: (_) async {
          calls++;
          throw StateError('SECRET');
        },
        isOnline: () => online,
        currentUser: () => null,
      );
      await expectLater(generate(client), throwsA(isA<AiFailure>()));
    }
    expect(calls, 0);
    final client = AiQuizClient(
      invoke: (_) async => throw StateError('SECRET'),
      isOnline: () => true,
      currentUser: () => 'owner',
    );
    await expectLater(
      generate(client),
      throwsA(isA<AiFailure>().having((e) => e.code, 'code', 'UNKNOWN')),
    );
  });
  test('cancel discards late result and never retries', () async {
    final response = Completer<dynamic>();
    var calls = 0;
    final client = AiQuizClient(
      invoke: (_) {
        calls++;
        return response.future;
      },
      isOnline: () => true,
      currentUser: () => 'owner',
    );
    final token = AiCancelToken();
    final request = generate(client, token: token);
    final expectation = expectLater(
      request,
      throwsA(isA<AiFailure>().having((e) => e.code, 'code', 'CANCELLED')),
    );
    token.cancel();
    await expectation;
    response.complete(validResult());
    expect(calls, 1);
  });
  test('deadline and account changes discard responses', () async {
    final delayed = Completer<dynamic>();
    final client = AiQuizClient(
      invoke: (_) => delayed.future,
      isOnline: () => true,
      currentUser: () => 'owner',
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      generate(client),
      throwsA(isA<AiFailure>().having((e) => e.code, 'code', 'AI_TIMEOUT')),
    );
    delayed.complete(validResult());
    var user = 'owner';
    final next = Completer<dynamic>();
    final other = AiQuizClient(
      invoke: (_) => next.future,
      isOnline: () => true,
      currentUser: () => user,
    );
    final request = generate(other);
    user = 'other';
    next.complete(validResult());
    await expectLater(
      request,
      throwsA(isA<AiFailure>().having((e) => e.code, 'code', 'AUTH')),
    );
  });
  test(
    'regeneration includes current prompts and refuses truncating their bounds',
    () async {
      Map<String, dynamic>? sent;
      final client = AiQuizClient(
        invoke: (r) async {
          sent = r;
          return validResult();
        },
        isOnline: () => true,
        currentUser: () => 'owner',
      );
      await generate(client, type: 'essay', prompts: ['Existing question']);
      expect(sent!['mode'], 'regenerate');
      expect(sent!['current_prompts'], ['Existing question']);
      await expectLater(
        generate(client, type: 'essay', prompts: List.filled(101, 'Question')),
        throwsA(
          isA<AiFailure>().having((e) => e.code, 'code', 'INVALID_REQUEST'),
        ),
      );
    },
  );
  test(
    'sequential request cap is Unicode-safe and reports zero contribution',
    () {
      AiSourceSelection source(String id, String text) =>
          AiSourceSelection(id: id, name: '$id.txt', size: 1)
            ..result = LessonText(text: text, sourceKey: 'att:$id');
      final result = allocateAiSources([
        source('a', '😀' * 39999),
        source('b', 'XY'),
        source('c', 'Z'),
      ]);
      expect(result.texts.length, 2);
      expect(result.texts[1]['text'], 'X');
      expect(result.prefixes.map((p) => p.characters), [39999, 1]);
      expect(result.warnings.last, contains('first 0 characters'));
      expect(
        () => allocateAiSources(List.generate(4, (i) => source('$i', 'Text'))),
        throwsFormatException,
      );
    },
  );
  test('an extraction error leaves other ready sources available', () {
    final good = AiSourceSelection(id: 'good', name: 'good.txt', size: 1)
      ..result = const LessonText(text: 'Rule', sourceKey: 'att:good');
    final bad = AiSourceSelection(id: 'bad', name: 'bad.pdf', size: 1)
      ..error = 'No readable text found in this file.';
    expect(allocateAiSources([bad, good]).texts.single['text'], 'Rule');
  });
}
