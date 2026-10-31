import 'package:flutter/foundation.dart';

import '../../../core/ai/ai_cancellation.dart';
import '../data/student_ai_client.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import '../domain/study_summary_usage.dart';

const studySummaryBusyMessage =
    'The AI assistant is busy right now. Please try again in a few minutes.';
const studySummarySaveError =
    'Could not confirm this summary was saved. Keep this screen open and try saving again.';

class StudySummarySession extends ChangeNotifier {
  StudySummarySession({
    required this.notebookId,
    required this.repository,
    required this.client,
    required this.isCurrent,
    required this.isOnline,
  });
  final String notebookId;
  final StudySummaryRepository repository;
  final StudentAiClient client;
  final bool Function() isCurrent, isOnline;
  StudyAiResult<StudyTextAnswer>? pending;
  String? error;
  bool working = false, saving = false, _disposed = false;
  int _epoch = 0;
  AiCancelToken? _cancel;
  bool get _current => !_disposed && isCurrent();
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> generate() async {
    if (!_current || working || pending != null) return;
    if (!isOnline() || client.guard.isBusy) {
      error = studyAiMessages[isOnline() ? 'AI_IN_PROGRESS' : 'OFFLINE'];
      _changed();
      return;
    }
    final epoch = ++_epoch;
    final token = AiCancelToken();
    _cancel = token;
    working = true;
    error = null;
    _changed();
    bool valid() => _current && epoch == _epoch && !token.isCancelled;
    try {
      final result = await client.summary(
        notebookId: notebookId,
        cancel: token,
      );
      if (!valid()) return;
      pending = result;
      await _save(valid);
    } catch (failure) {
      if (valid())
        error = failure is StudyAiFailure && failure.code == 'AI_BUSY'
            ? studySummaryBusyMessage
            : studyAiFriendlyError(failure);
    } finally {
      token.cancel();
      if (_current && epoch == _epoch) {
        _cancel = null;
        working = false;
        saving = false;
        _changed();
      }
    }
  }

  Future<void> retrySave() async {
    if (!_current || working || pending == null) return;
    final epoch = ++_epoch;
    working = true;
    error = null;
    _changed();
    await _save(() => _current && epoch == _epoch);
    if (_current && epoch == _epoch) {
      working = false;
      saving = false;
      _changed();
    }
  }

  Future<void> _save(bool Function() valid) async {
    final result = pending!;
    saving = true;
    _changed();
    try {
      await repository.save(
        notebookId,
        result.value.answer,
        usage: StudySummaryUsage.fromResult(result),
        canCommit: valid,
      );
      if (valid()) {
        pending = null;
        error = null;
      }
    } catch (_) {
      if (valid()) error = studySummarySaveError;
    }
  }

  void cancel() {
    if (!working || saving) return;
    _cancel?.cancel();
    _cancel = null;
    ++_epoch;
    working = false;
    error = studyAiMessages['CANCELLED'];
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _cancel?.cancel();
    super.dispose();
  }
}
