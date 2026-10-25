import 'package:drift/drift.dart';

import '../domain/results.dart';
import 'results_cache.dart';
import 'results_failure.dart';
import 'results_remote.dart';

class InstructorResultsRepository {
  InstructorResultsRepository(this.cache, this.remote, this.online);
  final ResultsCache cache;
  final ResultsRemote remote;
  final bool Function() online;
  final Set<String> _writing = {};
  final Map<String, Future<QuizMonitoring>> _refreshes = {};

  Future<QuizMonitoring?> cachedQuiz(String quizId) async {
    final row = await cache.read('monitor:$quizId', instructor: true);
    return row == null ? null : QuizMonitoring(row);
  }

  Future<AttemptDetail?> cachedDetail(String quizId, String sessionId) async {
    final row = await cache.read('detail:$quizId:$sessionId', instructor: true);
    return row == null ? null : AttemptDetail(row);
  }

  Future<List<ResultJson>?> cachedMembers(String classId) async {
    final row = await cache.read('members:$classId', instructor: true);
    return row == null ? null : resultRows(row['members']);
  }

  Future<bool> readOnly(String classId) async =>
      !online() || await cache.authorize(classId, instructor: true);

  void _connected(ResultsAction action) {
    cache.checkAccount();
    if (!online()) throw ResultsFailure(resultsOffline(action));
  }

  Future<QuizMonitoring> refreshQuiz(String quizId) => _refreshes.putIfAbsent(
    quizId,
    () => _refreshQuiz(quizId).whenComplete(() {
      _refreshes.remove(quizId);
    }),
  );

  Future<QuizMonitoring> _refreshQuiz(String quizId) async {
    _connected(ResultsAction.load);
    try {
      final quiz = await remote.quiz(quizId, instructor: true);
      final classId = quiz['class_id'] as String;
      await cache.authorize(classId, instructor: true);
      final data = QuizMonitoring(await remote.monitoring(quiz));
      // Fully parse sessions before replacing any previously complete snapshot.
      final sessions = data.sessions;
      final details = <String, ResultJson>{};
      final rows = await cache.db
          .customSelect(
            'SELECT id,payload FROM results_snapshots WHERE class_id=?',
            variables: [Variable(classId)],
          )
          .get();
      for (final row in rows) {
        final key = row.read<String>('id');
        if (!key.startsWith('detail:$quizId:')) continue;
        final sessionId = key.substring('detail:$quizId:'.length);
        if (sessions.any((s) => s.id == sessionId)) {
          details[key] = await remote.detail(quiz, sessionId);
        }
      }
      await cache.authorize(classId, instructor: true);
      await cache.db.transaction(() async {
        await cache.put('monitor:$quizId', classId, data.json);
        final gradeSnapshot = await cache.read(
          'grades:$classId',
          instructor: true,
        );
        if (gradeSnapshot != null) {
          await cache.put('grades:$classId', classId, {
            'quizzes': [
              ...resultRows(gradeSnapshot['quizzes'])
                  .where((q) => q['id'] != quizId),
              data.quiz,
            ],
            'quiz_attempts': [
              ...resultRows(gradeSnapshot['quiz_attempts'])
                  .where((a) => a['quiz_id'] != quizId),
              ...data.current.map((s) => s.json),
            ],
          });
        }
        await cache.put('members:$classId', classId, {'members': data.members});
        for (final row in rows) {
          final key = row.read<String>('id');
          if (key.startsWith('detail:$quizId:') && !details.containsKey(key))
            await cache.remove(key);
        }
        for (final entry in details.entries) {
          await cache.put(entry.key, classId, entry.value);
        }
        if (!_writing.contains(quizId)) await cache.remove('uncertain:$quizId');
      });
      cache.notify();
      return data;
    } catch (e) {
      final failure = resultsFailure(e, ResultsAction.load);
      if (failure.unavailable) await _evictQuiz(quizId);
      throw failure;
    }
  }

  Future<void> _evictQuiz(String quizId) async {
    cache.checkAccount();
    final rows = await cache.db
        .customSelect('SELECT id,class_id FROM results_snapshots')
        .get();
    final classes = <String>{};
    for (final row in rows) {
      final key = row.read<String>('id');
      if (key == 'monitor:$quizId' || key.startsWith('detail:$quizId:')) {
        classes.add(row.read<String>('class_id'));
      }
    }
    for (final id in classes) {
      await cache.evictClass(id);
    }
  }

  Future<AttemptDetail> refreshDetail(String quizId, String sessionId) async {
    _connected(ResultsAction.load);
    try {
      final quiz = await remote.quiz(quizId, instructor: true);
      await cache.authorize(quiz['class_id'] as String, instructor: true);
      final detail = AttemptDetail(await remote.detail(quiz, sessionId));
      if (detail.session.id != sessionId ||
          detail.session.json['quiz_id'] != quizId)
        throw resultsUnavailable;
      await cache.authorize(quiz['class_id'] as String, instructor: true);
      await cache.put(
        'detail:$quizId:$sessionId',
        quiz['class_id'] as String,
        detail.json,
      );
      return detail;
    } catch (e) {
      final failure = resultsFailure(e, ResultsAction.load);
      if (failure.unavailable) await _evictQuiz(quizId);
      throw failure;
    }
  }

  Future<List<ResultJson>> refreshMembers(String classId) async {
    _connected(ResultsAction.load);
    try {
      await cache.authorize(classId, instructor: true);
      final rows = await remote.members(classId);
      await cache.authorize(classId, instructor: true);
      await cache.put('members:$classId', classId, {'members': rows});
      return rows;
    } catch (e) {
      final failure = resultsFailure(e, ResultsAction.load);
      if (failure.unavailable) await cache.evictClass(classId);
      throw failure;
    }
  }

  Future<String> _write(
    String quizId,
    ResultsAction action,
    Future<ResultJson> Function(QuizMonitoring) parameters,
    String function,
    String success, {
    Future<void> Function(ResultJson)? dispatch,
  }) async {
    _connected(action);
    if (_writing.contains(quizId))
      throw const ResultsFailure('An update is already in progress.');
    if (await cache.read('uncertain:$quizId', instructor: true) != null)
      throw resultsUncertain;
    // Recheck after awaiting storage so two simultaneous calls cannot both dispatch.
    if (!_writing.add(quizId))
      throw const ResultsFailure('An update is already in progress.');
    var dispatched = false;
    var confirmed = false;
    try {
      final data = await refreshQuiz(quizId);
      final classId = data.quiz['class_id'] as String;
      if (await cache.authorize(classId, instructor: true) ||
          (data.quiz['class'] as Map?)?['archived_at'] != null) {
        throw const ResultsFailure('This class is archived.');
      }
      final params = await parameters(data);
      _connected(action);
      // Persist before dispatch, so restart cannot silently retry an unknown grant.
      await cache.put('uncertain:$quizId', classId, {
        'action': action.name,
        'parameters': params,
      });
      dispatched = true;
      await (dispatch == null
          ? remote.write(function, params)
          : dispatch(params));
      cache.checkAccount();
      confirmed = true;
      final updated = await refreshQuiz(quizId);
      if (action == ResultsAction.release &&
          updated.quiz['results_released_at'] == null) {
        throw resultsUncertain;
      }
      await cache.remove('uncertain:$quizId');
      return success;
    } catch (e) {
      final failure = resultsFailure(
        e,
        dispatched && !confirmed ? action : ResultsAction.load,
      );
      if (dispatched && (confirmed || failure.uncertain)) {
        // Leave the persistent reconciliation marker in place until a complete refresh.
        final data = await cachedQuiz(quizId);
        if (data != null)
          await cache.put(
            'uncertain:$quizId',
            data.quiz['class_id'] as String,
            {'action': action.name},
          );
        throw resultsUncertain;
      }
      if (dispatched) await cache.remove('uncertain:$quizId');
      if (failure.unavailable) await _evictQuiz(quizId);
      throw failure;
    } finally {
      _writing.remove(quizId);
    }
  }

  Future<String> gradeEssay(
    String quizId,
    String sessionId,
    String answerId,
    num points, {
    String? feedback,
  }) => _write(
    quizId,
    ResultsAction.grade,
    (data) async {
      final detail = await refreshDetail(quizId, sessionId);
      if (!detail.session.submitted || detail.readOnly) {
        throw const ResultsFailure('This attempt is not submitted yet.');
      }
      final matches = detail.questions
          .where((q) => (q['answer'] as Map?)?['id'] == answerId)
          .toList();
      if (matches.length != 1 || matches.single['type'] != 'essay')
        throw resultsUnavailable;
      final maximum = matches.single['points'] as int;
      if (!points.isFinite || points != points.roundToDouble()) {
        throw const ResultsFailure('Enter a whole-number score.');
      }
      if (points < 0 || points > maximum)
        throw ResultsFailure('Points must be between 0 and $maximum');
      if (feedback != null && feedback.runes.length > 2000) {
        throw const ResultsFailure(
          'Feedback must be at most 2,000 characters.',
        );
      }
      return {
        'p_answer': answerId,
        'p_points': points.toInt(),
        'p_feedback': feedback,
      };
    },
    'grade_essay',
    'Grade saved.',
  );

  Future<String> overridePoints(
    String quizId,
    String sessionId,
    String questionId,
    num points, {
    String? feedback,
  }) => _write(
    quizId,
    ResultsAction.grade,
    (_) async {
      final detail = await refreshDetail(quizId, sessionId);
      if (!detail.session.submitted || detail.readOnly)
        throw const ResultsFailure('This attempt is not submitted yet.');
      final question = detail.questions
          .where((q) => q['id'] == questionId)
          .firstOrNull;
      if (question == null) throw resultsUnavailable;
      if (!points.isFinite || points != points.roundToDouble())
        throw const ResultsFailure('Enter a whole-number score.');
      if (points < 0 || points > (question['points'] as int))
        throw ResultsFailure(
          'Points must be between 0 and ${question['points']}',
        );
      if (feedback != null && feedback.runes.length > 2000)
        throw const ResultsFailure(
          'Feedback must be at most 2,000 characters.',
        );
      return {
        'p_session': sessionId,
        'p_question': questionId,
        'p_points': points.toInt(),
        'p_feedback': feedback,
      };
    },
    'override_points',
    'Grade saved.',
  );

  Future<String> extendClosing(String quizId, DateTime closesAt) => _write(
    quizId,
    ResultsAction.secondChance,
    (data) async {
      if (data.quiz['results_released_at'] != null)
        throw const ResultsFailure(
          'Results are already released. Create a new quiz instead.',
        );
      final opens = DateTime.tryParse('${data.quiz['opens_at']}');
      if (!closesAt.toUtc().isAfter(DateTime.now().toUtc()) ||
          opens != null && !closesAt.toUtc().isAfter(opens)) {
        throw const ResultsFailure(
          'Choose a closing time in the future, after the opening time.',
        );
      }
      return {'closes_at': closesAt.toUtc().toIso8601String()};
    },
    '',
    'Closing time updated.',
    dispatch: (_) => remote.extendClosing(quizId, closesAt),
  );

  Future<String> releaseResults(String quizId) => _write(
    quizId,
    ResultsAction.release,
    (_) async => {'p_quiz': quizId},
    'release_results',
    'Results released.',
  );

  Future<String> grantSecondChance(
    String quizId,
    String studentId, {
    required String expectedSessionId,
    required String reason,
    String? proof,
  }) => _write(
    quizId,
    ResultsAction.secondChance,
    (data) async {
      final current = data.current
          .where((s) => s.studentId == studentId)
          .toList();
      if (current.length != 1 || current.single.id != expectedSessionId) {
        throw const ResultsFailure('This student has no attempt to reset.');
      }
      final trimmed = reason.trim();
      if (trimmed.runes.length < 10)
        throw const ResultsFailure(
          'Please give a reason of at least 10 characters.',
        );
      if (proof != null && proof.runes.length > 1000) {
        throw const ResultsFailure(
          'Proof note must be at most 1,000 characters.',
        );
      }
      return {
        'p_quiz': quizId,
        'p_student': studentId,
        'p_reason': trimmed,
        'p_proof': proof,
      };
    },
    'grant_second_chance',
    'Another attempt allowed.',
  );
}
