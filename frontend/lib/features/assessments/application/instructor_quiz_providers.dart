import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../classes/application/class_providers.dart';
import '../data/instructor_quiz_repository.dart';
import '../domain/quiz_draft.dart';

final instructorQuizRepositoryProvider =
    FutureProvider<InstructorQuizRepository?>((ref) async {
      final classes = await ref.watch(classRepositoryProvider.future);
      if (classes == null) return null;
      return InstructorQuizRepository(
        classes.database,
        ref.watch(supabaseClientProvider),
        classes.userId,
        () => ref.read(connectivityProvider).asData?.value ?? false,
      );
    });
final instructorQuizzesProvider = StreamProvider.autoDispose
    .family<List<InstructorQuizSummary>?, String>((ref, classId) async* {
      final repository = await ref.watch(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null) {
        yield null;
        return;
      }
      yield* repository.watchList(classId);
    });
typedef QuizLocation = ({String classId, String quizId});
final instructorQuizProvider = StreamProvider.autoDispose
    .family<InstructorQuiz?, QuizLocation>((ref, key) async* {
      final repository = await ref.watch(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null) {
        yield null;
        return;
      }
      yield* repository.watchQuiz(key.classId, key.quizId);
    });
// Explicit refreshes expose AsyncError without replacing the cached stream.
// Call ref.refresh(provider(key).future) to retry or refresh again.
final instructorQuizListRefreshProvider = FutureProvider.autoDispose
    .family<void, String>((ref, classId) async {
      final repository = await ref.watch(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null) throw StateError('Sign in to load assessments.');
      await repository.refreshList(classId);
    });
final instructorQuizRefreshProvider = FutureProvider.autoDispose
    .family<void, QuizLocation>((ref, key) async {
      final repository = await ref.watch(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null) throw StateError('Sign in to load assessments.');
      await repository.refreshQuiz(key.classId, key.quizId);
    });
