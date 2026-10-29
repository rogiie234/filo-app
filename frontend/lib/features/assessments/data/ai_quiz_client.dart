import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_sources.dart';
import '../domain/quiz_draft.dart';
import 'ai_quiz_response.dart';
import 'lesson_text_extractor.dart';

const aiPrivacyNotice =
    "File text is sent to Google under the free tier's terms. Do not include student names or private data.";
const aiErrorMessages = {
  'AI_BUSY': 'The AI assistant is busy right now. Your work is saved. Please try again in a few minutes, or create questions manually.',
  'AI_IN_PROGRESS':
      'Your last request is still being processed. Try again in a minute.',
  'AI_TIMEOUT': 'The AI request timed out. Please try again.',
  'AI_BAD_OUTPUT':
      'The AI could not produce valid questions. Try different source text.',
  'NO_TEXT': 'No readable text found in this file.',
  'TOO_LARGE': 'The request is too large. Use a smaller text selection.',
  'NOT_ALLOWED': 'You are not allowed to generate questions for this quiz.',
  'INVALID_REQUEST': 'Check the question counts and request settings.',
  'AI_UNAVAILABLE': 'The AI assistant is unavailable. Please try again later.',
  'AUTH': 'Your session has expired. Sign in again to generate questions.',
  'OFFLINE': "You're offline. Connect to the internet to generate questions, or create questions manually.",
  'CANCELLED': 'Generation cancelled. The server may still finish. A quick retry may be refused.',
  'UNKNOWN': 'Generation could not be confirmed. Wait before trying again, or create questions manually.',
};

class AiFailure implements Exception {
  const AiFailure(this.code);
  final String code;
  String get message => aiErrorMessages[code] ?? aiErrorMessages['UNKNOWN']!;
  @override
  String toString() => message;
}

String aiFriendlyError(Object error) => error is AiFailure
    ? error.message
    : error is AiCancelled
    ? aiErrorMessages['CANCELLED']!
    : error is LessonReadException
    ? error.message
    : aiErrorMessages['UNKNOWN']!;

class AiGeneratedBatch {
  const AiGeneratedBatch(
    this.questions,
    this.context,
    this.missing,
    this.dropped,
  );
  final List<QuizQuestion> questions;
  final AiSourceContext context;
  final Map<String, int> missing, dropped;
}

class AiQuizClient {
  AiQuizClient({
    required this.invoke,
    required this.isOnline,
    required this.currentUser,
    this.timeout = const Duration(seconds: 60),
  });
  final Future<dynamic> Function(Map<String, dynamic>) invoke;
  final bool Function() isOnline;
  final String? Function() currentUser;
  final Duration timeout;
  final _waitingUsers = <String>{};

  Future<AiGeneratedBatch> generate({
    required String classId,
    required String quizId,
    required List<Map<String, String>> texts,
    required Map<String, int> counts,
    required AiSourceContext context,
    required AiCancelToken cancel,
    String? regenerateType,
    List<String> currentPrompts = const [],
  }) async {
    cancel.check();
    if (!isOnline()) throw const AiFailure('OFFLINE');
    final user = currentUser();
    if (user == null) throw const AiFailure('AUTH');
    if (_waitingUsers.contains(user)) throw const AiFailure('AI_IN_PROGRESS');
    try {
      LessonTextExtractor.validateSources(texts);
    } on LessonReadException catch (e) {
      throw AiFailure(e.code);
    }
    final total = counts.values.fold<int>(0, (n, v) => n + v);
    if (counts.keys.toSet().difference(aiQuestionTypes.toSet()).isNotEmpty ||
        aiQuestionTypes.any(
          (t) => !counts.containsKey(t) || counts[t]! < 0 || counts[t]! > 20,
        ) ||
        total < 1 ||
        total > 20 ||
        !['easy', 'medium', 'hard'].contains(context.difficulty) ||
        context.topicFocus.runes.length > 200)
      throw const AiFailure('INVALID_REQUEST');
    if (regenerateType != null &&
        (total != 1 ||
            counts[regenerateType] != 1 ||
            currentPrompts.isEmpty ||
            currentPrompts.length > 100 ||
            currentPrompts.any(
              (p) => p.trim().isEmpty || p.runes.length > 1000,
            ) ||
            currentPrompts.fold<int>(0, (n, p) => n + p.runes.length) >
                40000)) {
      throw const AiFailure('INVALID_REQUEST');
    }
    _waitingUsers.add(user);
    try {
      final data = await cancel.wait(
        invoke({
          'class_id': classId,
          'quiz_id': quizId,
          'texts': texts,
          'counts': counts,
          'difficulty': context.difficulty,
          'topic_focus': context.topicFocus,
          if (regenerateType != null) ...{
            'mode': 'regenerate',
            'type': regenerateType,
            'current_prompts': currentPrompts,
          },
        }).timeout(timeout),
      );
      cancel.check();
      if (currentUser() != user) throw const AiFailure('AUTH');
      List<QuizQuestion> questions;
      try {
        questions = decodeAiQuestions(data, counts);
      } catch (_) {
        throw const AiFailure('AI_BAD_OUTPUT');
      }
      for (final q in questions) {
        q.payload['points'] = q.type == 'essay' ? 5 : 1;
      }
      return AiGeneratedBatch(
        questions,
        context,
        Map<String, int>.from(data['missing_by_type'] as Map),
        Map<String, int>.from(data['dropped_by_type'] as Map),
      );
    } on AiFailure {
      rethrow;
    } on AiCancelled {
      throw const AiFailure('CANCELLED');
    } on TimeoutException {
      throw const AiFailure('AI_TIMEOUT');
    } on FunctionException catch (e) {
      final d = e.details;
      final code = d is Map && d['error'] is Map ? d['error']['code'] : null;
      throw AiFailure(
        e.status == 401
            ? 'AUTH'
            : code is String && aiErrorMessages.containsKey(code)
            ? code
            : 'UNKNOWN',
      );
    } catch (_) {
      throw const AiFailure('UNKNOWN');
    } finally {
      _waitingUsers.remove(user);
    }
  }
}
