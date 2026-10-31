import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../data/study_repositories.dart';

final notebookRepositoryProvider = FutureProvider<NotebookRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null || !ref.mounted ? null : NotebookRepository(db);
});
final notebookSourceRepositoryProvider =
    FutureProvider<NotebookSourceRepository?>((ref) async {
      final db = await ref.watch(accountDatabaseProvider.future);
      return db == null || !ref.mounted ? null : NotebookSourceRepository(db);
    });
final studyChatRepositoryProvider = FutureProvider<StudyChatRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null || !ref.mounted ? null : StudyChatRepository(db);
});
final studySummaryRepositoryProvider = FutureProvider<StudySummaryRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null || !ref.mounted ? null : StudySummaryRepository(db);
});
final studyDeckRepositoryProvider = FutureProvider<StudyDeckRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null || !ref.mounted ? null : StudyDeckRepository(db);
});
final studyQuizRepositoryProvider = FutureProvider<StudyQuizRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null || !ref.mounted ? null : StudyQuizRepository(db);
});
final studyAttemptRepositoryProvider = FutureProvider<StudyAttemptRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  return db == null || !ref.mounted ? null : StudyAttemptRepository(db);
});

// Signed-out reads remain unavailable rather than resembling a loaded empty list.
final studyNotebooksProvider = StreamProvider.autoDispose<List<StudyNotebook>>((
  ref,
) async* {
  final repo = await ref.watch(notebookRepositoryProvider.future);
  if (repo == null || !ref.mounted)
    throw StateError('No verified account database');
  yield* repo.watchAll();
});
final studySourcesProvider = StreamProvider.autoDispose
    .family<List<StudySource>, String>((ref, id) async* {
      final repo = await ref.watch(notebookSourceRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watch(id);
    });
final studyChatsProvider = StreamProvider.autoDispose
    .family<List<StudyChat>, String>((ref, id) async* {
      final repo = await ref.watch(studyChatRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watch(id);
    });
final studyMessagesProvider = StreamProvider.autoDispose
    .family<List<StudyMessage>, String>((ref, id) async* {
      final repo = await ref.watch(studyChatRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watchMessages(id);
    });
final studySummaryProvider = StreamProvider.autoDispose
    .family<StudySummary?, String>((ref, id) async* {
      final repo = await ref.watch(studySummaryRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watch(id);
    });
final studyDecksProvider = StreamProvider.autoDispose
    .family<List<StudyDeck>, String>((ref, id) async* {
      final repo = await ref.watch(studyDeckRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watch(id);
    });
final studyCardsProvider = StreamProvider.autoDispose
    .family<List<StudyCard>, String>((ref, id) async* {
      final repo = await ref.watch(studyDeckRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watchCards(id);
    });
final studyQuizzesProvider = StreamProvider.autoDispose
    .family<List<StudyQuiz>, String>((ref, id) async* {
      final repo = await ref.watch(studyQuizRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watch(id);
    });
final studyQuestionsProvider = StreamProvider.autoDispose
    .family<List<StudyQuestion>, String>((ref, id) async* {
      final repo = await ref.watch(studyQuizRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watchQuestions(id);
    });
final studyAttemptsProvider = StreamProvider.autoDispose
    .family<List<StudyAttempt>, String>((ref, id) async* {
      final repo = await ref.watch(studyAttemptRepositoryProvider.future);
      if (repo == null || !ref.mounted)
        throw StateError('No verified account database');
      yield* repo.watch(id);
    });
