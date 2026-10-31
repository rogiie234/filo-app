import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/ai_cancellation.dart';
import '../../../core/ai/ai_request_guard.dart';
import '../domain/study_ai.dart';
import '../domain/study_inputs.dart';

typedef StudyAiInvoke = Future<dynamic> Function(
  String function,
  Map<String, dynamic> body,
  Future<void> abortSignal,
);

class StudentAiClient {
  StudentAiClient({
    required this.invoke,
    required this.loadSources,
    required this.isOnline,
    required this.currentAccount,
    required this.guard,
    bool Function()? sessionExpired,
    this.timeout = const Duration(seconds: 60),
  }) : sessionExpired = sessionExpired ?? (() => false);

  final StudyAiInvoke invoke;
  final Future<List<StudyAiSource>> Function(String notebookId) loadSources;
  final bool Function() isOnline, sessionExpired;
  final String? Function() currentAccount;
  final AiRequestGuard guard;
  final Duration timeout;
  AiCancelToken? _active;

  void cancelActive() => _active?.cancel();

  Future<StudyAiResult<StudyTextAnswer>> chat({
    required List<StudyChatInput> messages,
    String? notebookId,
    required AiCancelToken cancel,
    Future<void> Function(PreparedStudySources, AiCancelToken)? beforeDispatch,
  }) => _text(
    messages: messages,
    notebookId: notebookId,
    summary: false,
    cancel: cancel,
    beforeDispatch: beforeDispatch,
  );

  Future<StudyAiResult<StudyTextAnswer>> summary({
    required String notebookId,
    required AiCancelToken cancel,
  }) => _text(
    messages: const [],
    notebookId: notebookId,
    summary: true,
    cancel: cancel,
  );

  Future<StudyAiResult<StudyTextAnswer>> _text({
    required List<StudyChatInput> messages,
    required String? notebookId,
    required bool summary,
    required AiCancelToken cancel,
    Future<void> Function(PreparedStudySources, AiCancelToken)? beforeDispatch,
  }) => _request(
    notebookId,
    cancel,
    (sources) {
      final history = prepareStudyMessages(messages);
      if (!summary && (history.isEmpty || history.last['role'] != 'user')) {
        throw const StudyAiFailure('INVALID_REQUEST');
      }
      if (summary && sources.sources.isEmpty)
        throw const StudyAiFailure('NO_TEXT');
      return {
        'mode': summary ? 'summary' : 'chat',
        'messages': history,
        'sources': sources.sources,
      };
    },
    'ai-chat',
    (data, sources) {
      final (answer, truncated) = decodeStudyText(
        data,
        sources.sources.isNotEmpty,
      );
      return StudyAiResult(answer, sources, serverTruncated: truncated);
    },
    isChat: !summary,
    beforeDispatch: beforeDispatch,
  );

  Future<StudyAiResult<StudyAiBatch<StudyCardInput>>> flashcards({
    String? notebookId,
    required StudyDeckSettings settings,
    required AiCancelToken cancel,
  }) => _request(
    notebookId,
    cancel,
    (sources) {
      try {
        settings.validate();
      } catch (_) {
        throw const StudyAiFailure('INVALID_REQUEST');
      }
      _requireTopic(sources, settings.topicFocus);
      return {'sources': sources.sources, ...settings.toJson()};
    },
    'ai-flashcards',
    (data, sources) =>
        StudyAiResult(decodeStudyCards(data, settings.count), sources),
  );

  Future<StudyAiResult<StudyAiBatch<StudyQuestionInput>>> practiceQuiz({
    String? notebookId,
    required StudyQuizSettings settings,
    required AiCancelToken cancel,
  }) => _request(
    notebookId,
    cancel,
    (sources) {
      try {
        settings.validate();
      } catch (_) {
        throw const StudyAiFailure('INVALID_REQUEST');
      }
      _requireTopic(sources, settings.topicFocus);
      return {'sources': sources.sources, ...settings.toJson()};
    },
    'ai-mock-quiz',
    (data, sources) =>
        StudyAiResult(decodeStudyQuestions(data, settings), sources),
  );

  void _requireTopic(PreparedStudySources sources, String topic) {
    if (sources.sources.isEmpty && topic.trim().isEmpty)
      throw const StudyAiFailure('NO_TEXT');
  }

  Future<StudyAiResult<T>> _request<T>(
    String? notebookId,
    AiCancelToken cancel,
    Map<String, dynamic> Function(PreparedStudySources) bodyFor,
    String function,
    StudyAiResult<T> Function(dynamic, PreparedStudySources) decode, {
    bool isChat = false,
    Future<void> Function(PreparedStudySources, AiCancelToken)? beforeDispatch,
  }) async {
    PreparedStudySources? prepared;
    AiCancelToken? owned;
    try {
      cancel.check();
      if (!isOnline()) throw const StudyAiFailure('OFFLINE');
      if (sessionExpired()) throw const StudyAiFailure('AUTH');
      final account = currentAccount();
      if (account == null) throw const StudyAiFailure('NOT_ALLOWED');
      return await guard.run(cancel, (operation) async {
        owned = operation;
        _active = operation;
        List<StudyAiSource> selected;
        try {
          selected = notebookId == null
              ? <StudyAiSource>[]
              : await operation.wait(loadSources(notebookId));
        } on AiCancelled {
          rethrow;
        } on StudyAiFailure {
          rethrow;
        } catch (_) {
          _checkAccount(account, operation);
          throw const StudyAiFailure('LOAD_FAILED');
        }
        _checkAccount(account, operation);
        final sources = prepareStudySources(selected);
        prepared = sources;
        final body = bodyFor(sources);
        if (utf8.encode(jsonEncode(body)).length > 524288)
          throw const StudyAiFailure('TOO_LARGE');
        if (isChat) await guard.waitForChat(operation);
        _checkAccount(account, operation);
        if (!isOnline()) throw const StudyAiFailure('OFFLINE');
        // Commit the question against these exact source prefixes before transport.
        if (beforeDispatch != null)
          await operation.wait(beforeDispatch(sources, operation));
        _checkAccount(account, operation);
        if (!isOnline()) throw const StudyAiFailure('OFFLINE');
        if (isChat) guard.markChatDispatched();
        dynamic data;
        try {
          data = await operation.wait(
            invoke(function, body, operation.cancelled),
          );
        } catch (_) {
          _checkAccount(account, operation);
          rethrow;
        }
        _checkAccount(account, operation);
        final code = _serverCode(data);
        if (code != null) throw StudyAiFailure(code);
        return decode(data, sources);
      }, timeout: timeout);
    } on StudyAiFailure catch (e) {
      throw StudyAiFailure(e.code, sources: prepared ?? e.sources);
    } on AiRequestInProgress {
      throw const StudyAiFailure('AI_IN_PROGRESS');
    } on AiCancelled {
      throw StudyAiFailure('CANCELLED', sources: prepared);
    } on TimeoutException {
      throw StudyAiFailure('AI_TIMEOUT', sources: prepared);
    } on FunctionException catch (e) {
      final code = _serverCode(e.details);
      throw StudyAiFailure(
        code ?? (e.status == 401 && sessionExpired() ? 'AUTH' : 'UNKNOWN'),
        sources: prepared,
      );
    } catch (_) {
      throw StudyAiFailure('UNKNOWN', sources: prepared);
    } finally {
      if (identical(_active, owned)) _active = null;
    }
  }

  void _checkAccount(String account, AiCancelToken operation) {
    operation.check();
    if (currentAccount() != account) throw const StudyAiFailure('CANCELLED');
    if (sessionExpired()) throw const StudyAiFailure('AUTH');
  }

  String? _serverCode(dynamic data) {
    if (data is! Map || !data.containsKey('error')) return null;
    final error = data['error'];
    final code = error is Map ? error['code'] : null;
    const codes = {
      'NOT_ALLOWED',
      'INVALID_REQUEST',
      'NO_TEXT',
      'TOO_LARGE',
      'AI_IN_PROGRESS',
      'AI_BUSY',
      'AI_TIMEOUT',
      'AI_BAD_OUTPUT',
      'AI_UNAVAILABLE',
      'AI_BLOCKED',
    };
    return code is String && codes.contains(code) ? code : 'UNKNOWN';
  }
}
