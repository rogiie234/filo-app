import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/core/ai/ai_cancellation.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/study/application/study_quiz_sessions.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

const quizSettings = StudyQuizSettings(
  count: 5,
  types: ['multiple_choice', 'true_false', 'identification'],
  topicFocus: 'Cells',
);
const quizInputs = [
  StudyQuestionInput(
    type: 'multiple_choice',
    prompt: 'Choose B',
    options: ['A', 'B', 'C', 'D'],
    correctIndex: 1,
    explanation: 'B is the answer.',
  ),
  StudyQuestionInput(
    type: 'true_false',
    prompt: 'This is true',
    correctBoolean: true,
    explanation: 'True is the answer.',
  ),
  StudyQuestionInput(
    type: 'identification',
    prompt: 'Name the cell',
    acceptedAnswers: ['Red blood cell', 'Erythrocyte'],
    explanation: 'Either name is accepted.',
  ),
];

class AttemptFixture extends StudyAttemptRepository {
  AttemptFixture(super.db);
  bool fail = false, failAfterCommit = false;
  @override
  Future<String> save(
    String quizId,
    List<StudyQuestionResult> results, {
    String? attemptId,
    bool Function()? canCommit,
  }) async {
    if (fail) throw StateError('Synthetic private save error');
    final id = await super.save(
      quizId,
      results,
      attemptId: attemptId,
      canCommit: canCommit,
    );
    if (failAfterCommit) throw StateError('Synthetic acknowledgement error');
    return id;
  }
}

class QuizFixture extends StudyQuizRepository {
  QuizFixture(super.db);
  bool failAfterCommit = false;
  @override
  Future<String> create({
    required String notebookId,
    required String title,
    required StudyQuizSettings settings,
    required List<StudyQuestionInput> questions,
    String? quizId,
    bool Function()? canCommit,
  }) async {
    final id = await super.create(
      notebookId: notebookId,
      title: title,
      settings: settings,
      questions: questions,
      quizId: quizId,
      canCommit: canCommit,
    );
    if (failAfterCommit) throw StateError('Synthetic acknowledgement error');
    return id;
  }
}

void main() {
  late AppDatabase db;
  late String notebook;
  late QuizFixture quizzes;
  late AttemptFixture attempts;
  late AiRequestGuard guard;
  late StudentAiClient client;
  late StudyQuizGeneration generation;
  var current = true, online = true, calls = 0;
  late StudyAiInvoke invoke;
  List<StudyAiSource> sources = [];
  Map<String, dynamic> output() => {
    'questions': [
      {
        'type': 'multiple_choice',
        'prompt': 'Choose B',
        'options': ['A', 'B', 'C', 'D'],
        'correct_index': 1,
        'explanation': 'B is the answer.',
      },
      {
        'type': 'true_false',
        'prompt': 'This is true',
        'correct_boolean': true,
        'explanation': 'True is the answer.',
      },
      {
        'type': 'identification',
        'prompt': 'Name the cell',
        'accepted_answers': ['Red blood cell'],
        'explanation': 'Name accepted.',
      },
    ],
    'dropped': 1,
    'missing': 2,
  };
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notebook = await NotebookRepository(db).create('Quiz notebook');
    quizzes = QuizFixture(db);
    attempts = AttemptFixture(db);
    guard = AiRequestGuard();
    current = online = true;
    calls = 0;
    sources = [];
    invoke = (_, _, _) async => output();
    client = StudentAiClient(
      invoke: (function, body, abort) {
        expect(function, 'ai-mock-quiz');
        calls++;
        return invoke(function, body, abort);
      },
      loadSources: (_) async => sources,
      isOnline: () => online,
      currentAccount: () => current ? 'student' : 'other',
      guard: guard,
    );
    generation = StudyQuizGeneration(
      notebookId: notebook,
      repository: quizzes,
      client: client,
      isCurrent: () => current,
      isOnline: () => online,
    );
  });
  tearDown(() async {
    generation.dispose();
    await guard.close();
    await db.close();
  });
  Future<StudyQuizSession> session() async {
    final id = await quizzes.create(
      notebookId: notebook,
      title: 'Saved quiz',
      settings: quizSettings,
      questions: quizInputs,
    );
    final s = StudyQuizSession(
      notebookId: notebook,
      quizId: id,
      repository: attempts,
      isCurrent: () => current,
      random: Random(7),
    );
    addTearDown(s.dispose);
    await s.open();
    return s;
  }

  Future<void> finish(StudyQuizSession s) async {
    for (final answer in [1, true, '  RED   blood  CELL ']) {
      s.select(answer);
      s.check();
      await s.next();
    }
  }

  test('grades each type, locks Check, persists only complete attempts and retakes with original keys', () async {
    final s = await session();
    s.select(1);
    s.check();
    s.check();
    s.select(0);
    expect(s.results.length, 1);
    expect(s.answer, 1);
    expect(await db.select(db.practiceAttempts).get(), isEmpty);
    await s.next();
    s.select(false);
    s.check();
    await s.next();
    s.select('  ERYTHROCYTE ');
    s.check();
    await s.next();
    expect(s.score, 2);
    expect(s.complete, isTrue);
    final saved = (await db.select(db.practiceAttempts).get()).single;
    expect(saved.score, 2);
    expect(saved.total, 3);
    s.retake();
    expect(s.results, isEmpty);
    expect(s.savedId, isNull);
    expect(s.optionOrder[s.questions.first.id], unorderedEquals([0, 1, 2, 3]));
    await finish(s);
    expect(s.score, 3);
    expect(await db.select(db.practiceAttempts).get(), hasLength(2));
  });
  test(
    'identification normalizes whitespace and case without fuzzy matching',
    () async {
      final s = await session();
      final q = s.questions.last;
      expect(gradeStudyAnswer(q, ' Red \n blood\tcell '), isTrue);
      expect(gradeStudyAnswer(q, 'red blood cells'), isFalse);
      expect(gradeStudyAnswer(q, '   '), isFalse);
    },
  );
  test(
    'save-only retry reconciles committed attempt without duplicates',
    () async {
      final s = await session();
      attempts.failAfterCommit = true;
      await finish(s);
      expect(s.savedId, isNull);
      expect(s.error, isNotNull);
      s.retake();
      expect(s.complete, isTrue);
      attempts.failAfterCommit = false;
      await s.save();
      expect(s.savedId, isNotNull);
      expect(await db.select(db.practiceAttempts).get(), hasLength(1));
    },
  );
  test('failed save retains results; account change prevents writes', () async {
    final s = await session();
    attempts.fail = true;
    await finish(s);
    expect(s.results, hasLength(3));
    expect(await db.select(db.practiceAttempts).get(), isEmpty);
    attempts.fail = false;
    current = false;
    await s.save();
    expect(await db.select(db.practiceAttempts).get(), isEmpty);
  });
  test(
    'incomplete attempt disappears on reopening; deletion cascades history',
    () async {
      final s = await session();
      s.select(1);
      s.check();
      await s.open();
      expect(s.results, isEmpty);
      await finish(s);
      await quizzes.delete(s.quizId);
      expect(await db.select(db.practiceAttempts).get(), isEmpty);
      expect(await db.select(db.practiceQuestions).get(), isEmpty);
    },
  );
  test('generation preserves partial counts and stable save retry', () async {
    quizzes.failAfterCommit = true;
    await generation.generate(quizSettings);
    expect(generation.hasUnsaved, isTrue);
    expect(generation.result!.value.dropped, 1);
    expect(generation.result!.value.missing, 2);
    quizzes.failAfterCommit = false;
    await generation.retrySave();
    expect(generation.savedId, isNotNull);
    expect(calls, 1);
    expect(await db.select(db.practiceQuizzes).get(), hasLength(1));
  });
  test(
    'invalid setup, no topic, offline and shared busy block generation',
    () async {
      await generation.generate(const StudyQuizSettings(count: 7, types: []));
      expect(calls, 0);
      await generation.generate(
        const StudyQuizSettings(count: 5, types: ['true_false']),
      );
      expect(generation.error, studyAiMessages['NO_TEXT']);
      online = false;
      await generation.generate(quizSettings);
      expect(generation.error, studyAiMessages['OFFLINE']);
      online = true;
      final pending = Completer<void>();
      final held = guard.run(AiCancelToken(), (_) => pending.future);
      await generation.generate(quizSettings);
      expect(generation.error, studyAiMessages['AI_IN_PROGRESS']);
      pending.complete();
      await held;
    },
  );
  test('busy uses approved neutral message', () async {
    invoke = (_, _, _) async => throw const StudyAiFailure('AI_BUSY');
    await generation.generate(quizSettings);
    expect(generation.error, studyQuizBusyMessage);
  });
  test('cancel and account change ignore late output', () async {
    final pending = Completer<Object?>();
    invoke = (_, _, _) => pending.future;
    final waiting = generation.generate(quizSettings);
    await Future<void>.delayed(Duration.zero);
    generation.cancel();
    pending.complete(output());
    await waiting;
    expect(await db.select(db.practiceQuizzes).get(), isEmpty);
    expect(guard.isBusy, isFalse);
    current = false;
    await generation.generate(quizSettings);
    expect(calls, 1);
  });
  test(
    'long source retains confirmed cut metadata and quizzes work offline',
    () async {
      sources = [
        StudyAiSource(key: 'source', name: 'Source', text: 'x' * 40001),
      ];
      await generation.generate(quizSettings);
      expect(generation.result!.sources.truncated, isTrue);
      online = false;
      final s = await session();
      await finish(s);
      expect(s.savedId, isNotNull);
    },
  );
  test(
    'stable IDs reject mismatching data and stale transaction rolls back',
    () async {
      await quizzes.create(
        notebookId: notebook,
        title: 'Quiz',
        settings: quizSettings,
        questions: quizInputs,
        quizId: 'stable',
      );
      await expectLater(
        quizzes.create(
          notebookId: notebook,
          title: 'Different',
          settings: quizSettings,
          questions: quizInputs,
          quizId: 'stable',
        ),
        throwsStateError,
      );
      await expectLater(
        quizzes.create(
          notebookId: notebook,
          title: 'Stale',
          settings: quizSettings,
          questions: quizInputs,
          canCommit: () => false,
        ),
        throwsStateError,
      );
      expect(await db.select(db.practiceQuizzes).get(), hasLength(1));
    },
  );
  test('all server errors stay friendly', () async {
    for (final code in [
      'NOT_ALLOWED',
      'INVALID_REQUEST',
      'NO_TEXT',
      'TOO_LARGE',
      'AI_IN_PROGRESS',
      'AI_TIMEOUT',
      'AI_BAD_OUTPUT',
      'AI_UNAVAILABLE',
      'AI_BLOCKED',
    ]) {
      invoke = (_, _, _) async => throw StudyAiFailure(code);
      await generation.generate(quizSettings);
      expect(generation.error, studyAiMessages[code]);
    }
    expect(await db.select(db.practiceQuizzes).get(), isEmpty);
  });
  test(
    'ten quiz limit retains pending result and capacity can be reused',
    () async {
      for (var i = 0; i < 10; i++) {
        await quizzes.create(
          notebookId: notebook,
          title: 'Quiz $i',
          settings: quizSettings,
          questions: quizInputs,
        );
      }
      await generation.generate(quizSettings);
      expect(generation.error, studyQuizLimitMessage);
      expect(generation.hasUnsaved, isTrue);
      final first = (await db.select(db.practiceQuizzes).get()).first;
      await quizzes.delete(first.id);
      await generation.retrySave();
      expect(generation.savedId, isNotNull);
      expect(calls, 1);
    },
  );
  test('account change during generation drops the response', () async {
    final response = Completer<dynamic>(), started = Completer<void>();
    invoke = (_, _, _) {
      started.complete();
      return response.future;
    };
    final waiting = generation.generate(quizSettings);
    await started.future;
    current = false;
    response.complete(output());
    await waiting;
    expect(await db.select(db.practiceQuizzes).get(), isEmpty);
  });
}
