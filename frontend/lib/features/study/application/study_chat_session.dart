import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/ai/ai_cancellation.dart';
import '../../../data/local/app_database.dart';
import '../data/student_ai_client.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';

const studyChatBusyMessage =
    'The AI assistant is busy right now. Your message is saved. Please try again in a few minutes.';
const studyChatSaveMessageError = 'Could not save your message. Try again.';
const studyChatSaveAnswerError =
    'Could not confirm this answer was saved. Keep this screen open and try saving again.';

String trimStudyQuestion(String text) =>
    String.fromCharCodes(text.trim().runes.take(2000));
int chatDaysLeft(DateTime expiresAt, DateTime now) => expiresAt.isAfter(now)
    ? (expiresAt.difference(now).inMilliseconds / Duration.millisecondsPerDay)
          .ceil()
          .clamp(1, 30)
          .toInt()
    : 0;

class StudyChatSession extends ChangeNotifier {
  StudyChatSession({
    required this.notebookId,
    required this.repository,
    required this.client,
    required this.isCurrent,
    required this.isOnline,
  });
  final String notebookId;
  final StudyChatRepository repository;
  final StudentAiClient client;
  final bool Function() isCurrent, isOnline;
  String? chatId, error, requestMode;
  String draft = '';
  List<StudyMessage> messages = [];
  List<String> notices = [];
  StudyTextAnswer? pendingAnswer;
  String? _questionId;
  bool loading = true, working = false, _disposed = false;
  int _epoch = 0;
  AiCancelToken? _cancel;
  bool get _current => !_disposed && isCurrent();
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setDraft(String text) {
    draft = text;
    _changed();
  }

  Future<void> open({String? id, bool latest = false}) async {
    _cancel?.cancel();
    final epoch = ++_epoch;
    loading = true;
    working = false;
    pendingAnswer = null;
    error = null;
    requestMode = null;
    notices = [];
    draft = '';
    messages = [];
    chatId = null;
    _changed();
    try {
      await repository.purgeExpired();
      if (latest) {
        final chats =
            await (repository.db.select(repository.db.chats)
                  ..where((c) => c.notebookId.equals(notebookId))
                  ..orderBy([
                    (c) => OrderingTerm.desc(c.lastMessageAt),
                    (c) => OrderingTerm.asc(c.id),
                  ])
                  ..limit(1))
                .get();
        id = chats.isEmpty ? null : chats.first.id;
      }
      if (id != null) {
        if (await repository.find(notebookId, id) == null)
          throw const StudyAiFailure('LOAD_FAILED');
        final saved = await repository.getMessages(id);
        if (!_current || epoch != _epoch) return;
        chatId = id;
        messages = saved;
        if (saved.isNotEmpty && saved.last.role == 'user')
          draft = saved.last.content;
      }
    } catch (_) {
      if (_current && epoch == _epoch) error = studyAiMessages['LOAD_FAILED'];
    } finally {
      if (_current && epoch == _epoch) {
        loading = false;
        _changed();
      }
    }
  }

  Future<void> send() async {
    if (!_current || working || loading || pendingAnswer != null) return;
    if (!isOnline()) {
      error = studyAiMessages['OFFLINE'];
      _changed();
      return;
    }
    if (client.guard.isBusy) {
      error = studyAiMessages['AI_IN_PROGRESS'];
      _changed();
      return;
    }
    if (client.guard.chatCooldownRemaining > Duration.zero) return;
    final question = trimStudyQuestion(draft);
    if (question.isEmpty) return;
    final shortened = draft.trim().runes.length > 2000;
    draft = question;
    notices = [
      if (shortened) 'Your message was shortened to 2,000 characters.',
    ];
    error = null;
    working = true;
    requestMode = null;
    final epoch = ++_epoch;
    final token = AiCancelToken();
    _cancel = token;
    var saved = false;
    _changed();
    bool valid() => _current && epoch == _epoch && !token.isCancelled;
    try {
      final sourceTable = repository.db.notebookSources;
      final sources =
          await (repository.db.select(sourceTable)
                ..where((s) => s.notebookId.equals(notebookId))
                ..orderBy([
                  (s) => OrderingTerm.asc(s.createdAt),
                  (s) => OrderingTerm.asc(s.id),
                ]))
              .get();
      final history = chatId == null
          ? <StudyMessage>[]
          : await repository.getMessages(chatId!);
      if (!valid()) return;
      final reuse =
          history.isNotEmpty &&
          history.last.role == 'user' &&
          history.last.content == question;
      final inputs = [
        for (final m in history)
          StudyChatInput(role: m.role, content: m.content),
        if (!reuse) StudyChatInput(role: 'user', content: question),
      ];
      final result = await client.chat(
        messages: inputs,
        notebookId: notebookId,
        cancel: token,
        beforeDispatch: (prepared, operation) async {
          void checkPreparing() {
            operation.check();
            if (!valid()) throw const StudyAiFailure('CANCELLED');
          }

          checkPreparing();
          late (String, String) savedIds;
          await repository.db.transaction(() async {
            final latest =
                await (repository.db.select(sourceTable)
                      ..where((s) => s.notebookId.equals(notebookId))
                      ..orderBy([
                        (s) => OrderingTerm.asc(s.createdAt),
                        (s) => OrderingTerm.asc(s.id),
                      ]))
                    .get();
            if (latest.length != sources.length ||
                prepared.usage.length != sources.length ||
                List.generate(
                  sources.length,
                  (i) =>
                      latest[i] != sources[i] ||
                      prepared.usage[i].key != sources[i].sourceKey,
                ).any((changed) => changed)) {
              throw const StudyAiFailure('LOAD_FAILED');
            }
            checkPreparing();
            try {
              savedIds = await repository.saveQuestion(
                notebookId: notebookId,
                chatId: chatId,
                content: question,
                mode: prepared.sources.isEmpty ? 'general' : 'files',
              );
              checkPreparing();
            } on AiCancelled {
              rethrow;
            } on StudyAiFailure {
              rethrow;
            } catch (_) {
              throw const StudyAiFailure('SAVE_FAILED');
            }
          });
          checkPreparing();
          chatId = savedIds.$1;
          _questionId = savedIds.$2;
          saved = true;
          requestMode = prepared.sources.isEmpty ? 'general' : 'files';
          notices.addAll([
            for (final usage in prepared.usage)
              if (usage.truncated)
                'Only the first ${usage.retainedCharacters} characters of ${usage.name} were used.',
          ]);
          messages = await repository.getMessages(chatId!);
          checkPreparing();
          _changed();
        },
      );
      if (!valid()) return;
      if (result.serverTruncated && !result.sources.truncated)
        notices.add('The AI response reports that text was shortened.');
      pendingAnswer = result.value;
      _changed();
      await _saveAnswer(epoch);
    } on StudyAiFailure catch (failure) {
      if (_current && epoch == _epoch)
        error = failure.code == 'AI_BUSY' && saved
            ? studyChatBusyMessage
            : failure.code == 'SAVE_FAILED'
            ? studyChatSaveMessageError
            : failure.code == 'AI_BUSY'
            ? studyAiMessages['AI_UNAVAILABLE']
            : failure.message;
    } catch (_) {
      if (_current && epoch == _epoch) error = studyAiMessages['LOAD_FAILED'];
    } finally {
      token.cancel();
      if (_current && epoch == _epoch) {
        working = false;
        _changed();
      }
    }
  }

  Future<void> _saveAnswer(int epoch) async {
    final answer = pendingAnswer;
    if (answer == null || !_current || epoch != _epoch) return;
    try {
      await repository.saveReply(
        notebookId: notebookId,
        chatId: chatId!,
        questionId: _questionId!,
        content: answer.answer,
        mode: answer.mode,
      );
      if (!_current || epoch != _epoch) return;
      messages = await repository.getMessages(chatId!);
      if (!_current || epoch != _epoch) return;
      pendingAnswer = null;
      draft = '';
      error = null;
    } catch (_) {
      if (_current && epoch == _epoch) error = studyChatSaveAnswerError;
    }
  }

  Future<void> retrySave() async {
    if (working || pendingAnswer == null || !_current) return;
    working = true;
    _changed();
    final epoch = _epoch;
    await _saveAnswer(epoch);
    if (_current && epoch == _epoch) {
      working = false;
      _changed();
    }
  }

  void cancel() {
    _cancel?.cancel();
    if (working) error = studyAiMessages['CANCELLED'];
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}
