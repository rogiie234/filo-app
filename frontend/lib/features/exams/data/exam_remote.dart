import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exam.dart';

class ExamFailure implements Exception {
  const ExamFailure(
    this.message, {
    this.retryable = false,
    this.reconcile = false,
  });
  final String message;
  final bool retryable, reconcile;
  @override
  String toString() => message;
}

ExamFailure examFailure(Object error) {
  if (error is ExamFailure) return error;
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is ClientException) {
    return const ExamFailure(
      'Connection lost. Your saved answers will retry when connected.',
      retryable: true,
    );
  }
  if (error is PostgrestException) {
    const messages = {
      'Not signed in': 'Sign in to continue.',
      'OTP verification required': 'Verify your account to continue.',
      'Quiz not found': 'This quiz is unavailable.',
      'This class is archived': 'This class is archived.',
      'This quiz has not opened yet': 'This quiz has not opened yet.',
      'This quiz has closed': 'This quiz has closed.',
      'You have already taken this quiz': 'You have already taken this quiz.',
      'Session not found': "We couldn't find your exam attempt.",
      'This attempt is finished': 'This attempt has ended.',
      'This attempt is closed': 'This attempt is no longer accepting answers.',
      'Class access denied': 'You no longer have access to this exam.',
      'Class is read-only or inaccessible':
          'This class is read-only or unavailable.',
      'Question not found': 'This question is unavailable.',
      'Invalid option': 'This answer option is unavailable.',
      'Answer must be at most 10000 characters':
          'Keep your answer within 10,000 characters.',
      'Results are not available yet': 'Results are not available yet.',
    };
    return ExamFailure(
      messages[error.message] ??
          (error.code == '42501'
              ? "You can't access this exam right now."
              : "We couldn't complete that request. Try again."),
      retryable:
          error.code?.startsWith('08') == true ||
          error.code == '57014' ||
          int.tryParse(error.code ?? '') != null &&
              int.parse(error.code!) >= 500 &&
              int.parse(error.code!) < 600,
      reconcile:
          error.code == '42501' ||
          [
            'Not signed in',
            'Session not found',
            'This attempt is finished',
            'This attempt is closed',
            'Class access denied',
          ].contains(error.message),
    );
  }
  return const ExamFailure("We couldn't complete that request. Try again.");
}

abstract interface class ExamRemote {
  Future<List<ExamJson>> quizzes();
  Future<ExamJson?> session(String quizId);
  Future<ExamJson> start(String quizId);
  Future<ExamJson> exam(String sessionId);
  Future<void> save(String sessionId, ExamAnswer answer);
  Future<ExamJson> submit(String sessionId);
}

class SupabaseExamRemote implements ExamRemote {
  SupabaseExamRemote(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw examFailure(e);
    }
  }

  @override
  Future<List<ExamJson>> quizzes() => _call(() async {
    final memberships = await client
        .from('class_members')
        .select('class_id,classes!inner(id,archived_at,deleted_at)')
        .eq('student_id', userId)
        .eq('status', 'active')
        .isFilter('classes.archived_at', null)
        .isFilter('classes.deleted_at', null);
    final ids = memberships.map((row) => row['class_id'] as String).toList();
    if (ids.isEmpty) return [];
    final rows = await client
        .from('quizzes')
        .select()
        .inFilter('class_id', ids)
        .eq('status', 'published')
        .isFilter('deleted_at', null)
        .order('opens_at');
    return rows.map(ExamJson.from).toList();
  });
  Future<ExamJson> _rpc(String name, ExamJson params) => _call(
    () async => ExamJson.from(await client.rpc(name, params: params) as Map),
  );
  @override
  Future<ExamJson?> session(String quizId) => _call(() async {
    final value = await client.rpc(
      'get_my_session',
      params: {'p_quiz': quizId},
    );
    return value == null ? null : ExamJson.from(value as Map);
  });
  @override
  Future<ExamJson> start(String quizId) =>
      _rpc('start_exam', {'p_quiz': quizId});
  @override
  Future<ExamJson> exam(String sessionId) =>
      _rpc('get_exam', {'p_session': sessionId});
  @override
  Future<void> save(String sessionId, ExamAnswer answer) => _call(() async {
    await client.rpc('save_answer', params: answer.params(sessionId));
  });
  @override
  Future<ExamJson> submit(String sessionId) =>
      _rpc('submit_exam', {'p_session': sessionId});
}
