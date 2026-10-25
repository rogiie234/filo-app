import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/database_providers.dart';
import '../data/instructor_results_repository.dart';
import '../data/results_cache.dart';
import '../data/results_failure.dart';
import '../data/results_remote.dart';
import '../data/student_results_repository.dart';
import '../domain/results.dart';

final resultsCacheProvider = FutureProvider<ResultsCache?>((ref) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  final userId = await ref.watch(verifiedUserIdProvider.future);
  final client = ref.watch(supabaseClientProvider);
  if (db == null || userId == null || !ref.mounted) return null;
  return ResultsCache(
    db,
    userId,
    () =>
        ref.mounted &&
        client.auth.currentUser?.id == userId &&
        ref.read(verifiedUserIdProvider).asData?.value == userId,
  );
});

final studentResultsRepositoryProvider =
    FutureProvider<StudentResultsRepository?>((ref) async {
      final cache = await ref.watch(resultsCacheProvider.future);
      return cache == null
          ? null
          : StudentResultsRepository(
              cache,
              SupabaseResultsRemote(
                ref.watch(supabaseClientProvider),
                cache.userId,
              ),
              () => ref.read(connectivityProvider).asData?.value == true,
            );
    });

final instructorResultsRepositoryProvider =
    FutureProvider<InstructorResultsRepository?>((ref) async {
      final cache = await ref.watch(resultsCacheProvider.future);
      return cache == null
          ? null
          : InstructorResultsRepository(
              cache,
              SupabaseResultsRemote(
                ref.watch(supabaseClientProvider),
                cache.userId,
              ),
              () => ref.read(connectivityProvider).asData?.value == true,
            );
    });

Stream<ResultsState<T>> _feed<T>({
  required ResultsCache cache,
  required bool online,
  required Future<T?> Function() cached,
  required Future<T> Function() refresh,
  required Future<bool> Function(T) readOnly,
}) async* {
  T? data;
  String? error;
  try {
    data = await cached();
    error = !online && data == null ? resultsOffline(ResultsAction.load) : null;
    yield ResultsState(
      data: data,
      cached: data != null,
      refreshing: online,
      readOnly: data == null || await readOnly(data),
      error: error,
    );
  } catch (e) {
    yield ResultsState(error: resultsFailure(e, ResultsAction.load).message);
    return;
  }
  if (online) {
    try {
      data = await refresh();
    } catch (e) {
      error = resultsFailure(e, ResultsAction.load).message;
      // Re-read after eviction; never retain an unauthorized prior emission.
      try {
        data = await cached();
      } catch (_) {
        data = null;
      }
    }
    yield ResultsState(
      data: data,
      cached: error != null && data != null,
      readOnly: data == null || await readOnly(data),
      error: error,
    );
  }
  await for (final _ in cache.changes) {
    try {
      data = await cached();
      yield ResultsState(
        data: data,
        cached: true,
        readOnly: data == null || await readOnly(data),
        error: error,
      );
    } catch (e) {
      yield ResultsState(error: resultsFailure(e, ResultsAction.load).message);
    }
  }
}

final studentResultProvider = StreamProvider.autoDispose
    .family<ResultsState<StudentResultData>, String>((ref, quizId) async* {
      final online = ref.watch(connectivityProvider).asData?.value == true;
      final repo = await ref.watch(studentResultsRepositoryProvider.future);
      if (repo == null) {
        yield const ResultsState(error: 'Sign in to continue.');
        return;
      }
      yield* _feed(
        cache: repo.cache,
        online: online,
        cached: () => repo.cached(quizId),
        refresh: () => repo.refresh(quizId),
        readOnly: (_) async => true,
      );
    });

final quizMonitoringProvider = StreamProvider.autoDispose
    .family<ResultsState<QuizMonitoring>, String>((ref, quizId) async* {
      final online = ref.watch(connectivityProvider).asData?.value == true;
      final repo = await ref.watch(instructorResultsRepositoryProvider.future);
      if (repo == null) {
        yield const ResultsState(error: 'Sign in to continue.');
        return;
      }
      yield* _feed(
        cache: repo.cache,
        online: online,
        cached: () => repo.cachedQuiz(quizId),
        refresh: () => repo.refreshQuiz(quizId),
        readOnly: (data) async =>
            await repo.readOnly(data.quiz['class_id'] as String) ||
            (data.quiz['class'] as Map?)?['archived_at'] != null ||
            await repo.cache.read('uncertain:$quizId', instructor: true) !=
                null,
      );
    });

typedef ResultAttemptKey = ({String quizId, String sessionId});
final resultAttemptProvider = StreamProvider.autoDispose
    .family<ResultsState<AttemptDetail>, ResultAttemptKey>((ref, key) async* {
      final online = ref.watch(connectivityProvider).asData?.value == true;
      final repo = await ref.watch(instructorResultsRepositoryProvider.future);
      if (repo == null) {
        yield const ResultsState(error: 'Sign in to continue.');
        return;
      }
      yield* _feed(
        cache: repo.cache,
        online: online,
        cached: () => repo.cachedDetail(key.quizId, key.sessionId),
        refresh: () => repo.refreshDetail(key.quizId, key.sessionId),
        readOnly: (data) async =>
            data.readOnly ||
            await repo.readOnly(data.quiz['class_id'] as String) ||
            (data.quiz['class'] as Map?)?['archived_at'] != null ||
            await repo.cache.read(
                  'uncertain:${key.quizId}',
                  instructor: true,
                ) !=
                null,
      );
    });

final resultsActiveMembersProvider = StreamProvider.autoDispose
    .family<ResultsState<List<ResultJson>>, String>((ref, classId) async* {
      final online = ref.watch(connectivityProvider).asData?.value == true;
      final repo = await ref.watch(instructorResultsRepositoryProvider.future);
      if (repo == null) {
        yield const ResultsState(error: 'Sign in to continue.');
        return;
      }
      yield* _feed(
        cache: repo.cache,
        online: online,
        cached: () => repo.cachedMembers(classId),
        refresh: () => repo.refreshMembers(classId),
        readOnly: (_) => repo.readOnly(classId),
      );
    });

ResultsState<List<T>> _list<T>(
  ResultsState<QuizMonitoring> state,
  List<T> Function(QuizMonitoring) select, {
  bool history = false,
}) => ResultsState(
  data: state.data == null ? null : select(state.data!),
  cached: state.cached,
  refreshing: state.refreshing,
  readOnly: history || state.readOnly,
  error: state.error,
);

final quizResultSessionsProvider = Provider.autoDispose
    .family<AsyncValue<ResultsState<List<ResultSession>>>, String>(
      (ref, quizId) => ref
          .watch(quizMonitoringProvider(quizId))
          .whenData((state) => _list(state, (data) => data.current)),
    );
final quizResultHistoryProvider = Provider.autoDispose
    .family<AsyncValue<ResultsState<List<ResultSession>>>, String>(
      (ref, quizId) => ref
          .watch(quizMonitoringProvider(quizId))
          .whenData(
            (state) => _list(state, (data) => data.history, history: true),
          ),
    );
final quizSecondChancesProvider = Provider.autoDispose
    .family<AsyncValue<ResultsState<List<ResultJson>>>, String>(
      (ref, quizId) => ref
          .watch(quizMonitoringProvider(quizId))
          .whenData((state) => _list(state, (data) => data.secondChances)),
    );
