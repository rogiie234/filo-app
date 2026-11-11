import 'dart:async';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_cancellation.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/study/application/study_flashcard_sessions.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

const _settings = StudyDeckSettings(count: 5, topicFocus: 'Cells');
const _cards = [
  StudyCardInput(front: 'Question A', back: 'Answer A'),
  StudyCardInput(front: 'Question B', back: 'Answer B'),
  StudyCardInput(front: 'Question C', back: 'Answer C'),
];

class DeckRepositoryFixture extends StudyDeckRepository {
  DeckRepositoryFixture(super.db);
  bool failCreate = false, failAfterCommit = false, failStatus = false;
  Completer<void>? statusGate;
  @override
  Future<String> create({
    required String notebookId,
    required String title,
    required StudyDeckSettings settings,
    required List<StudyCardInput> cards,
    String? deckId,
    bool Function()? canCommit,
  }) async {
    if (failCreate) throw StateError('Private synthetic failure');
    final id = await super.create(
      notebookId: notebookId,
      title: title,
      settings: settings,
      cards: cards,
      deckId: deckId,
      canCommit: canCommit,
    );
    if (failAfterCommit) throw StateError('Synthetic acknowledgement failure');
    return id;
  }

  @override
  Future<int> setCardStatus(
    String id,
    String status, {
    String? deckId,
    bool Function()? canCommit,
  }) async {
    await statusGate?.future;
    if (failStatus) throw StateError('Private synthetic failure');
    return super.setCardStatus(
      id,
      status,
      deckId: deckId,
      canCommit: canCommit,
    );
  }
}

void main() {
  late AppDatabase db;
  late DeckRepositoryFixture repo;
  late AiRequestGuard guard;
  late StudentAiClient client;
  late StudyDeckGeneration generation;
  late String notebook;
  late StudyAiInvoke invoke;
  var online = true, current = true, calls = 0;
  List<StudyAiSource> sources = [];
  Map<String, dynamic>? submitted;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DeckRepositoryFixture(db);
    notebook = await NotebookRepository(db).create('Flashcards');
    guard = AiRequestGuard();
    online = current = true;
    calls = 0;
    sources = [];
    submitted = null;
    invoke = (_, body, _) async => {
      'cards': [
        for (final c in _cards) {'front': c.front, 'back': c.back},
      ],
      'dropped': 1,
      'missing': (body['count'] as int) - _cards.length,
    };
    client = StudentAiClient(
      invoke: (function, body, abort) {
        expect(function, 'ai-flashcards');
        calls++;
        submitted = body;
        return invoke(function, body, abort);
      },
      loadSources: (_) async => sources,
      isOnline: () => online,
      currentAccount: () => current ? 'owner' : 'other',
      guard: guard,
    );
    generation = StudyDeckGeneration(
      notebookId: notebook,
      repository: repo,
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
  Future<String> deck() => repo.create(
    notebookId: notebook,
    title: 'Saved deck',
    settings: _settings,
    cards: _cards,
  );
  StudyFlashcardSession study(String id) {
    final session = StudyFlashcardSession(
      notebookId: notebook,
      deckId: id,
      repository: repo,
      isCurrent: () => current,
      random: Random(7),
    );
    addTearDown(session.dispose);
    return session;
  }

  Future<List<StudyCard>> savedCards(String id) =>
      (db.select(db.flashcards)..where((c) => c.deckId.equals(id))).get();

  test('partial deck saves atomically with topic title/settings and actual reported counts', () async {
    await generation.generate(_settings);
    expect(generation.savedId, isNotNull);
    expect(generation.result!.value.dropped, 1);
    expect(generation.result!.value.missing, 2);
    final row = (await db.select(db.flashcardDecks).get()).single;
    expect(row.title, 'Cells');
    expect(row.settings, contains('"count":5'));
    expect(await savedCards(row.id), hasLength(3));
    expect((await savedCards(row.id)).every((c) => c.status == 'new'), isTrue);
    expect(submitted!['topic_focus'], 'Cells');
  });

  test(
    'source-free topic required, count bounds and Unicode topic limit',
    () async {
      for (final settings in [
        const StudyDeckSettings(count: 4),
        const StudyDeckSettings(count: 31),
        StudyDeckSettings(count: 5, topicFocus: List.filled(201, '😀').join()),
      ]) {
        await generation.generate(settings);
        expect(generation.error, studyAiMessages['INVALID_REQUEST']);
      }
      await generation.generate(const StudyDeckSettings(count: 10));
      expect(generation.error, studyAiMessages['NO_TEXT']);
      expect(calls, 0);
      await generation.generate(
        StudyDeckSettings(count: 30, topicFocus: List.filled(200, '😀').join()),
      );
      expect(calls, 1);
      expect(generation.savedId, isNotNull);
    },
  );

  test('source generation uses default title and actual Unicode truncation metadata', () async {
    sources = [
      StudyAiSource(
        key: 'att:a',
        name: 'Long.txt',
        text: List.filled(40001, '😀').join(),
      ),
    ];
    await generation.generate(const StudyDeckSettings(count: 10));
    expect(
      (await db.select(db.flashcardDecks).get()).single.title,
      'Flashcard deck',
    );
    expect(generation.result!.sources.usage.single.retainedCharacters, 40000);
    expect(generation.result!.truncated, isTrue);
    expect(
      ((submitted!['sources'] as List).single['text'] as String).runes.length,
      40000,
    );
  });

  test('failed save retries locally; uncertain committed create reuses the same deck', () async {
    repo.failCreate = true;
    await generation.generate(_settings);
    expect(generation.hasUnsaved, isTrue);
    expect(generation.error, studyDeckSaveError);
    expect(await db.select(db.flashcardDecks).get(), isEmpty);
    repo.failCreate = false;
    repo.failAfterCommit = true;
    await generation.retrySave();
    expect(generation.savedId, isNull);
    expect(await db.select(db.flashcardDecks).get(), hasLength(1));
    repo.failAfterCommit = false;
    await generation.retrySave();
    expect(generation.savedId, isNotNull);
    expect(calls, 1);
    expect(await db.select(db.flashcardDecks).get(), hasLength(1));
    expect(await db.select(db.flashcards).get(), hasLength(3));
  });

  test(
    'deck limit is transactional; deleting frees capacity for pending save',
    () async {
      final ids = await Future.wait(List.generate(10, (_) => deck()));
      await generation.generate(_settings);
      expect(generation.error, studyDeckLimitMessage);
      expect(generation.hasUnsaved, isTrue);
      await repo.delete(ids.first);
      await generation.retrySave();
      expect(generation.savedId, isNotNull);
      expect(calls, 1);
      expect(await db.select(db.flashcardDecks).get(), hasLength(10));
    },
  );

  test(
    'offline and shared guard refuse requests without creating decks',
    () async {
      online = false;
      await generation.generate(_settings);
      expect(generation.error, studyAiMessages['OFFLINE']);
      online = true;
      final blocker = Completer<void>();
      final busy = guard.run(AiCancelToken(), (_) => blocker.future);
      await generation.generate(_settings);
      expect(generation.error, studyAiMessages['AI_IN_PROGRESS']);
      blocker.complete();
      await busy;
      expect(calls, 0);
      expect(await db.select(db.flashcardDecks).get(), isEmpty);
    },
  );

  test('cancellation and account changes discard late generations', () async {
    final response = Completer<dynamic>(), started = Completer<void>();
    invoke = (_, _, _) {
      started.complete();
      return response.future;
    };
    final request = generation.generate(_settings);
    await started.future;
    generation.cancel();
    await request;
    response.complete({
      'cards': [
        {'front': 'Late', 'back': 'Late'},
      ],
      'dropped': 0,
      'missing': 4,
    });
    await Future<void>.delayed(Duration.zero);
    expect(generation.result, isNull);
    expect(guard.isBusy, isFalse);
    final another = Completer<dynamic>(), dispatched = Completer<void>();
    invoke = (_, _, _) {
      dispatched.complete();
      return another.future;
    };
    final retry = generation.generate(_settings);
    await dispatched.future;
    current = false;
    another.complete({
      'cards': [
        {'front': 'Late', 'back': 'Late'},
      ],
      'dropped': 0,
      'missing': 4,
    });
    await retry;
    expect(await db.select(db.flashcardDecks).get(), isEmpty);
  });

  test(
    'all documented server errors use safe messages and neutral busy copy',
    () async {
      for (final code in [
        'NOT_ALLOWED',
        'INVALID_REQUEST',
        'NO_TEXT',
        'TOO_LARGE',
        'AI_IN_PROGRESS',
        'AI_BUSY',
        'AI_TIMEOUT',
        'AI_BAD_OUTPUT',
        'AI_UNAVAILABLE',
        'AI_BLOCKED',
      ]) {
        invoke = (_, _, _) async => {
          'error': {'code': code, 'message': 'PRIVATE'},
        };
        await generation.generate(_settings);
        expect(
          generation.error,
          code == 'AI_BUSY' ? studyFlashcardBusyMessage : studyAiMessages[code],
        );
      }
      expect(await db.select(db.flashcardDecks).get(), isEmpty);
    },
  );

  test('status persists before advancement; a failure leaves current card for retry', () async {
    final id = await deck(), session = study(await deck());
    await session.open();
    final first = session.card!.id;
    repo.statusGate = Completer<void>();
    final marking = session.mark('learning');
    expect(session.card!.id, first);
    expect(session.completed, 0);
    repo.statusGate!.complete();
    await marking;
    expect(session.completed, 1);
    expect(session.learning, 1);
    repo.statusGate = null;
    repo.failStatus = true;
    final second = session.card!.id;
    await session.mark('known');
    expect(session.card!.id, second);
    expect(session.completed, 1);
    expect(session.retryStatus, 'known');
    repo.failStatus = false;
    await session.mark('known');
    expect(session.known, 1);
    expect(session.completed, 2);
    expect((await savedCards(id)).every((c) => c.status == 'new'), isTrue);
  });

  test('shuffle keeps stored positions and missed replay includes only this pass learning cards', () async {
    final id = await deck(), session = study(await deck());
    await session.open();
    final positions = {for (final c in session.cards) c.id: c.position};
    session.shuffle();
    final missed = session.card!.id;
    await session.mark('learning');
    await session.mark('known');
    await session.mark('known');
    expect(session.progress, 1);
    expect(session.known, 2);
    expect(session.learning, 1);
    session.repeatMissed();
    expect(session.total, 1);
    expect(session.card!.id, missed);
    await session.mark('known');
    expect(session.known, 1);
    expect(session.learning, 0);
    expect({for (final c in session.cards) c.id: c.position}, positions);
    expect((await savedCards(id)).every((c) => c.status == 'new'), isTrue);
    final reopened = study(session.deckId);
    await reopened.open();
    expect(reopened.cards.every((c) => c.status == 'known'), isTrue);
    expect(reopened.total, 3);
    expect(reopened.completed, 0);
  });

  test('single-card deletion is deck-scoped and final deletion leaves an empty deck', () async {
    final id = await deck(), session = study(await deck());
    await session.open();
    final first = session.card!.id;
    expect(await repo.deleteCard(id, first), 0);
    while (session.card != null) {
      await session.deleteCurrent();
    }
    expect(session.cards, isEmpty);
    expect(await savedCards(session.deckId), isEmpty);
    expect(await db.select(db.flashcardDecks).get(), hasLength(2));
    expect(await savedCards(id), hasLength(3));
  });

  test(
    'account changes during status save roll back and leave the pass unchanged',
    () async {
      final session = study(await deck());
      await session.open();
      repo.statusGate = Completer<void>();
      final request = session.mark('known');
      current = false;
      repo.statusGate!.complete();
      await request;
      expect(session.completed, 0);
      expect(
        (await savedCards(session.deckId)).every((c) => c.status == 'new'),
        isTrue,
      );
    },
  );

  test('account invalidation rolls back deck rows and cards in the same transaction', () async {
    var checks = 0;
    await expectLater(
      repo.create(
        notebookId: notebook,
        title: 'Pending',
        settings: _settings,
        cards: _cards,
        canCommit: () => ++checks == 1,
      ),
      throwsStateError,
    );
    expect(await db.select(db.flashcardDecks).get(), isEmpty);
    expect(await db.select(db.flashcards).get(), isEmpty);
  });
}
