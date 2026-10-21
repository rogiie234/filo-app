import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../data/local/app_database.dart';
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
      if (ref.watch(connectivityProvider).asData?.value != true) {
        throw StateError("You're offline. Connect to refresh classwork.");
      }
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

/// Classwork needs a durable confirmation even when a successful post pull is
/// empty. Keep this marker separate from the legacy post repository cursors.
final instructorAssignmentsRefreshProvider = FutureProvider.autoDispose
    .family<void, String>((ref, classId) async {
      if (ref.watch(connectivityProvider).asData?.value != true) {
        throw StateError("You're offline. Connect to refresh classwork.");
      }
      final coordinator = await ref.watch(syncCoordinatorProvider.future);
      if (coordinator == null) throw StateError('Sign in to load classwork.');
      await coordinator.run();
      if (!ref.mounted) return;
      if ([
        'queue',
        'class_access',
        'classes',
        'posts',
        'post_attachments',
      ].any(coordinator.errors.containsKey)) {
        throw StateError(
          'Could not refresh assignments. Saved work is shown when available.',
        );
      }
      final repository = await ref.watch(classRepositoryProvider.future);
      if (repository == null || !ref.mounted) return;
      final db = repository.database;
      final room = await (db.select(
        db.cacheClasses,
      )..where((c) => c.id.equals(classId))).getSingleOrNull();
      if (room == null ||
          room.deletedAt != null ||
          room.ownerId != repository.userId) {
        throw StateError('This class is no longer available.');
      }
      await db
          .into(db.syncState)
          .insertOnConflictUpdate(
            SyncStateCompanion.insert(
              syncedTableName: 'instructor_classwork_posts:$classId',
            ),
          );
    });
