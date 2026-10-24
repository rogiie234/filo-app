import 'dart:async';

import '../data/exam_remote.dart';
import '../data/exam_store.dart';
import '../domain/exam.dart';
import '../domain/exam_clock.dart';

typedef ExamSchedule = void Function(Duration delay, void Function() action);

class ExamAnswerSaver {
  ExamAnswerSaver({
    required this.store,
    required this.remote,
    required this.clock,
    required this.sessionId,
    required this.isCurrent,
    required this.online,
    required this.onChanged,
    required this.onReconcile,
    ExamSchedule? schedule,
  }) {
    _schedule =
        schedule ??
        (delay, action) {
          _timer?.cancel();
          _timer = Timer(delay, action);
        };
  }
  final ExamStore store;
  final ExamRemote remote;
  final ExamClock clock;
  final String sessionId;
  final bool Function() isCurrent, online;
  final void Function() onChanged;
  final Future<void> Function() onReconcile;
  late final ExamSchedule _schedule;
  Timer? _timer;
  Future<void>? _running;
  final _textTimers = <String, Timer>{};
  final _editVersions = <String, int>{};
  final _debouncing = <String>{};
  bool _disposed = false, _blocked = false, _paused = false;
  bool _dirty = false;
  final _invalidQuestions = <String, ExamFailure>{};
  int _failures = 0, _generation = 0;
  ExamFailure? _error;
  ExamFailure? get error => _error ?? _invalidQuestions.values.firstOrNull;
  bool get sending => _running != null;
  bool get _current => !_disposed && isCurrent();

  Future<void> change(ExamAnswer answer) async {
    if (!_current || !clock.canEdit || _blocked)
      throw const ExamFailure('This attempt is no longer accepting answers.');
    final id = answer.questionId;
    final version = (_editVersions[id] ?? 0) + 1;
    _editVersions[id] = version;
    _textTimers.remove(id)?.cancel();
    if (answer.text != null) _debouncing.add(id);
    await store.write(sessionId, answer, clock.wallNow());
    if (!_current || _editVersions[id] != version) return;
    if (answer.text != null) {
      _textTimers[id] = Timer(const Duration(milliseconds: 800), () {
        _textTimers.remove(id);
        _debouncing.remove(id);
        _dirty = true;
        if (_current) unawaited(flush(drainText: false));
      });
    } else {
      _debouncing.remove(id);
    }
    _error = null;
    if ((answer.text?.runes.length ?? 0) > 10000) {
      const failure = ExamFailure('Keep your answer within 10,000 characters.');
      _invalidQuestions[answer.questionId] = failure;
      onChanged();
      throw failure;
    }
    _invalidQuestions.remove(answer.questionId);
    _dirty = true;
    onChanged();
    unawaited(flush(drainText: false));
  }

  void reconnect() {
    if (!_current) return;
    _timer?.cancel();
    _generation++;
    _failures = 0;
    unawaited(flush(drainText: false));
  }

  Future<void> flush({bool drainText = true}) {
    if (drainText) {
      for (final timer in _textTimers.values) {
        timer.cancel();
      }
      _textTimers.clear();
      _debouncing.clear();
      _dirty = true;
    }
    if (_running != null) return _running!;
    if (!_current || _blocked || _paused || !online() || !clock.canSend)
      return Future.value();
    final work = _flush();
    _running = work;
    onChanged();
    return work.whenComplete(() {
      _running = null;
      if (_current) {
        onChanged();
        if (_dirty && _error == null) unawaited(flush(drainText: false));
      }
    });
  }

  Future<void> _flush() async {
    try {
      while (_current && !_blocked && !_paused && online() && clock.canSend) {
        _dirty = false;
        final versions = Map<String, int>.of(_editVersions);
        final snapshot = await store.answers(sessionId, pendingOnly: true);
        if (!_current || _paused || !online() || !clock.canSend) return;
        final pending = <StoredAnswer>[];
        for (final answer in snapshot) {
          final id = answer.answer.questionId;
          if (_debouncing.contains(id) || _invalidQuestions.containsKey(id))
            continue;
          if ((answer.answer.text?.runes.length ?? 0) > 10000) {
            _invalidQuestions[id] = const ExamFailure(
              'Keep your answer within 10,000 characters.',
            );
            continue;
          }
          pending.add(answer);
          if (pending.length == 20) break;
        }
        if (pending.isEmpty) return;
        try {
          final receipts = await remote.saveBatch(sessionId, pending);
          if (!_current) return;
          final successful = [
            for (final answer in pending)
              if (receipts.any(
                (r) =>
                    r.questionId == answer.answer.questionId &&
                    r.revision == answer.revision &&
                    r.savedAt != null &&
                    r.failure == null,
              ))
                answer,
          ];
          await store.acknowledgeBatch(sessionId, successful);
          if (!_current) return;
          _failures = 0;
          _error = null;
          for (final receipt in receipts) {
            final failure = receipt.failure;
            if (failure == null) continue;
            if (failure.retryable || failure.reconcile) {
              _handleFailure(failure);
              return;
            }
            if (_editVersions[receipt.questionId] ==
                versions[receipt.questionId]) {
              _invalidQuestions[receipt.questionId] = failure;
            }
          }
        } catch (e) {
          if (!_current) return;
          final failure = examFailure(e);
          _handleFailure(failure);
          if (!failure.retryable && !failure.reconcile) {
            for (final answer in pending) {
              final id = answer.answer.questionId;
              if (_editVersions[id] == versions[id])
                _invalidQuestions[id] = failure;
            }
          }
          return;
        }
        if (_current) onChanged();
      }
    } catch (e) {
      if (_current) _error = examFailure(e);
    }
  }

  void _handleFailure(ExamFailure failure) {
    _error = failure;
    if (failure.retryable) {
      final seconds = _failures < 3 ? 1 << _failures++ : 8;
      final generation = ++_generation;
      _schedule(Duration(seconds: seconds), () {
        if (_current && generation == _generation)
          unawaited(flush(drainText: false));
      });
    } else if (failure.reconcile) {
      _blocked = true;
      // Reconcile after this flight exits, so refreshing cannot await itself.
      _schedule(Duration.zero, () {
        if (_current)
          unawaited(
            onReconcile().catchError((Object e) {
              if (_current) {
                _error = examFailure(e);
                onChanged();
              }
            }),
          );
      });
    }
  }

  Future<void> drain() async {
    do {
      await flush();
    } while (_current &&
        online() &&
        clock.canSend &&
        error == null &&
        !await allSent());
  }

  Future<bool> allSent() async =>
      (await store.answers(sessionId)).every((a) => a.sent);
  Future<void> pause() async {
    _paused = true;
    _timer?.cancel();
    _generation++;
    await _running;
  }

  void resume() {
    _paused = false;
    reconnect();
  }

  void dispose() {
    _disposed = true;
    for (final timer in _textTimers.values) {
      timer.cancel();
    }
    _textTimers.clear();
    _debouncing.clear();
    _generation++;
    _timer?.cancel();
  }
}
