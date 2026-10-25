import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../domain/results.dart';
import 'results_cache.dart';
import 'results_failure.dart';
import 'results_remote.dart';

class StudentResultsRepository {
  StudentResultsRepository(this.cache, this.remote, this.online);
  final ResultsCache cache;
  final ResultsRemote remote;
  final bool Function() online;
  final Map<String, Future<StudentResultData>> _refreshes = {};

  Future<StudentResultData?> cached(String quizId) => cache.student(quizId);

  Future<StudentResultData> refresh(String quizId) => _refreshes.putIfAbsent(
    quizId,
    () => _refresh(quizId).whenComplete(() {
      _refreshes.remove(quizId);
    }),
  );

  Future<StudentResultData> _refresh(String quizId) async {
    cache.checkAccount();
    if (!online()) throw ResultsFailure(resultsOffline(ResultsAction.load));
    try {
      final quiz = await remote.quiz(quizId, instructor: false);
      await cache.authorize(quiz['class_id'] as String, instructor: false);
      final raw = await remote.mySession(quizId);
      cache.checkAccount();
      final candidate = raw == null ? null : ResultSession(raw);
      final session = candidate?.voided == true ? null : candidate;
      // Invalidate previous eligibility before a possibly failing result request.
      final old = await cache.read('student:$quizId', instructor: false);
      if (old?['session'] != null) {
        final previous = ResultSession(resultJson(old!['session']));
        if (previous.id != session?.id || session?.released != true) {
          await cache.saveStudent(quiz, session, null);
        }
      }
      ReleasedResult? result;
      if (session != null && session.released && session.submitted) {
        result = ReleasedResult.fromJson(await remote.result(session.id));
      }
      await cache.authorize(quiz['class_id'] as String, instructor: false);
      await cache.saveStudent(quiz, session, result);
      return StudentResultData(quiz, session, result);
    } catch (e) {
      final failure = resultsFailure(e, ResultsAction.load);
      if (e is PostgrestException &&
          e.message == 'Results are not available yet') {
        final old = await cache.read('student:$quizId', instructor: false);
        if (old != null && old['session'] != null) {
          final session = resultJson(old['session'])
            ..['results_released'] = false;
          await cache.saveStudent(
            resultJson(old['quiz']),
            ResultSession(session),
            null,
          );
        }
      }
      if (failure.unavailable) {
        final old = await cache.read('student:$quizId', instructor: false);
        if (old != null) {
          final session = old['session'];
          if (session != null)
            await cache.removeResult(ResultSession(resultJson(session)).id);
          await cache.remove('student:$quizId');
        }
      }
      cache.checkAccount();
      throw failure;
    }
  }
}
