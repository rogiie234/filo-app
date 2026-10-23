import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/database_providers.dart';
import '../data/exam_remote.dart';
import '../data/exam_store.dart';
import '../domain/exam.dart';
import 'student_exam_repository.dart';

final studentExamRepositoryProvider = FutureProvider<StudentExamRepository?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  final userId = await ref.watch(verifiedUserIdProvider.future);
  final client = ref.watch(supabaseClientProvider);
  if (db == null || userId == null || !ref.mounted) return null;
  final repository = StudentExamRepository(
    store: ExamStore(db),
    remote: SupabaseExamRemote(client, userId),
    isCurrent: () =>
        ref.mounted &&
        client.auth.currentUser?.id == userId &&
        ref.read(verifiedUserIdProvider).asData?.value == userId,
    online: () => ref.read(connectivityProvider).asData?.value == true,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final studentQuizzesProvider = FutureProvider.autoDispose<List<StudentQuiz>>((
  ref,
) async {
  final repository = await ref.watch(studentExamRepositoryProvider.future);
  return repository == null ? [] : repository.quizzes();
});
final studentExamSessionProvider = FutureProvider.autoDispose
    .family<ExamSession?, String>((ref, quizId) async {
      final repository = await ref.watch(studentExamRepositoryProvider.future);
      return repository?.status(quizId);
    });

final examUpdatesProvider = StreamProvider.autoDispose<int>((ref) async* {
  final repository = await ref.watch(studentExamRepositoryProvider.future);
  if (repository == null) return;
  yield 0;
  yield* repository.changes;
});
final activeExamProvider = Provider.autoDispose<ExamAttempt?>((ref) {
  ref.watch(examUpdatesProvider);
  return ref.watch(studentExamRepositoryProvider).asData?.value?.active;
});
final examAnswersProvider = FutureProvider.autoDispose<List<StoredAnswer>>((
  ref,
) async {
  ref.watch(examUpdatesProvider);
  final repository = await ref.watch(studentExamRepositoryProvider.future);
  return repository == null ? [] : repository.answers();
});
final examCountdownProvider = StreamProvider.autoDispose<Duration>((
  ref,
) async* {
  final repository = await ref.watch(studentExamRepositoryProvider.future);
  if (repository == null) return;
  yield repository.clock.remaining;
  yield* Stream.periodic(
    const Duration(seconds: 1),
    (_) => repository.clock.remaining,
  );
});
final examSavingStateProvider = Provider.autoDispose<String>((ref) {
  ref.watch(examUpdatesProvider);
  final answers = ref.watch(examAnswersProvider);
  final repository = ref.watch(studentExamRepositoryProvider).asData?.value;
  if (repository?.error != null) return repository!.error!.message;
  if (repository?.saver?.error != null)
    return repository!.saver!.error!.message;
  if (answers.asData == null) return 'Saving...';
  if (answers.asData!.value.every((answer) => answer.sent)) return 'Saved';
  return ref.watch(connectivityProvider).asData?.value == true
      ? 'Saving...'
      : 'Reconnecting...';
});

/// Mounted by the signed-in home; discovery does not navigate to unfinished UI.
final examLifecycleProvider = Provider.autoDispose<void>((ref) {
  final future = ref.watch(studentExamRepositoryProvider.future);
  var disposed = false, left = false;
  Future<void> recover() async {
    try {
      final repository = await future;
      if (!disposed) await repository?.recover();
    } catch (_) {
      /* Repository/provider retains the retryable failure. */
    }
  }

  Future<void> leave() async {
    if (left) return;
    left = true;
    try {
      final repository = await future;
      if (!disposed) await repository?.logLeave();
    } catch (_) {
      /* No departure popup; pending queue retries through sync. */
    }
  }

  ref.listen(connectivityProvider, (_, next) {
    if (next.asData?.value == true) unawaited(recover());
  });
  final listener = AppLifecycleListener(
    onResume: () {
      left = false;
      unawaited(recover());
    },
    onHide: () => unawaited(leave()),
    onPause: () => unawaited(leave()),
  );
  final timer = Timer.periodic(const Duration(seconds: 15), (_) {
    unawaited(() async {
      try {
        final repository = await future;
        if (!disposed &&
            repository != null &&
            (repository.error != null ||
                repository.active != null && !repository.clock.canEdit))
          await recover();
      } catch (_) {
        /* Provider errors remain visible to consumers. */
      }
    }());
  });
  unawaited(recover());
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    listener.dispose();
  });
});
