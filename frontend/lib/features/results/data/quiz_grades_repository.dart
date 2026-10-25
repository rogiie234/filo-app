import '../domain/results.dart';
import 'results_cache.dart';
import 'results_failure.dart';
import 'results_remote.dart';
import 'student_results_repository.dart';

class QuizGradesRepository {
  QuizGradesRepository(this.cache, this.remote);
  final ResultsCache cache;
  final SupabaseResultsRemote remote;

  Future<ResultJson?> read(String classId, {required bool instructor}) =>
      cache.read('grades:$classId', instructor: instructor);

  Future<void> refresh(String classId) async {
    final profile = await cache.db.readProfile(cache.userId);
    final instructor = profile?.role == 'instructor';
    await cache.authorize(classId, instructor: instructor);
    try {
      final room = await remote.client
          .from('classes')
          .select('owner_id,deleted_at')
          .eq('id', classId)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (room == null ||
          room['deleted_at'] != null ||
          instructor && room['owner_id'] != cache.userId)
        throw resultsUnavailable;
      if (!instructor) {
        final membership = await remote.client
            .from('class_members')
            .select('id')
            .eq('class_id', classId)
            .eq('student_id', cache.userId)
            .eq('status', 'active')
            .maybeSingle()
            .timeout(const Duration(seconds: 20));
        if (membership == null) throw resultsUnavailable;
      }
      final quizzes = await remote.classQuizzes(classId);
      final attempts = <ResultJson>[];
      final resolved = <ResultJson>[];
      if (instructor) {
        attempts.addAll(await remote.classAttempts(classId));
        resolved.addAll(quizzes);
      } else {
        final student = StudentResultsRepository(cache, remote, () => true);
        for (final quiz in quizzes) {
          final data = await student.refresh(quiz['id'] as String);
          resolved.add(data.quiz);
          final session = data.session;
          if (session != null)
            attempts.add({
              ...session.json,
              'id': session.id,
              'quiz_id': quiz['id'],
              'student_id': cache.userId,
              'total_score': data.result?.score,
              'grading_complete': data.result != null,
              'passed': data.result?.passed,
              'percent': data.result?.percent,
            });
        }
      }
      await cache.authorize(classId, instructor: instructor);
      await cache.put('grades:$classId', classId, {
        'quizzes': resolved,
        'quiz_attempts': attempts,
      });
    } catch (e) {
      final failure = resultsFailure(e, ResultsAction.load);
      if (failure.unavailable) await cache.evictClass(classId);
      throw failure;
    }
  }
}
