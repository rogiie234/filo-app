import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/results.dart';
import 'results_failure.dart';

abstract interface class ResultsRemote {
  Future<ResultJson> quiz(String quizId, {required bool instructor});
  Future<ResultJson?> mySession(String quizId);
  Future<ResultJson> result(String sessionId);
  Future<ResultJson> monitoring(ResultJson quiz);
  Future<ResultJson> detail(ResultJson quiz, String sessionId);
  Future<List<ResultJson>> members(String classId);
  Future<void> write(String function, ResultJson parameters);
  Future<void> extendClosing(String quizId, DateTime closesAt);
}

class SupabaseResultsRemote implements ResultsRemote {
  SupabaseResultsRemote(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  static const _timeout = Duration(seconds: 20);

  Future<List<ResultJson>> _pages(
    PostgrestFilterBuilder<List<ResultJson>> query,
  ) async {
    final all = <ResultJson>[];
    String? after;
    while (true) {
      final page = await (after == null ? query : query.gt('id', after))
          .order('id', ascending: true)
          .limit(200)
          .timeout(_timeout);
      if (page.isEmpty) return all;
      all.addAll(page);
      after = page.last['id'] as String;
    }
  }

  @override
  Future<ResultJson> quiz(String quizId, {required bool instructor}) async {
    final quiz = await client
        .from('quizzes')
        .select('*,class:classes!inner(owner_id,archived_at,deleted_at)')
        .eq('id', quizId)
        .isFilter('deleted_at', null)
        .maybeSingle()
        .timeout(_timeout);
    if (quiz == null) throw resultsUnavailable;
    final room = resultJson(quiz['class']);
    if (room['deleted_at'] != null ||
        (instructor && room['owner_id'] != userId)) {
      throw resultsUnavailable;
    }
    if (!instructor) {
      final member = await client
          .from('class_members')
          .select('id')
          .eq('class_id', quiz['class_id'])
          .eq('student_id', userId)
          .eq('status', 'active')
          .maybeSingle()
          .timeout(_timeout);
      if (member == null) throw resultsUnavailable;
    }
    return quiz;
  }

  @override
  Future<ResultJson?> mySession(String quizId) async {
    final raw = await client
        .rpc('get_my_session', params: {'p_quiz': quizId})
        .timeout(_timeout);
    return raw == null ? null : resultJson(raw);
  }

  @override
  Future<ResultJson> result(String sessionId) async => resultJson(
    await client
        .rpc('get_result', params: {'p_session': sessionId})
        .timeout(_timeout),
  );

  @override
  Future<List<ResultJson>> members(String classId) async {
    final room = await client
        .from('classes')
        .select('owner_id,deleted_at')
        .eq('id', classId)
        .maybeSingle()
        .timeout(_timeout);
    if (room == null ||
        room['owner_id'] != userId ||
        room['deleted_at'] != null) {
      throw resultsUnavailable;
    }
    return _pages(
      client
          .from('class_members')
          .select(
            '*,profile:profiles!class_members_student_id_fkey(id,display_name,avatar_path)',
          )
          .eq('class_id', classId)
          .eq('status', 'active'),
    );
  }

  @override
  Future<ResultJson> monitoring(ResultJson quiz) async {
    final sessions = await _pages(
      client
          .from('exam_sessions')
          .select(
            '*,profile:profiles!exam_sessions_student_id_fkey(id,display_name,avatar_path)',
          )
          .eq('quiz_id', quiz['id']),
    );
    final roster = await members(quiz['class_id'] as String);
    final chances = await _pages(
      client.from('second_chances').select().eq('quiz_id', quiz['id']),
    );
    final essays = await _pages(
      client
          .from('exam_answers')
          .select(
            'id,session_id,text_answer,points_awarded,questions!inner(type),exam_sessions!inner(quiz_id,status)',
          )
          .eq('questions.type', 'essay')
          .eq('exam_sessions.quiz_id', quiz['id'])
          .inFilter('exam_sessions.status', ['submitted', 'auto_submitted']),
    );
    return {
      'quiz': quiz,
      'sessions': sessions,
      'members': roster,
      'second_chances': chances,
      'essay_answers': essays,
    };
  }

  @override
  Future<ResultJson> detail(ResultJson quiz, String sessionId) async {
    final session = await client
        .from('exam_sessions')
        .select(
          '*,profile:profiles!exam_sessions_student_id_fkey(id,display_name,avatar_path)',
        )
        .eq('id', sessionId)
        .eq('quiz_id', quiz['id'])
        .maybeSingle()
        .timeout(_timeout);
    if (session == null) throw resultsUnavailable;
    final questions = await _pages(
      client
          .from('questions')
          .select('*,question_options(*),answer_keys(*)')
          .eq('quiz_id', quiz['id']),
    );
    final answers = await _pages(
      client.from('exam_answers').select().eq('session_id', sessionId),
    );
    final byQuestion = {for (final a in answers) a['question_id']: a};
    final byId = {for (final q in questions) q['id']: q};
    final ordered = <ResultJson>[];
    for (final id in session['question_order'] as List) {
      final q = byId[id];
      if (q == null) throw const FormatException('Attempt question is missing');
      final options = resultRows(q['question_options']);
      final optionIds = (session['option_orders'] as Map)[id] as List?;
      options.sort(
        (a, b) => optionIds == null
            ? (a['position'] as int).compareTo(b['position'] as int)
            : optionIds.indexOf(a['id']).compareTo(optionIds.indexOf(b['id'])),
      );
      ordered.add({
        ...q,
        'question_options': options,
        'answer': byQuestion[id],
      });
    }
    return {'quiz': quiz, 'session': session, 'questions': ordered};
  }

  @override
  Future<void> write(String function, ResultJson parameters) async {
    await client.rpc(function, params: parameters).timeout(_timeout);
  }

  @override
  Future<void> extendClosing(String quizId, DateTime closesAt) async {
    final row = await client
        .from('quizzes')
        .update({'closes_at': closesAt.toUtc().toIso8601String()})
        .eq('id', quizId)
        .select('id')
        .single()
        .timeout(_timeout);
    if (row['id'] != quizId) throw resultsUncertain;
  }

  Future<List<ResultJson>> classQuizzes(String classId) => _pages(
    client
        .from('quizzes')
        .select()
        .eq('class_id', classId)
        .eq('status', 'published')
        .isFilter('deleted_at', null),
  );

  Future<List<ResultJson>> classAttempts(String classId) => _pages(
    client
        .from('exam_sessions')
        .select('*,quizzes!inner(class_id,deleted_at)')
        .eq('quizzes.class_id', classId)
        .isFilter('quizzes.deleted_at', null)
        .neq('status', 'voided'),
  );
}
