import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/study/application/study_providers.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _studyTables = [
  'practice_attempts',
  'practice_questions',
  'practice_quizzes',
  'flashcards',
  'flashcard_decks',
  'summaries',
  'chat_messages',
  'chats',
  'notebook_sources',
  'notebooks',
];
const _cards = [StudyCardInput(front: 'Question', back: 'Answer')];
const _questions = [
  StudyQuestionInput(
    type: 'multiple_choice',
    prompt: 'Choose',
    options: ['A', 'B', 'C', 'D'],
    correctIndex: 1,
    explanation: 'Because B',
  ),
  StudyQuestionInput(
    type: 'true_false',
    prompt: 'Statement',
    correctBoolean: true,
    explanation: 'It holds',
  ),
  StudyQuestionInput(
    type: 'identification',
    prompt: 'Name it',
    acceptedAnswers: ['Answer', 'Variant'],
    explanation: 'Definition',
  ),
];

Future<String> _deck(AppDatabase db, String notebookId) =>
    StudyDeckRepository(db).create(
      notebookId: notebookId,
      title: 'Deck',
      settings: const StudyDeckSettings(count: 5, topicFocus: 'Topic'),
      cards: _cards,
    );
Future<String> _quiz(AppDatabase db, String notebookId) =>
    StudyQuizRepository(db).create(
      notebookId: notebookId,
      title: 'Quiz',
      settings: const StudyQuizSettings(
        count: 5,
        types: ['multiple_choice', 'true_false', 'identification'],
      ),
      questions: _questions,
    );
Future<String> _source(AppDatabase db, String notebookId, int index) =>
    NotebookSourceRepository(db).add(
      notebookId: notebookId,
      fileId: 'original',
      name: 'Lesson',
      text: LessonText(text: 'Retained source', sourceKey: 'att:source-$index'),
      extractedAt: db.now(),
    );
Future<String> _attempt(AppDatabase db, String quizId) async {
  final questions = await StudyQuizRepository(db).watchQuestions(quizId).first;
  return StudyAttemptRepository(db).save(quizId, [
    StudyQuestionResult(questionId: questions[0].id, answer: 1, correct: true),
    StudyQuestionResult(
      questionId: questions[1].id,
      answer: false,
      correct: false,
    ),
    StudyQuestionResult(
      questionId: questions[2].id,
      answer: 'Answer',
      correct: true,
    ),
  ]);
}

Future<int> _count(AppDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
        .read<int>('n');
Future<void> _originalFile(AppDatabase db, File file) async {
  await file.writeAsString('Original bytes');
  await db
      .into(db.localFiles)
      .insert(
        LocalFilesCompanion.insert(
          id: 'original',
          name: 'Lesson.txt',
          relativePath: file.path,
          size: 14,
          source: 'personal_upload',
          createdAt: db.now(),
          updatedAt: db.now(),
        ),
      );
}

void main() {
  late AppDatabase db;
  late DateTime time;
  setUp(() {
    time = DateTime.utc(2026, 10, 31, 9);
    db = AppDatabase(NativeDatabase.memory(), now: () => time);
  });
  tearDown(() => db.close());

  test(
    'notebook deletion cascades all ten tables and preserves original file',
    () async {
      final directory = await Directory.systemTemp.createTemp('filo-study-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/lesson.txt');
      await _originalFile(db, file);
      final notebook = await NotebookRepository(db).create('Notebook');
      final other = await NotebookRepository(db).create('Other notebook');
      await _source(db, notebook, 1);
      final chat = await StudyChatRepository(db).create(notebook, 'Chat');
      await StudyChatRepository(
        db,
      ).addMessage(chatId: chat, role: 'user', content: 'Ask', mode: 'files');
      await StudyChatRepository(db).addMessage(
        chatId: chat,
        role: 'assistant',
        content: 'Reply',
        mode: 'files',
      );
      await StudySummaryRepository(db).save(notebook, 'Summary');
      await _deck(db, notebook);
      final quiz = await _quiz(db, notebook);
      await _attempt(db, quiz);
      for (final table in _studyTables) {
        expect(await _count(db, table), greaterThan(0), reason: table);
      }
      await NotebookRepository(db).delete(notebook);
      for (final table in _studyTables.where((t) => t != 'notebooks')) {
        expect(await _count(db, table), 0, reason: table);
      }
      expect((await NotebookRepository(db).watchAll().first).single.id, other);
      expect(await _count(db, 'local_files'), 1);
      expect(await file.readAsString(), 'Original bytes');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('chat, deck and quiz deletion remove only their own children', () async {
    final notebook = await NotebookRepository(db).create('Notebook');
    final chats = StudyChatRepository(db);
    final chat = await chats.create(notebook, 'Chat');
    await chats.addMessage(
      chatId: chat,
      role: 'user',
      content: 'Hi',
      mode: 'general',
    );
    final keptChat = await chats.create(notebook, 'Keep');
    await chats.addMessage(
      chatId: keptChat,
      role: 'user',
      content: 'Keep',
      mode: 'general',
    );
    await chats.delete(chat);
    expect((await db.select(db.chatMessages).get()).single.chatId, keptChat);
    final deck = await _deck(db, notebook),
        keptDeck = await _deck(db, notebook);
    await StudyDeckRepository(db).delete(deck);
    expect((await db.select(db.flashcards).get()).single.deckId, keptDeck);
    final quiz = await _quiz(db, notebook),
        keptQuiz = await _quiz(db, notebook);
    await _attempt(db, quiz);
    await _attempt(db, keptQuiz);
    await StudyQuizRepository(db).delete(quiz);
    expect(
      (await db.select(db.practiceQuestions).get()).every(
        (q) => q.quizId == keptQuiz,
      ),
      isTrue,
    );
    expect(
      (await db.select(db.practiceAttempts).get()).single.quizId,
      keptQuiz,
    );
    expect(await NotebookRepository(db).get(notebook), isNotNull);
  });

  for (final resource in [
    'notebooks',
    'notebook_sources',
    'flashcard_decks',
    'practice_quizzes',
  ]) {
    test(
      '$resource limit is atomic, scoped and reusable after deletion',
      () async {
        final notebooks = NotebookRepository(db);
        final notebook = await notebooks.create('Parent');
        final limit = resource == 'notebooks'
            ? 20
            : resource == 'notebook_sources'
            ? 3
            : 10;
        var serial = 0;
        Future<String> create() => switch (resource) {
          'notebooks' => notebooks.create('Notebook ${serial++}'),
          'notebook_sources' => _source(db, notebook, serial++),
          'flashcard_decks' => _deck(db, notebook),
          _ => _quiz(db, notebook),
        };
        final ids = <String>[];
        for (var i = resource == 'notebooks' ? 1 : 0; i < limit - 1; i++) {
          ids.add(await create());
        }
        final raced = await Future.wait(
          List.generate(
            3,
            (_) => create().then<Object>(
              (id) => id,
              onError: (Object error, StackTrace _) => error,
            ),
          ),
        );
        expect(raced.whereType<String>().length, 1);
        final failures = raced.whereType<StudyLimitExceeded>().toList();
        expect(failures.length, 2);
        expect(
          failures.every((f) => f.resource == resource && f.limit == limit),
          isTrue,
        );
        expect(await _count(db, resource), limit);
        final id = ids.first;
        switch (resource) {
          case 'notebooks':
            await notebooks.delete(id);
          case 'notebook_sources':
            await NotebookSourceRepository(db).remove(id);
          case 'flashcard_decks':
            await StudyDeckRepository(db).delete(id);
          case 'practice_quizzes':
            await StudyQuizRepository(db).delete(id);
        }
        await create();
        expect(await _count(db, resource), limit);
        if (resource != 'notebooks') {
          final other = await notebooks.create('Other');
          switch (resource) {
            case 'notebook_sources':
              await _source(db, other, 999);
            case 'flashcard_decks':
              await _deck(db, other);
            case 'practice_quizzes':
              await _quiz(db, other);
          }
          expect(await _count(db, resource), limit + 1);
        }
      },
    );
  }

  test('chat expiry starts at creation, renews on messages and expires at boundary', () async {
    final notebook = await NotebookRepository(db).create('Notebook');
    final repo = StudyChatRepository(db), created = time;
    final empty = await repo.create(notebook, 'Empty');
    final chat = await repo.create(notebook, 'Active');
    expect(
      (await repo.watch(notebook).first).every(
        (c) => c.expiresAt.toUtc() == created.add(const Duration(days: 30)),
      ),
      isTrue,
    );
    time = created.add(const Duration(days: 29));
    await Future.wait([
      repo.addMessage(
        chatId: chat,
        role: 'user',
        content: 'Question',
        mode: 'general',
      ),
      repo.addMessage(
        chatId: chat,
        role: 'assistant',
        content: 'Answer',
        mode: 'general',
      ),
    ]);
    final messages = await repo.watchMessages(chat).first;
    expect(messages.map((m) => m.position), [0, 1]);
    final renewed = (await repo.watch(notebook).first).firstWhere(
      (c) => c.id == chat,
    );
    expect(renewed.lastMessageAt.toUtc(), time);
    expect(renewed.expiresAt.toUtc(), time.add(const Duration(days: 30)));
    time = created
        .add(const Duration(days: 30))
        .subtract(const Duration(seconds: 1));
    expect(await repo.purgeExpired(), 0);
    time = created.add(const Duration(days: 30));
    expect(await repo.purgeExpired(), 1);
    expect(
      (await repo.watch(notebook).first).map((c) => c.id),
      isNot(contains(empty)),
    );
    time = renewed.expiresAt;
    await expectLater(
      repo.addMessage(
        chatId: chat,
        role: 'user',
        content: 'Late',
        mode: 'general',
      ),
      throwsStateError,
    );
    expect(await _count(db, 'chat_messages'), 2);
    expect(await repo.purgeExpired(), 1);
    expect(await _count(db, 'chat_messages'), 0);
  });

  test(
    'opening database purges expired chats and keeps unexpired history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'filo-study-expiry-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/account.sqlite');
      var disk = AppDatabase(NativeDatabase(file), now: () => time);
      final notebook = await NotebookRepository(disk).create('Notebook');
      final expired = await StudyChatRepository(disk).create(notebook, 'Old');
      await StudyChatRepository(disk).addMessage(
        chatId: expired,
        role: 'user',
        content: 'Old',
        mode: 'files',
      );
      time = time.add(const Duration(days: 1));
      final kept = await StudyChatRepository(disk).create(notebook, 'New');
      await StudyChatRepository(disk).addMessage(
        chatId: kept,
        role: 'assistant',
        content: 'New',
        mode: 'files',
      );
      await disk.close();
      time = time.add(const Duration(days: 29));
      disk = AppDatabase(NativeDatabase(file), now: () => time);
      addTearDown(() => disk.close());
      expect((await disk.select(disk.chats).get()).single.id, kept);
      expect((await disk.select(disk.chatMessages).get()).single.chatId, kept);
      expect(await _count(disk, 'notebooks'), 1);
    },
  );

  test(
    'snapshot survives file deletion, draft cleanup, cache expiry and reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'filo-study-source-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/account.sqlite');
      final original = File('${directory.path}/lesson.txt');
      var disk = AppDatabase(NativeDatabase(file), now: () => time);
      await _originalFile(disk, original);
      final notebook = await NotebookRepository(disk).create('Notebook');
      await _source(disk, notebook, 1);
      final cache = FileTextCache(disk, now: () => time);
      await cache.save(
        const LessonText(text: 'Retained source', sourceKey: 'att:source-1'),
        'draft',
      );
      await (disk.delete(
        disk.localFiles,
      )..where((f) => f.id.equals('original'))).go();
      await original.delete();
      await cache.deleteForDraft('draft');
      expect(await cache.find('att:source-1'), isNull);
      expect(
        (await NotebookSourceRepository(
          disk,
        ).watch(notebook).first).single.extractedText,
        'Retained source',
      );
      await cache.save(
        const LessonText(text: 'Temporary text', sourceKey: 'att:source-1'),
        'other-draft',
      );
      await disk.customStatement('UPDATE file_text_cache SET extracted_at=0');
      await disk.close();
      disk = AppDatabase(NativeDatabase(file), now: () => time);
      addTearDown(() => disk.close());
      final source = (await NotebookSourceRepository(
        disk,
      ).watch(notebook).first).single;
      expect(source.sourceKey, 'att:source-1');
      expect(source.fileId, 'original');
      expect(source.extractedText, 'Retained source');
      expect(await _count(disk, 'file_text_cache'), 0);
      await NotebookSourceRepository(disk).remove(source.id);
      expect(await NotebookRepository(disk).get(notebook), isNotNull);
    },
  );

  test('one summary, saved settings, statuses, question shapes and attempt results', () async {
    final notebook = await NotebookRepository(db).create('Notebook');
    final summary = StudySummaryRepository(db);
    await summary.save(notebook, 'First');
    final first = (await summary.watch(notebook).first)!;
    time = time.add(const Duration(hours: 1));
    await summary.save(notebook, 'Replacement');
    final saved = (await summary.watch(notebook).first)!;
    expect(await _count(db, 'summaries'), 1);
    expect(saved.createdAt, first.createdAt);
    expect(saved.updatedAt.toUtc(), time);
    expect(saved.content, 'Replacement');
    final deck = await _deck(db, notebook);
    final decks = StudyDeckRepository(db);
    final card = (await decks.watchCards(deck).first).single;
    expect(card.status, 'new');
    await decks.setCardStatus(card.id, 'learning');
    expect((await decks.watchCards(deck).first).single.status, 'learning');
    await decks.setCardStatus(card.id, 'known');
    expect((await decks.watchCards(deck).first).single.status, 'known');
    expect(() => decks.setCardStatus(card.id, 'invalid'), throwsArgumentError);
    expect(jsonDecode((await decks.watch(notebook).first).single.settings), {
      'count': 5,
      'topic_focus': 'Topic',
    });
    final quiz = await _quiz(db, notebook);
    final questions = await StudyQuizRepository(db).watchQuestions(quiz).first;
    expect(jsonDecode(questions[0].options!), ['A', 'B', 'C', 'D']);
    expect(questions[0].correctIndex, 1);
    expect(questions[1].correctBoolean, true);
    expect(jsonDecode(questions[2].acceptedAnswers!), ['Answer', 'Variant']);
    await _attempt(db, quiz);
    final attempt = (await StudyAttemptRepository(db).watch(quiz).first).single;
    expect(attempt.score, 2);
    expect(attempt.total, 3);
    expect(attempt.attemptedAt.toUtc(), time);
    expect((jsonDecode(attempt.results) as List).map((r) => r['correct']), [
      true,
      false,
      true,
    ]);
    await expectLater(
      StudyAttemptRepository(db).save(quiz, [
        StudyQuestionResult(
          questionId: questions[0].id,
          answer: 0,
          correct: false,
        ),
      ]),
      throwsArgumentError,
    );
  });

  test(
    'invalid payloads and missing parents leave no partial study rows',
    () async {
      final notebook = await NotebookRepository(db).create('Notebook');
      await expectLater(
        StudyDeckRepository(db).create(
          notebookId: notebook,
          title: 'Deck',
          settings: const StudyDeckSettings(count: 5),
          cards: const [StudyCardInput(front: '', back: 'Back')],
        ),
        throwsArgumentError,
      );
      await expectLater(
        StudyQuizRepository(db).create(
          notebookId: notebook,
          title: 'Quiz',
          settings: const StudyQuizSettings(count: 5, types: ['true_false']),
          questions: const [
            StudyQuestionInput(
              type: 'true_false',
              prompt: 'Prompt',
              explanation: 'Why',
              correctIndex: 0,
            ),
          ],
        ),
        throwsArgumentError,
      );
      await expectLater(_deck(db, 'missing-parent'), throwsA(isA<Exception>()));
      expect(await _count(db, 'flashcard_decks'), 0);
      expect(await _count(db, 'flashcards'), 0);
      expect(await _count(db, 'practice_quizzes'), 0);
      expect(await _count(db, 'practice_questions'), 0);
    },
  );

  test(
    'failed child save rolls back its parent and permits a clean retry',
    () async {
      final notebook = await NotebookRepository(db).create('Notebook');
      await db.customStatement('''
      CREATE TRIGGER fail_second_card BEFORE INSERT ON flashcards
      WHEN NEW.position=1 BEGIN SELECT RAISE(ABORT, 'synthetic write failure'); END
    ''');
      Future<String> save() => StudyDeckRepository(db).create(
        notebookId: notebook,
        title: 'Deck',
        settings: const StudyDeckSettings(count: 5),
        cards: const [
          StudyCardInput(front: 'One', back: 'First'),
          StudyCardInput(front: 'Two', back: 'Second'),
        ],
      );
      await expectLater(save(), throwsA(isA<Exception>()));
      expect(await _count(db, 'flashcard_decks'), 0);
      expect(await _count(db, 'flashcards'), 0);
      await db.customStatement('DROP TRIGGER fail_second_card');
      await save();
      expect(await _count(db, 'flashcard_decks'), 1);
      expect(await _count(db, 'flashcards'), 2);
    },
  );

  test('v10 upgrade adds tables and indexes without changing populated existing tables', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-study-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/account.sqlite');
    var disk = AppDatabase(NativeDatabase(file), now: () => time);
    await disk.saveProfile(
      CacheProfilesCompanion.insert(
        id: 'owner',
        role: 'student',
        displayName: 'Owner',
      ),
    );
    await _originalFile(disk, File('${directory.path}/original.txt'));
    await disk
        .into(disk.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'queued',
            actionType: 'existing',
            payload: '{}',
            status: 'pending',
          ),
        );
    await FileTextCache(disk).save(
      const LessonText(text: 'Cached text', sourceKey: 'att:source-1'),
      'draft',
    );
    // Remove all v11 additions to form the existing physical v10 schema, not just its version flag.
    for (final table in _studyTables) {
      await disk.customStatement('DROP TABLE $table');
    }
    await disk.customStatement('PRAGMA user_version=10');
    final schema = await disk
        .customSelect(
          "SELECT name,sql FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .get();
    final names = schema.map((r) => r.read<String>('name')).toList();
    final before = <String, List<Map<String, Object?>>>{};
    for (final name in names) {
      before[name] = (await disk.customSelect('SELECT * FROM "$name"').get())
          .map((r) => r.data)
          .toList();
    }
    await disk.close();
    disk = AppDatabase(NativeDatabase(file), now: () => time);
    addTearDown(() => disk.close());
    expect(
      (await disk.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      12,
    );
    for (final name in names) {
      expect(
        (await disk.customSelect('SELECT * FROM "$name"').get())
            .map((r) => r.data)
            .toList(),
        before[name],
        reason: name,
      );
      final sql = await disk
          .customSelect(
            'SELECT sql FROM sqlite_master WHERE name=?',
            variables: [Variable(name)],
          )
          .getSingle();
      expect(
        sql.read<String>('sql'),
        schema
            .firstWhere((r) => r.read<String>('name') == name)
            .read<String>('sql'),
      );
    }
    final indexes =
        (await disk
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='index'",
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(
      indexes,
      containsAll([
        'study_idx_chats_notebook',
        'study_idx_chats_expiry',
        'study_idx_messages_chat',
        'study_idx_decks_notebook',
        'study_idx_quizzes_notebook',
        'study_idx_attempts_quiz',
      ]),
    );
    final notebook = await NotebookRepository(disk).create('Migrated');
    await _source(disk, notebook, 1);
    await _deck(disk, notebook);
    final quiz = await _quiz(disk, notebook);
    await _attempt(disk, quiz);
    final chat = await StudyChatRepository(disk).create(notebook, 'Chat');
    await StudyChatRepository(disk)
        .addMessage(chatId: chat, role: 'user', content: 'Hi', mode: 'general');
    await NotebookRepository(disk).delete(notebook);
    for (final table in _studyTables) {
      expect(await _count(disk, table), 0);
    }
    expect(await disk.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'account files and repository providers isolate and retain study content',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'filo-study-accounts-',
      );
      final manager = UserDatabaseManager(
        directoryProvider: () async => directory,
      );
      addTearDown(() async {
        await manager.close();
        await directory.delete(recursive: true);
      });
      var current = await manager.openForUser('account-a');
      final container = ProviderContainer(
        overrides: [
          accountDatabaseProvider.overrideWith((ref) async => current),
        ],
      );
      addTearDown(container.dispose);
      final a = (await container.read(notebookRepositoryProvider.future))!;
      final notebook = await a.create('Private A');
      await _source(current, notebook, 1);
      await _deck(current, notebook);
      final quiz = await _quiz(current, notebook);
      await _attempt(current, quiz);
      current = await manager.openForUser('account-b');
      container.invalidate(accountDatabaseProvider);
      final b = (await container.read(notebookRepositoryProvider.future))!;
      expect(identical(a, b), isFalse);
      for (final table in _studyTables) {
        expect(await _count(current, table), 0);
      }
      await b.create('Private B');
      current = await manager.openForUser('account-a');
      container.invalidate(accountDatabaseProvider);
      container.listen(studyNotebooksProvider, (_, _) {});
      container.listen(studySourcesProvider(notebook), (_, _) {});
      container.listen(studyDecksProvider(notebook), (_, _) {});
      container.listen(studyAttemptsProvider(quiz), (_, _) {});
      expect(
        (await container.read(studyNotebooksProvider.future)).single.name,
        'Private A',
      );
      expect(
        (await container.read(studySourcesProvider(notebook).future))
            .single
            .extractedText,
        'Retained source',
      );
      expect(
        (await container.read(studyDecksProvider(notebook).future)).length,
        1,
      );
      expect(
        (await container.read(studyAttemptsProvider(quiz).future)).single.score,
        2,
      );
    },
  );

  test(
    'signed-out providers do not expose a loaded empty notebook list',
    () async {
      final container = ProviderContainer(
        overrides: [accountDatabaseProvider.overrideWith((ref) async => null)],
      );
      addTearDown(container.dispose);
      expect(await container.read(notebookRepositoryProvider.future), isNull);
      await expectLater(
        container.read(studyNotebooksProvider.future),
        throwsStateError,
      );
    },
  );
}
