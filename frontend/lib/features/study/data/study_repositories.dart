import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../assessments/data/file_text_cache.dart';
import '../../assessments/domain/ai_sources.dart';
import '../domain/study_inputs.dart';

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
  Future<void> save(String notebookId, String content) async {
    requireStudyText(content, 'content', max: 4000);
    await db.transaction(() async {
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
              createdAt: old?.createdAt ?? time,
              updatedAt: time,
            ),
          );
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
  }) async {
    requireStudyText(title, 'title');
    settings.validate();
    if (cards.isEmpty || cards.length > settings.count)
      throw ArgumentError('Invalid card count');
    for (final card in cards) {
      card.validate();
    }
    return db.transaction(() async {
      await _checkLimit(db, 'flashcard_decks', 10, notebookId: notebookId);
      final id = _uuid.v4(), time = db.now().toUtc();
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
      return id;
    });
  }

  Future<int> setCardStatus(String id, String status) {
    if (!{'new', 'learning', 'known'}.contains(status))
      throw ArgumentError.value(status, 'status');
    return (db.update(db.flashcards)..where((c) => c.id.equals(id))).write(
      FlashcardsCompanion(status: Value(status)),
    );
  }

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
  }) async {
    requireStudyText(title, 'title');
    settings.validate();
    if (questions.isEmpty || questions.length > settings.count)
      throw ArgumentError('Invalid question count');
    for (final question in questions) {
      question.validate();
      if (!settings.types.contains(question.type))
        throw ArgumentError('Unselected question type');
    }
    return db.transaction(() async {
      await _checkLimit(db, 'practice_quizzes', 10, notebookId: notebookId);
      final id = _uuid.v4(), time = db.now().toUtc();
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
    List<StudyQuestionResult> results,
  ) => db.transaction(() async {
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
    final id = _uuid.v4();
    await db
        .into(db.practiceAttempts)
        .insert(
          PracticeAttemptsCompanion.insert(
            id: id,
            quizId: quizId,
            attemptedAt: db.now().toUtc(),
            score: results.where((r) => r.correct).length,
            total: results.length,
            results: jsonEncode(results.map((r) => r.toJson()).toList()),
          ),
        );
    return id;
  });
  Future<int> delete(String id) =>
      (db.delete(db.practiceAttempts)..where((a) => a.id.equals(id))).go();
}
