import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../assessments/data/file_text_cache.dart';
import '../../assessments/domain/ai_sources.dart';
import '../domain/study_inputs.dart';
import '../domain/study_summary_usage.dart';

const _uuid = Uuid();

Future<void> _checkLimit(
  AppDatabase db,
  String table,
  int limit, {
  String? notebookId,
}) async {
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM $table${notebookId == null ? '' : ' WHERE notebook_id=?'}',
        variables: notebookId == null ? [] : [Variable(notebookId)],
      )
      .getSingle();
  if (row.read<int>('n') >= limit) throw StudyLimitExceeded(table, limit);
}

class NotebookRepository {
  NotebookRepository(this.db);
  final AppDatabase db;
  Stream<List<StudyNotebook>> watchAll() =>
      (db.select(db.notebooks)..orderBy([
            (n) => OrderingTerm.desc(n.lastOpenedAt),
            (n) => OrderingTerm.asc(n.id),
          ]))
          .watch();
  Future<StudyNotebook?> get(String id) => (db.select(
    db.notebooks,
  )..where((n) => n.id.equals(id))).getSingleOrNull();
  Future<String> create(String name) async {
    requireStudyText(name, 'name');
    return db.transaction(() async {
      await _checkLimit(db, 'notebooks', 20);
      final id = _uuid.v4(), time = db.now().toUtc();
      await db
          .into(db.notebooks)
          .insert(
            NotebooksCompanion.insert(
              id: id,
              name: name.trim(),
              createdAt: time,
              updatedAt: time,
              lastOpenedAt: time,
            ),
          );
      return id;
    });
  }

  Future<int> rename(String id, String name) {
    requireStudyText(name, 'name');
    return (db.update(db.notebooks)..where((n) => n.id.equals(id))).write(
      NotebooksCompanion(
        name: Value(name.trim()),
        updatedAt: Value(db.now().toUtc()),
      ),
    );
  }

  Future<int> markOpened(String id) =>
      (db.update(db.notebooks)..where((n) => n.id.equals(id))).write(
        NotebooksCompanion(lastOpenedAt: Value(db.now().toUtc())),
      );
  Future<int> delete(String id) =>
      (db.delete(db.notebooks)..where((n) => n.id.equals(id))).go();
}

class NotebookSourceRepository {
  NotebookSourceRepository(this.db);
  final AppDatabase db;
  Stream<List<StudySource>> watch(String notebookId) =>
      (db.select(db.notebookSources)
            ..where((s) => s.notebookId.equals(notebookId))
            ..orderBy([
              (s) => OrderingTerm.asc(s.createdAt),
              (s) => OrderingTerm.asc(s.id),
            ]))
          .watch();
  Future<String> add({
    required String notebookId,
    required String fileId,
    required String name,
    required LessonText text,
    required DateTime extractedAt,
    int extractorRevision = lessonExtractorRevision,
  }) async {
    requireStudyText(fileId, 'fileId');
    requireStudyText(name, 'name', max: 255);
    requireStudyText(text.text, 'extractedText');
    if (!FileTextCache.validKey(text.sourceKey) ||
        extractorRevision < 1 ||
        utf8.encode(text.text).length > lessonCacheByteCap) {
      throw ArgumentError('Invalid source snapshot');
    }
    return db.transaction(() async {
      await _checkLimit(db, 'notebook_sources', 3, notebookId: notebookId);
      final id = _uuid.v4();
      await db
          .into(db.notebookSources)
          .insert(
            NotebookSourcesCompanion.insert(
              id: id,
              notebookId: notebookId,
              fileId: fileId,
              name: name.trim(),
              sourceKey: text.sourceKey,
              extractedText: text.text,
              extractorRevision: extractorRevision,
              extractedAt: extractedAt.toUtc(),
              createdAt: db.now().toUtc(),
            ),
          );
      return id;
    });
  }

  Future<int> remove(String id) =>
      (db.delete(db.notebookSources)..where((s) => s.id.equals(id))).go();
}

class StudyChatRepository {
  StudyChatRepository(this.db);
  final AppDatabase db;
  Future<StudyChat?> find(String notebookId, String chatId) =>
      (db.select(db.chats)..where(
            (c) => c.id.equals(chatId) & c.notebookId.equals(notebookId),
          ))
          .getSingleOrNull();

  Future<List<StudyMessage>> getMessages(String chatId) =>
      (db.select(db.chatMessages)
            ..where((m) => m.chatId.equals(chatId))
            ..orderBy([(m) => OrderingTerm.asc(m.position)]))
          .get();

  Future<(String, String)> saveQuestion({
    required String notebookId,
    required String? chatId,
    required String content,
    required String mode,
  }) => db.transaction(() async {
    requireStudyText(content, 'content', max: 2000);
    final title = String.fromCharCodes(
      content.replaceAll(RegExp(r'\s+'), ' ').runes.take(60),
    );
    var id = chatId;
    id ??= await create(notebookId, title);
    final chat = await find(notebookId, id);
    if (chat == null || !chat.expiresAt.isAfter(db.now().toUtc())) {
      throw StateError('Chat unavailable');
    }
    final messages = await getMessages(id);
    if (messages.isEmpty && chatId != null) await rename(id, title);
    if (messages.isNotEmpty &&
        messages.last.role == 'user' &&
        messages.last.content == content) {
      if (!{'files', 'general'}.contains(mode)) {
        throw ArgumentError('Invalid mode');
      }
      final now = db.now().toUtc();
      await (db.update(
        db.chatMessages,
      )..where((m) => m.id.equals(messages.last.id))).write(
        ChatMessagesCompanion(mode: Value(mode), createdAt: Value(now)),
      );
      await (db.update(db.chats)..where((c) => c.id.equals(id!))).write(
        ChatsCompanion(
          lastMessageAt: Value(now),
          expiresAt: Value(now.add(const Duration(days: 30))),
        ),
      );
      return (id, messages.last.id);
    }
    return (
      id,
      await addMessage(chatId: id, role: 'user', content: content, mode: mode),
    );
  });

  Future<void> saveReply({
    required String notebookId,
    required String chatId,
    required String questionId,
    required String content,
    required String mode,
  }) => db.transaction(() async {
    final chat = await find(notebookId, chatId);
    if (chat == null || !chat.expiresAt.isAfter(db.now().toUtc())) {
      throw StateError('Chat unavailable');
    }
    final messages = await getMessages(chatId);
    if (messages.length >= 2 &&
        messages.last.role == 'assistant' &&
        messages[messages.length - 2].id == questionId &&
        messages.last.content == content &&
        messages.last.mode == mode) {
      return;
    }
    if (messages.isEmpty ||
        messages.last.id != questionId ||
        messages.last.role != 'user') {
      throw StateError('Question is no longer current');
    }
    await addMessage(
      chatId: chatId,
      role: 'assistant',
      content: content,
      mode: mode,
    );
  });

  Stream<List<StudyChat>> watch(String notebookId) =>
      (db.select(db.chats)
            ..where((c) => c.notebookId.equals(notebookId))
            ..orderBy([
              (c) => OrderingTerm.desc(c.lastMessageAt),
              (c) => OrderingTerm.asc(c.id),
            ]))
          .watch();
  Stream<List<StudyMessage>> watchMessages(String chatId) =>
      (db.select(db.chatMessages)
            ..where((m) => m.chatId.equals(chatId))
            ..orderBy([(m) => OrderingTerm.asc(m.position)]))
          .watch();
  Future<String> create(String notebookId, String title) async {
    requireStudyText(title, 'title');
    final id = _uuid.v4(), time = db.now().toUtc();
    await db
        .into(db.chats)
        .insert(
          ChatsCompanion.insert(
            id: id,
            notebookId: notebookId,
            title: title.trim(),
            createdAt: time,
            lastMessageAt: time,
            expiresAt: time.add(const Duration(days: 30)),
          ),
        );
    return id;
  }

  Future<String> addMessage({
    required String chatId,
    required String role,
    required String content,
    required String mode,
  }) async {
    requireStudyText(content, 'content');
    if (!{'user', 'assistant'}.contains(role) ||
        !{'files', 'general'}.contains(mode)) {
      throw ArgumentError('Invalid message role or mode');
    }
    return db.transaction(() async {
      final chat = await (db.select(
        db.chats,
      )..where((c) => c.id.equals(chatId))).getSingle();
      final time = db.now().toUtc();
      if (!chat.expiresAt.isAfter(time)) throw StateError('Chat has expired');
      final previous =
          await (db.select(db.chatMessages)
                ..where((m) => m.chatId.equals(chatId))
                ..orderBy([(m) => OrderingTerm.desc(m.position)])
                ..limit(1))
              .getSingleOrNull();
      final id = _uuid.v4();
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: id,
              chatId: chatId,
              role: role,
              content: content,
              mode: mode,
              createdAt: time,
              position: (previous?.position ?? -1) + 1,
            ),
          );
      await (db.update(db.chats)..where((c) => c.id.equals(chatId))).write(
        ChatsCompanion(
          lastMessageAt: Value(time),
          expiresAt: Value(time.add(const Duration(days: 30))),
        ),
      );
      return id;
    });
  }

  Future<int> rename(String id, String title) {
    requireStudyText(title, 'title');
    return (db.update(db.chats)..where((c) => c.id.equals(id))).write(
      ChatsCompanion(title: Value(title.trim())),
    );
  }

  Future<int> delete(String id) =>
      (db.delete(db.chats)..where((c) => c.id.equals(id))).go();
  Future<int> purgeExpired() => db.purgeExpiredStudyChats();
}

class StudySummaryRepository {
  StudySummaryRepository(this.db);
  final AppDatabase db;
  Stream<StudySummary?> watch(String notebookId) => (db.select(
    db.summaries,
  )..where((s) => s.notebookId.equals(notebookId))).watchSingleOrNull();
  Future<void> save(
    String notebookId,
    String content, {
    StudySummaryUsage? usage,
    bool Function()? canCommit,
  }) async {
    requireStudyText(content, 'content', max: 4000);
    await db.transaction(() async {
      void checkCurrent() {
        if (canCommit != null && !canCommit()) {
          throw StateError('Summary save is no longer current');
        }
      }

      checkCurrent();
      final old = await (db.select(
        db.summaries,
      )..where((s) => s.notebookId.equals(notebookId))).getSingleOrNull();
      final time = db.now().toUtc();
      await db
          .into(db.summaries)
          .insertOnConflictUpdate(
            SummariesCompanion.insert(
              notebookId: notebookId,
              content: content,
              usageJson: Value(usage?.encode()),
              createdAt: old?.createdAt ?? time,
              updatedAt: time,
            ),
          );
      checkCurrent();
    });
  }

  Future<int> delete(String notebookId) => (db.delete(
    db.summaries,
  )..where((s) => s.notebookId.equals(notebookId))).go();
}

class StudyDeckRepository {
  StudyDeckRepository(this.db);
  final AppDatabase db;
  Stream<List<StudyDeck>> watch(String notebookId) =>
      (db.select(db.flashcardDecks)
            ..where((d) => d.notebookId.equals(notebookId))
            ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
          .watch();
  Stream<List<StudyCard>> watchCards(String deckId) =>
      (db.select(db.flashcards)
            ..where((c) => c.deckId.equals(deckId))
            ..orderBy([(c) => OrderingTerm.asc(c.position)]))
          .watch();
  Future<String> create({
    required String notebookId,
    required String title,
    required StudyDeckSettings settings,
    required List<StudyCardInput> cards,
    String? deckId,
    bool Function()? canCommit,
  }) async {
    requireStudyText(title, 'title');
    settings.validate();
    if (cards.isEmpty || cards.length > settings.count) {
      throw ArgumentError('Invalid card count');
    }
    for (final card in cards) {
      card.validate();
    }
    return db.transaction(() async {
      void checkCurrent() {
        if (canCommit != null && !canCommit()) {
          throw StateError('Deck save is no longer current');
        }
      }

      checkCurrent();
      final id = deckId ?? _uuid.v4();
      final existing = await (db.select(
        db.flashcardDecks,
      )..where((d) => d.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        final saved =
            await (db.select(db.flashcards)
                  ..where((c) => c.deckId.equals(id))
                  ..orderBy([(c) => OrderingTerm.asc(c.position)]))
                .get();
        if (existing.notebookId != notebookId ||
            existing.title != title.trim() ||
            existing.settings != jsonEncode(settings.toJson()) ||
            saved.length != cards.length ||
            List.generate(
              cards.length,
              (i) =>
                  saved[i].front != cards[i].front ||
                  saved[i].back != cards[i].back,
            ).any((different) => different)) {
          throw StateError('Deck save does not match existing content');
        }
        checkCurrent();
        return id;
      }
      await _checkLimit(db, 'flashcard_decks', 10, notebookId: notebookId);
      final time = db.now().toUtc();
      await db
          .into(db.flashcardDecks)
          .insert(
            FlashcardDecksCompanion.insert(
              id: id,
              notebookId: notebookId,
              title: title.trim(),
              settings: jsonEncode(settings.toJson()),
              createdAt: time,
              updatedAt: time,
            ),
          );
      for (var i = 0; i < cards.length; i++) {
        await db
            .into(db.flashcards)
            .insert(
              FlashcardsCompanion.insert(
                id: _uuid.v4(),
                deckId: id,
                front: cards[i].front,
                back: cards[i].back,
                position: i,
              ),
            );
      }
      checkCurrent();
      return id;
    });
  }

  Future<int> setCardStatus(
    String id,
    String status, {
    String? deckId,
    bool Function()? canCommit,
  }) {
    if (!{'new', 'learning', 'known'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    return db.transaction(() async {
      if (canCommit != null && !canCommit()) {
        throw StateError('Account changed');
      }
      final changed =
          await (db.update(db.flashcards)..where(
                (c) =>
                    c.id.equals(id) &
                    (deckId == null
                        ? const Constant(true)
                        : c.deckId.equals(deckId)),
              ))
              .write(FlashcardsCompanion(status: Value(status)));
      if (canCommit != null && !canCommit()) {
        throw StateError('Account changed');
      }
      return changed;
    });
  }

  Future<int> deleteCard(
    String deckId,
    String cardId, {
    bool Function()? canCommit,
  }) => db.transaction(() async {
    if (canCommit != null && !canCommit()) throw StateError('Account changed');
    final changed = await (db.delete(
      db.flashcards,
    )..where((c) => c.id.equals(cardId) & c.deckId.equals(deckId))).go();
    if (canCommit != null && !canCommit()) throw StateError('Account changed');
    return changed;
  });

  Future<int> rename(String id, String title) {
    requireStudyText(title, 'title');
    return (db.update(db.flashcardDecks)..where((d) => d.id.equals(id))).write(
      FlashcardDecksCompanion(
        title: Value(title.trim()),
        updatedAt: Value(db.now().toUtc()),
      ),
    );
  }

  Future<int> delete(String id) =>
      (db.delete(db.flashcardDecks)..where((d) => d.id.equals(id))).go();
}

class StudyQuizRepository {
  StudyQuizRepository(this.db);
  final AppDatabase db;
  Stream<List<StudyQuiz>> watch(String notebookId) =>
      (db.select(db.practiceQuizzes)
            ..where((q) => q.notebookId.equals(notebookId))
            ..orderBy([(q) => OrderingTerm.desc(q.createdAt)]))
          .watch();
  Stream<List<StudyQuestion>> watchQuestions(String quizId) =>
      (db.select(db.practiceQuestions)
            ..where((q) => q.quizId.equals(quizId))
            ..orderBy([(q) => OrderingTerm.asc(q.position)]))
          .watch();
  Future<String> create({
    required String notebookId,
    required String title,
    required StudyQuizSettings settings,
    required List<StudyQuestionInput> questions,
    String? quizId,
    bool Function()? canCommit,
  }) async {
    requireStudyText(title, 'title');
    settings.validate();
    if (questions.isEmpty || questions.length > settings.count) {
      throw ArgumentError('Invalid question count');
    }
    for (final question in questions) {
      question.validate();
      if (!settings.types.contains(question.type)) {
        throw ArgumentError('Unselected question type');
      }
    }
    return db.transaction(() async {
      void checkCurrent() {
        if (canCommit != null && !canCommit()) {
          throw StateError('Quiz save is no longer current');
        }
      }

      checkCurrent();
      final id = quizId ?? _uuid.v4();
      final existing = await (db.select(
        db.practiceQuizzes,
      )..where((q) => q.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        final saved =
            await (db.select(db.practiceQuestions)
                  ..where((q) => q.quizId.equals(id))
                  ..orderBy([(q) => OrderingTerm.asc(q.position)]))
                .get();
        if (existing.notebookId != notebookId ||
            existing.title != title.trim() ||
            existing.settings != jsonEncode(settings.toJson()) ||
            saved.length != questions.length) {
          throw StateError('Quiz save mismatch');
        }
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i], row = saved[i];
          if (q.type != row.type ||
              q.prompt != row.prompt ||
              q.explanation != row.explanation ||
              q.correctIndex != row.correctIndex ||
              q.correctBoolean != row.correctBoolean ||
              (q.options == null ? null : jsonEncode(q.options)) !=
                  row.options ||
              (q.acceptedAnswers == null
                      ? null
                      : jsonEncode(q.acceptedAnswers)) !=
                  row.acceptedAnswers) {
            throw StateError('Quiz questions mismatch');
          }
        }
        checkCurrent();
        return id;
      }
      await _checkLimit(db, 'practice_quizzes', 10, notebookId: notebookId);
      final time = db.now().toUtc();
      await db
          .into(db.practiceQuizzes)
          .insert(
            PracticeQuizzesCompanion.insert(
              id: id,
              notebookId: notebookId,
              title: title.trim(),
              settings: jsonEncode(settings.toJson()),
              createdAt: time,
              updatedAt: time,
            ),
          );
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        await db
            .into(db.practiceQuestions)
            .insert(
              PracticeQuestionsCompanion.insert(
                id: _uuid.v4(),
                quizId: id,
                type: q.type,
                prompt: q.prompt,
                explanation: q.explanation,
                position: i,
                options: Value(
                  q.options == null ? null : jsonEncode(q.options),
                ),
                correctIndex: Value(q.correctIndex),
                correctBoolean: Value(q.correctBoolean),
                acceptedAnswers: Value(
                  q.acceptedAnswers == null
                      ? null
                      : jsonEncode(q.acceptedAnswers),
                ),
              ),
            );
      }
      checkCurrent();
      return id;
    });
  }

  Future<int> rename(String id, String title) {
    requireStudyText(title, 'title');
    return (db.update(db.practiceQuizzes)..where((q) => q.id.equals(id))).write(
      PracticeQuizzesCompanion(
        title: Value(title.trim()),
        updatedAt: Value(db.now().toUtc()),
      ),
    );
  }

  Future<int> delete(String id) =>
      (db.delete(db.practiceQuizzes)..where((q) => q.id.equals(id))).go();
}

class StudyAttemptRepository {
  StudyAttemptRepository(this.db);
  final AppDatabase db;
  Stream<List<StudyAttempt>> watch(String quizId) =>
      (db.select(db.practiceAttempts)
            ..where((a) => a.quizId.equals(quizId))
            ..orderBy([(a) => OrderingTerm.desc(a.attemptedAt)]))
          .watch();
  Future<String> save(
    String quizId,
    List<StudyQuestionResult> results, {
    String? attemptId,
    bool Function()? canCommit,
  }) => db.transaction(() async {
    void checkCurrent() {
      if (canCommit != null && !canCommit()) {
        throw StateError('Attempt is no longer current');
      }
    }

    checkCurrent();
    final questions = await (db.select(
      db.practiceQuestions,
    )..where((q) => q.quizId.equals(quizId))).get();
    final byId = {for (final q in questions) q.id: q};
    if (results.isEmpty ||
        results.length != questions.length ||
        results.map((r) => r.questionId).toSet().length != results.length) {
      throw ArgumentError('An attempt must contain each question exactly once');
    }
    for (final r in results) {
      final q = byId[r.questionId], answer = r.answer;
      if (q == null ||
          !(switch (q.type) {
            'multiple_choice' => answer is int && answer >= 0 && answer <= 3,
            'true_false' => answer is bool,
            'identification' => answer is String,
            _ => false,
          })) {
        throw ArgumentError('Invalid attempt answer');
      }
    }
    final id = attemptId ?? _uuid.v4();
    final encoded = jsonEncode(results.map((r) => r.toJson()).toList());
    final existing = await (db.select(
      db.practiceAttempts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      if (existing.quizId != quizId || existing.results != encoded) {
        throw StateError('Attempt save mismatch');
      }
      checkCurrent();
      return id;
    }
    await db
        .into(db.practiceAttempts)
        .insert(
          PracticeAttemptsCompanion.insert(
            id: id,
            quizId: quizId,
            attemptedAt: db.now().toUtc(),
            score: results.where((r) => r.correct).length,
            total: results.length,
            results: encoded,
          ),
        );
    checkCurrent();
    return id;
  });
  Future<int> delete(String id) =>
      (db.delete(db.practiceAttempts)..where((a) => a.id.equals(id))).go();
}
