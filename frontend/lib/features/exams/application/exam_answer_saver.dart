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
  bool _disposed = false, _blocked = false, _paused = false;
  bool _dirty = false;
  final Set<String> _invalidQuestions = {};
  int _failures = 0, _generation = 0;
  ExamFailure? error;
  bool get sending => _running != null;
  bool get _current => !_disposed && isCurrent();

  Future<void> change(ExamAnswer answer) async {
    if (!_current || !clock.canEdit || _blocked)
      throw const ExamFailure('This attempt is no longer accepting answers.');
    await store.write(sessionId, answer, clock.wallNow());
    if (!_current) return;
    if ((answer.text?.runes.length ?? 0) > 10000) {
      _invalidQuestions.add(answer.questionId);
      error = const ExamFailure('Keep your answer within 10,000 characters.');
      onChanged();
      throw error!;
    }
    _invalidQuestions.remove(answer.questionId);
    _dirty = true;
    error = null;
    onChanged();
    unawaited(flush());
  }

  void reconnect() {
    if (!_current) return;
    _timer?.cancel();
    _generation++;
    _failures = 0;
    unawaited(flush());
  }

  Future<void> flush() {
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
        if (_dirty && error == null) unawaited(flush());
      }
    });
  }

  Future<void> _flush() async {
    try {
      while (_current && !_blocked && !_paused && online() && clock.canSend) {
        _dirty = false;
        final pending = (await store.answers(sessionId))
            .where(
              (a) =>
                  !a.sent && !_invalidQuestions.contains(a.answer.questionId),
            )
            .toList();
        if (!_current || pending.isEmpty) return;
        for (final queued in pending) {
          if (!_current || _paused || !online() || !clock.canSend) return;
          final latest = (await store.answers(sessionId))
              .where((a) => a.answer.questionId == queued.answer.questionId)
              .single;
          if (!_current || _paused || !clock.canSend) return;
          if (latest.sent) continue;
          if ((latest.answer.text?.runes.length ?? 0) > 10000) {
            _invalidQuestions.add(latest.answer.questionId);
            error = const ExamFailure(
              'Keep your answer within 10,000 characters.',
            );
            onChanged();
            continue;
          }
          try {
            await remote.save(sessionId, latest.answer);
            if (!_current) return;
            await store.acknowledge(sessionId, latest);
            _failures = 0;
            error = null;
          } catch (e) {
            if (!_current) return;
            error = examFailure(e);
            if (error!.retryable) {
              final seconds = _failures < 3 ? 1 << _failures++ : 8;
              final generation = ++_generation;
              _schedule(Duration(seconds: seconds), () {
                if (_current && generation == _generation) unawaited(flush());
              });
              return;
            }
            if (error!.reconcile) {
              _blocked = true;
              // Reconcile after this flight exits, so refreshing cannot await itself.
              _schedule(Duration.zero, () {
                if (_current)
                  unawaited(
                    onReconcile().catchError((Object e) {
                      if (_current) {
                        error = examFailure(e);
                        onChanged();
                      }
                    }),
                  );
              });
              return;
            }
            final now = (await store.answers(sessionId))
                .where((a) => a.answer.questionId == queued.answer.questionId)
                .single;
            if (now.revision == latest.revision)
              _invalidQuestions.add(queued.answer.questionId);
          }
          if (_current) onChanged();
        }
      }
    } catch (e) {
      if (_current) error = examFailure(e);
    }
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
    _generation++;
    _timer?.cancel();
  }
}
