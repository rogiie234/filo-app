import 'dart:async';

import 'package:filo/core/ai/ai_cancellation.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/core/ai/ai_request_providers.dart';
import 'package:filo/features/assessments/data/ai_quiz_client.dart';
import 'package:filo/features/assessments/data/ai_quiz_response.dart'
    show aiQuestionTypes;
import 'package:filo/features/assessments/domain/ai_sources.dart'
    show AiSourceContext;
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _messages = [StudyChatInput(role: 'user', content: 'Question')];
const _deckSettings = StudyDeckSettings(count: 5, topicFocus: 'Topic');
const _quizSettings = StudyQuizSettings(
  count: 5,
  types: ['multiple_choice', 'true_false', 'identification'],
  topicFocus: 'Topic',
);
Map<String, dynamic> _answer({bool files = false}) => {
  'answer': 'Answer',
  'mode': files ? 'files' : 'general',
  'truncated': false,
};
Map<String, dynamic> _cards() => {
  'cards': [
    {'front': 'Front', 'back': 'Back'},
  ],
  'dropped': 2,
  'missing': 4,
};
Map<String, dynamic> _quiz() => {
  'questions': [
    {
      'type': 'multiple_choice',
      'prompt': 'Choose',
      'options': ['A', 'B', 'C', 'D'],
      'correct_index': 0,
      'explanation': 'Why',
    },
    {
      'type': 'true_false',
      'prompt': 'Statement',
      'correct_boolean': false,
      'explanation': 'Why',
    },
    {
      'type': 'identification',
      'prompt': 'Name',
      'accepted_answers': ['Answer', 'Variant'],
      'explanation': 'Why',
    },
  ],
  'dropped': 1,
  'missing': 2,
};
TypeMatcher<StudyAiFailure> _failure(String code) =>
    isA<StudyAiFailure>().having((e) => e.code, 'code', code);
Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late AiRequestGuard guard;
  setUp(() => guard = AiRequestGuard());
  tearDown(() => guard.close());
  StudentAiClient client({
    StudyAiInvoke? invoke,
    Future<List<StudyAiSource>> Function(String)? load,
    bool Function()? online,
    String? Function()? account,
    bool Function()? expired,
    Duration timeout = const Duration(seconds: 60),
  }) => StudentAiClient(
    invoke: invoke ?? ((_, _, _) async => _answer()),
    loadSources:
        load ??
        ((_) async => const [
          StudyAiSource(key: 'att:one', name: 'lesson.txt', text: 'Rule'),
        ]),
    isOnline: online ?? (() => true),
    currentAccount: account ?? (() => 'account:session'),
    sessionExpired: expired,
    guard: guard,
    timeout: timeout,
  );

  test('messages keep last ten in order, trim whitespace and count Unicode code points', () {
    final input = List.generate(
      12,
      (i) =>
          StudyChatInput(role: i.isEven ? 'user' : 'assistant', content: '$i'),
    );
    final output = prepareStudyMessages(input);
    expect(
      output.map((m) => m['content']),
      List.generate(10, (i) => '${i + 2}'),
    );
    final long = prepareStudyMessages([
      StudyChatInput(role: 'user', content: '  ${'😀' * 2001}  '),
    ]).single['content']!;
    expect(long.runes.length, 2000);
    expect(long, '😀' * 2000);
    expect(input.length, 12);
    expect(
      () => prepareStudyMessages(const [
        StudyChatInput(role: 'system', content: 'Text'),
      ]),
      throwsA(_failure('INVALID_REQUEST')),
    );
    expect(
      () => prepareStudyMessages(const [
        StudyChatInput(role: 'user', content: '  '),
      ]),
      throwsA(_failure('INVALID_REQUEST')),
    );
  });

  test(
    'single-source boundary preserves cache input and sets true cut flag',
    () {
      for (final size in [39999, 40000, 40001]) {
        final source = StudyAiSource(
          key: 'att:one',
          name: 'lesson.txt',
          text: '😀' * size,
        );
        final prepared = prepareStudySources([source]);
        expect(
          prepared.sources.single['text']!.runes.length,
          size > 40000 ? 40000 : size,
        );
        expect(prepared.truncated, size > 40000);
        expect(prepared.usage.single.originalCharacters, size);
        expect(
          prepared.usage.single.retainedCharacters,
          size > 40000 ? 40000 : size,
        );
        expect(source.text.runes.length, size);
      }
    },
  );

  test(
    'multi-source cap keeps every source and redistributes short-source space',
    () {
      final result = prepareStudySources([
        StudyAiSource(key: 'att:a', name: 'a', text: 'A' * 50000),
        const StudyAiSource(key: 'att:b', name: 'b', text: 'Short'),
        StudyAiSource(key: 'att:c', name: 'c', text: '😀' * 50000),
      ]);
      expect(result.sources.length, 3);
      expect(result.usage.map((s) => s.retainedCharacters), [19998, 5, 19997]);
      expect(
        result.usage.fold<int>(0, (n, s) => n + s.retainedCharacters),
        40000,
      );
      expect(result.truncated, isTrue);
      expect(result.usage[1].truncated, isFalse);
      expect(
        result.sources.every(
          (s) => s.keys.toSet().difference({'name', 'text'}).isEmpty,
        ),
        isTrue,
      );
      expect(prepareStudySources(const []).truncated, isFalse);
    },
  );

  test(
    'unreadable selection never disappears or becomes general knowledge',
    () async {
      var calls = 0;
      final api = client(
        invoke: (_, _, _) async {
          calls++;
          return _answer();
        },
        load: (_) async => const [
          StudyAiSource(key: 'att:a', name: 'a', text: 'Readable'),
          StudyAiSource(key: 'att:b', name: 'b', text: '  '),
        ],
      );
      await expectLater(
        api.flashcards(
          notebookId: 'notebook',
          settings: _deckSettings,
          cancel: AiCancelToken(),
        ),
        throwsA(_failure('NO_TEXT')),
      );
      expect(calls, 0);
      expect(
        () => prepareStudySources(
          List.generate(
            4,
            (i) => StudyAiSource(key: '$i', name: '$i', text: 'Text'),
          ),
        ),
        throwsA(_failure('TOO_LARGE')),
      );
    },
  );

  test('four methods use exact endpoint bodies and typed repository-compatible results', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final api = client(
      invoke: (function, body, _) async {
        calls.add((function, body));
        return switch (function) {
          'ai-flashcards' => _cards(),
          'ai-mock-quiz' => _quiz(),
          _ => _answer(files: (body['sources'] as List).isNotEmpty),
        };
      },
    );
    final chat = await api.chat(messages: _messages, cancel: AiCancelToken());
    final summary = await api.summary(
      notebookId: 'notebook',
      cancel: AiCancelToken(),
    );
    final cards = await api.flashcards(
      settings: _deckSettings,
      cancel: AiCancelToken(),
    );
    final quiz = await api.practiceQuiz(
      notebookId: 'notebook',
      settings: _quizSettings,
      cancel: AiCancelToken(),
    );
    expect(calls.map((c) => c.$1), [
      'ai-chat',
      'ai-chat',
      'ai-flashcards',
      'ai-mock-quiz',
    ]);
    expect(calls[0].$2, {
      'mode': 'chat',
      'messages': [
        {'role': 'user', 'content': 'Question'},
      ],
      'sources': [],
    });
    expect(calls[1].$2, {
      'mode': 'summary',
      'messages': [],
      'sources': [
        {'name': 'lesson.txt', 'text': 'Rule'},
      ],
    });
    expect(calls[2].$2, {'sources': [], 'count': 5, 'topic_focus': 'Topic'});
    expect(calls[3].$2['types'], _quizSettings.types);
    expect(chat.value.mode, 'general');
    expect(summary.value.mode, 'files');
    expect(cards.value.items.single.front, 'Front');
    expect(cards.value.dropped, 2);
    expect(cards.value.missing, 4);
    expect(quiz.value.items.map((q) => q.type), _quizSettings.types);
    expect(quiz.value.items[1].correctBoolean, isFalse);
    expect(quiz.value.items[2].acceptedAnswers, ['Answer', 'Variant']);
    expect(quiz.value.missing, 2);
  });

  test(
    'long source is clipped on wire and flag survives server truncated:false',
    () async {
      Map<String, dynamic>? sent;
      final api = client(
        load: (_) async => [
          StudyAiSource(key: 'att:long', name: 'long.txt', text: '😀' * 40001),
        ],
        invoke: (_, body, _) async {
          sent = body;
          return _answer(files: true);
        },
      );
      final result = await api.summary(
        notebookId: 'notebook',
        cancel: AiCancelToken(),
      );
      expect(
        ((sent!['sources'] as List).single['text'] as String).runes.length,
        40000,
      );
      expect(result.serverTruncated, isFalse);
      expect(result.truncated, isTrue);
      expect(result.sources.usage.single.retainedCharacters, 40000);
    },
  );

  const expectedMessages = {
    'NOT_ALLOWED': "You can't use this study action right now.",
    'INVALID_REQUEST': 'Check your study settings and try again.',
    'NO_TEXT': 'No readable text found in this file.',
    'TOO_LARGE':
        'The request is too large. Use less source text and try again.',
    'AI_IN_PROGRESS':
        'Your last request is still being processed. Try again in a minute.',
    'AI_BUSY': 'The AI assistant is busy right now. Your work is saved. Please try again in a few minutes, or create questions manually.',
    'AI_TIMEOUT': 'The AI request timed out. Please try again.',
    'AI_BAD_OUTPUT':
        'The AI could not prepare this study material. Please try again.',
    'AI_UNAVAILABLE':
        'The AI assistant is unavailable. Please try again later.',
    'AI_BLOCKED': "The AI couldn't respond to this request. Try changing your question or source text.",
  };
  for (final entry in expectedMessages.entries) {
    test(
      '${entry.key} maps safely through thrown and returned envelopes',
      () async {
        for (final throws in [true, false]) {
          final envelope = {
            'error': {'code': entry.key, 'message': 'PRIVATE_RAW_ERROR'},
          };
          final api = client(
            invoke: (_, _, _) async {
              if (throws) {
                throw FunctionException(status: 503, details: envelope);
              }
              return envelope;
            },
          );
          try {
            await api.flashcards(
              settings: _deckSettings,
              cancel: AiCancelToken(),
            );
            fail('Expected a typed failure');
          } on StudyAiFailure catch (e) {
            expect(e.code, entry.key);
            expect(e.message, entry.value);
            expect(e.toString(), isNot(contains('PRIVATE_RAW_ERROR')));
          }
          expect(guard.isBusy, isFalse);
        }
      },
    );
  }

  test(
    'offline, denied and confirmed expired sessions fail before network',
    () async {
      var calls = 0;
      Future<dynamic> invoke(
        String _,
        Map<String, dynamic> _,
        Future<void> _,
      ) async {
        calls++;
        return _answer();
      }

      final offline = client(online: () => false, invoke: invoke);
      await expectLater(
        offline.chat(messages: _messages, cancel: AiCancelToken()),
        throwsA(_failure('OFFLINE')),
      );
      final denied = client(account: () => null, invoke: invoke);
      await expectLater(
        denied.chat(messages: _messages, cancel: AiCancelToken()),
        throwsA(_failure('NOT_ALLOWED')),
      );
      final expired = client(expired: () => true, invoke: invoke);
      await expectLater(
        expired.chat(messages: _messages, cancel: AiCancelToken()),
        throwsA(_failure('AUTH')),
      );
      expect(calls, 0);
      final bare401 = client(
        invoke: (_, _, _) async =>
            throw FunctionException(status: 401, details: 'PRIVATE'),
      );
      await expectLater(
        bare401.flashcards(settings: _deckSettings, cancel: AiCancelToken()),
        throwsA(_failure('UNKNOWN')),
      );
      expect(
        studyAiFriendlyError(StateError('PRIVATE')),
        studyAiMessages['UNKNOWN'],
      );
    },
  );

  test(
    'missing inputs and invalid settings fail safely without invoking',
    () async {
      var calls = 0;
      final api = client(
        invoke: (_, _, _) async {
          calls++;
          return _answer();
        },
        load: (_) async => [],
      );
      await expectLater(
        api.chat(
          messages: const [
            StudyChatInput(role: 'assistant', content: 'Answer'),
          ],
          cancel: AiCancelToken(),
        ),
        throwsA(_failure('INVALID_REQUEST')),
      );
      await expectLater(
        api.summary(notebookId: 'empty', cancel: AiCancelToken()),
        throwsA(_failure('NO_TEXT')),
      );
      await expectLater(
        api.flashcards(
          settings: const StudyDeckSettings(count: 4),
          cancel: AiCancelToken(),
        ),
        throwsA(_failure('INVALID_REQUEST')),
      );
      await expectLater(
        api.practiceQuiz(
          settings: const StudyQuizSettings(count: 5, types: ['essay']),
          cancel: AiCancelToken(),
        ),
        throwsA(_failure('INVALID_REQUEST')),
      );
      await expectLater(
        api.flashcards(
          settings: const StudyDeckSettings(count: 5),
          cancel: AiCancelToken(),
        ),
        throwsA(_failure('NO_TEXT')),
      );
      expect(calls, 0);
      final badCache = client(
        load: (_) async => throw StateError('PRIVATE_DATABASE'),
      );
      await expectLater(
        badCache.summary(notebookId: 'notebook', cancel: AiCancelToken()),
        throwsA(_failure('LOAD_FAILED')),
      );
    },
  );

  test(
    'unknown transport/errors and pre-cancelled input never expose diagnostics',
    () async {
      for (final error in [
        StateError('PRIVATE_RAW'),
        const FunctionException(
          status: 500,
          details: {
            'error': {'code': 'PRIVATE_UNKNOWN', 'message': 'PRIVATE_RAW'},
          },
        ),
      ]) {
        final api = client(invoke: (_, _, _) async => throw error);
        await expectLater(
          api.flashcards(settings: _deckSettings, cancel: AiCancelToken()),
          throwsA(_failure('UNKNOWN')),
        );
      }
      var calls = 0;
      final api = client(
        invoke: (_, _, _) async {
          calls++;
          return _cards();
        },
      );
      final cancel = AiCancelToken()..cancel();
      await expectLater(
        api.flashcards(settings: _deckSettings, cancel: cancel),
        throwsA(_failure('CANCELLED')),
      );
      expect(calls, 0);
      expect(guard.isBusy, isFalse);
    },
  );

  test(
    'connectivity and account are checked again before and after transport',
    () async {
      var online = true, calls = 0;
      final loading = Completer<List<StudyAiSource>>();
      final api = client(
        online: () => online,
        load: (_) => loading.future,
        invoke: (_, _, _) async {
          calls++;
          return _answer(files: true);
        },
      );
      final pending = api.summary(
        notebookId: 'notebook',
        cancel: AiCancelToken(),
      );
      final offline = expectLater(pending, throwsA(_failure('OFFLINE')));
      online = false;
      loading.complete(const [
        StudyAiSource(key: 'att:a', name: 'a', text: 'Text'),
      ]);
      await offline;
      expect(calls, 0);
      var identity = 'a';
      final reply = Completer<dynamic>();
      final switched = client(
        account: () => identity,
        invoke: (_, _, _) => reply.future,
      );
      final request = switched.flashcards(
        settings: _deckSettings,
        cancel: AiCancelToken(),
      );
      final denied = expectLater(request, throwsA(_failure('CANCELLED')));
      identity = 'b';
      reply.complete(_cards());
      await denied;
    },
  );

  test('malformed successful responses are rejected rather than partially rendered', () {
    for (final malformed in [
      null,
      [],
      {'answer': '', 'mode': 'general', 'truncated': false},
      {'answer': 'Text', 'mode': 'files', 'truncated': false},
      {'answer': 'Text', 'mode': 'general', 'truncated': 'false'},
    ]) {
      expect(
        () => decodeStudyText(malformed, false),
        throwsA(_failure('AI_BAD_OUTPUT')),
      );
    }
    for (final malformed in [
      {'cards': [], 'dropped': 0, 'missing': 5},
      {
        'cards': [
          {'front': 'Front', 'back': 'Back'},
        ],
        'dropped': -1,
        'missing': 4,
      },
      {
        'cards': [
          {'front': 'Front', 'back': 'Back', 'unexpected': true},
        ],
        'dropped': 0,
        'missing': 4,
      },
      {
        'cards': [
          {'front': 'Front', 'back': 'Back'},
        ],
        'dropped': 0,
        'missing': 0,
      },
    ]) {
      expect(
        () => decodeStudyCards(malformed, 5),
        throwsA(_failure('AI_BAD_OUTPUT')),
      );
    }
    final malformedQuiz = _quiz();
    ((malformedQuiz['questions'] as List)[1] as Map)['correct_boolean'] =
        'false';
    expect(
      () => decodeStudyQuestions(malformedQuiz, _quizSettings),
      throwsA(_failure('AI_BAD_OUTPUT')),
    );
  });

  test('cancellation aborts transport, drops late result, clears busy and never retries', () async {
    final reply = Completer<dynamic>(), aborted = Completer<void>();
    var calls = 0;
    final api = client(
      invoke: (_, _, abort) {
        calls++;
        unawaited(abort.then((_) => aborted.complete()));
        return reply.future;
      },
    );
    final cancel = AiCancelToken();
    final pending = api.flashcards(settings: _deckSettings, cancel: cancel);
    final check = expectLater(pending, throwsA(_failure('CANCELLED')));
    expect(guard.isBusy, isTrue);
    cancel.cancel();
    await check;
    await aborted.future;
    expect(guard.isBusy, isFalse);
    reply.complete(_cards());
    await _tick();
    expect(calls, 1);
  });

  test(
    'deadline aborts transport and keeps truncation metadata on failure',
    () async {
      final reply = Completer<dynamic>(), aborted = Completer<void>();
      final api = client(
        timeout: const Duration(milliseconds: 100),
        load: (_) async => [
          StudyAiSource(key: 'att:a', name: 'a', text: 'x' * 40001),
        ],
        invoke: (_, _, abort) {
          unawaited(abort.then((_) => aborted.complete()));
          return reply.future;
        },
      );
      await expectLater(
        api.flashcards(
          notebookId: 'notebook',
          settings: _deckSettings,
          cancel: AiCancelToken(),
        ),
        throwsA(
          _failure('AI_TIMEOUT').having(
            (StudyAiFailure e) => e.sources?.truncated,
            'truncated',
            true,
          ),
        ),
      );
      await aborted.future;
      expect(guard.isBusy, isFalse);
      reply.complete(_cards());
    },
  );

  test('chat waits three seconds from dispatch and cancellation prevents queued send', () async {
    await guard.close();
    var elapsed = Duration.zero;
    final sleeping = Completer<void>();
    Duration? delay;
    guard = AiRequestGuard(
      elapsed: () => elapsed,
      sleep: (d) {
        delay = d;
        return sleeping.future;
      },
    );
    var calls = 0;
    final api = client(
      invoke: (_, _, _) async {
        calls++;
        return _answer();
      },
    );
    await api.chat(messages: _messages, cancel: AiCancelToken());
    elapsed = const Duration(seconds: 1);
    final cancel = AiCancelToken();
    final pending = api.chat(messages: _messages, cancel: cancel);
    final check = expectLater(pending, throwsA(_failure('CANCELLED')));
    await _tick();
    expect(delay, const Duration(seconds: 2));
    expect(guard.isBusy, isTrue);
    expect(calls, 1);
    cancel.cancel();
    await check;
    sleeping.complete();
    await _tick();
    expect(calls, 1);
    elapsed = const Duration(seconds: 3);
    await api.chat(messages: _messages, cancel: AiCancelToken());
    expect(calls, 2);
  });

  test(
    'account change during source loading cannot send another accounts text',
    () async {
      var account = 'a:session', calls = 0;
      final sources = Completer<List<StudyAiSource>>();
      final api = client(
        account: () => account,
        load: (_) => sources.future,
        invoke: (_, _, _) async {
          calls++;
          return _answer(files: true);
        },
      );
      final pending = api.summary(
        notebookId: 'notebook',
        cancel: AiCancelToken(),
      );
      final check = expectLater(pending, throwsA(_failure('CANCELLED')));
      account = 'b:session';
      sources.complete(const [
        StudyAiSource(key: 'att:a', name: 'a', text: 'Text'),
      ]);
      await check;
      expect(calls, 0);
    },
  );

  test('account/disposal cancellation aborts active work and late success is ignored', () async {
    final reply = Completer<dynamic>();
    final api = client(invoke: (_, _, _) => reply.future);
    final pending = api.flashcards(
      settings: _deckSettings,
      cancel: AiCancelToken(),
    );
    final check = expectLater(pending, throwsA(_failure('CANCELLED')));
    api.cancelActive();
    await check;
    reply.complete(_cards());
    expect(guard.isBusy, isFalse);
  });

  test('student and instructor share one guard in both directions', () async {
    final instructorReply = Completer<dynamic>();
    final instructor = AiQuizClient(
      guard: guard,
      invoke: (_) => instructorReply.future,
      isOnline: () => true,
      currentUser: () => 'instructor',
    );
    Future<dynamic> generate(AiCancelToken cancel) => instructor.generate(
      classId: 'class',
      quizId: 'quiz',
      texts: [
        {'file_name': 'lesson.txt', 'text': 'Rule'},
      ],
      counts: {
        for (final type in aiQuestionTypes)
          type: type == 'multiple_choice' ? 1 : 0,
      },
      context: const AiSourceContext(sources: [], difficulty: 'easy'),
      cancel: cancel,
    );
    final cancelInstructor = AiCancelToken();
    final pending = generate(cancelInstructor);
    final check = expectLater(
      pending,
      throwsA(isA<AiFailure>().having((e) => e.code, 'code', 'CANCELLED')),
    );
    final studentReply = Completer<dynamic>();
    final student = client(invoke: (_, _, _) => studentReply.future);
    await expectLater(
      student.flashcards(settings: _deckSettings, cancel: AiCancelToken()),
      throwsA(_failure('AI_IN_PROGRESS')),
    );
    cancelInstructor.cancel();
    await check;
    instructorReply.complete({});
    final studentPending = student.flashcards(
      settings: _deckSettings,
      cancel: AiCancelToken(),
    );
    await expectLater(
      generate(AiCancelToken()),
      throwsA(isA<AiFailure>().having((e) => e.code, 'code', 'AI_IN_PROGRESS')),
    );
    studentReply.complete(_cards());
    await studentPending;
  });

  test('Riverpod exposes phone-wide busy changes including recovery', () async {
    final container = ProviderContainer(
      overrides: [aiRequestGuardProvider.overrideWithValue(guard)],
    );
    addTearDown(container.dispose);
    final states = <bool>[];
    container.listen(aiRequestBusyProvider, (_, next) {
      if (next.hasValue) states.add(next.value!);
    }, fireImmediately: true);
    await container.read(aiRequestBusyProvider.future);
    final reply = Completer<dynamic>();
    final pending = client(invoke: (_, _, _) => reply.future)
        .flashcards(settings: _deckSettings, cancel: AiCancelToken());
    await _tick();
    reply.complete(_cards());
    await pending;
    await _tick();
    expect(states, containsAllInOrder([false, true, false]));
  });
}
