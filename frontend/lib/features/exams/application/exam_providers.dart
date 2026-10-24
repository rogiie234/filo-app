import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/database_providers.dart';
import '../../classes/application/class_providers.dart';
import '../data/exam_remote.dart';
import '../data/exam_store.dart';
import '../domain/exam.dart';
import 'student_exam_repository.dart';
import 'exam_screen_security.dart';

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
    protectScreen: ExamScreenSecurity.protect,
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

final _examCatalogIdentityProvider = Provider.autoDispose((ref) {
  ref.watch(examUpdatesProvider);
  final repository = ref.watch(studentExamRepositoryProvider).asData?.value;
  return (
    repository?.active?.sessionId,
    repository?.active?.deadline,
    repository?.completion,
  );
});

// Class/profile cache writes often rebuild cards without changing access.
final studentQuizAccessSignatureProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(
    classCardsProvider.select((cards) {
      final rooms = cards.value;
      if (rooms == null) return null;
      final access =
          rooms
              .map((room) => '${room.id}:${room.pending}:${room.archived}')
              .toList()
            ..sort();
      return access.join('|');
    }),
  );
});

final studentQuizCatalogProvider =
    StreamProvider.autoDispose<StudentQuizCatalog>((ref) async* {
      ref.watch(connectivityProvider);
      final access = ref.watch(studentQuizAccessSignatureProvider);
      ref.watch(_examCatalogIdentityProvider);
      final repository = await ref.watch(studentExamRepositoryProvider.future);
      if (repository == null) {
        yield const StudentQuizCatalog([]);
        return;
      }
      final cached = await repository.cachedCatalog();
      yield StudentQuizCatalog(
        cached.quizzes,
        loaded: cached.loaded,
        refreshing:
            access != null &&
            ref.read(connectivityProvider).asData?.value == true,
      );
      if (access != null) yield await repository.refreshCatalog();
    });

/// Foreground pages update at schedule boundaries; resume also reconciles data.
final studentQuizNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final quizzes =
      ref.watch(studentQuizCatalogProvider).value?.quizzes ?? <StudentQuiz>[];
  Timer? timer;
  final controller = StreamController<DateTime>();
  void update() {
    timer?.cancel();
    final now = DateTime.now().toUtc();
    controller.add(now);
    var delay = const Duration(minutes: 1);
    for (final quiz in quizzes) {
      for (final boundary in [
        quiz.opensAt,
        quiz.closesAt,
        quiz.session?.deadline,
      ]) {
        if (boundary == null || !boundary.isAfter(now)) continue;
        final remaining =
            boundary.difference(now) + const Duration(milliseconds: 1);
        if (remaining < delay) delay = remaining;
      }
    }
    timer = Timer(delay, update);
  }

  controller.onListen = update;
  final listener = AppLifecycleListener(
    onResume: () {
      ref.invalidate(studentQuizCatalogProvider);
      update();
    },
  );
  ref.onDispose(() {
    listener.dispose();
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

class StudentExamHandoff {
  const StudentExamHandoff({required this.quizId, this.sessionId});
  final String quizId;
  final String? sessionId;
}

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
  final failure = repository?.saver?.error ?? repository?.error;
  if (failure?.retryable == true || failure?.connection == true) {
    return 'Reconnecting...';
  }
  if (failure != null) return 'Saving...';
  if (answers.asData == null) return 'Saving...';
  if (answers.asData!.value.every((answer) => answer.sent)) return 'Saved';
  return ref.watch(connectivityProvider).asData?.value == true
      ? 'Saving...'
      : 'Reconnecting...';
});

/// Mounted once by the signed-in home; production navigation observes recovery.
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
                repository.startUncertain ||
                repository.pendingSessionId != null ||
                repository.active != null && !repository.clock.canEdit)) {
          await recover();
        }
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
