import 'dart:async';

/// One stable persistence operation per qualifying background interval.
class ExamLeaveTracker {
  ExamLeaveTracker({required this.capture, required this.onQueued});
  final Future<void> Function()? Function() capture;
  final Future<void> Function() onQueued;
  final _pending = <Future<void> Function()>[];
  Timer? _debounce;
  final _away = Stopwatch();
  Future<void> Function()? _candidate;

  void _qualify() {
    final write = _candidate;
    _candidate = null;
    if (_disposed || write == null) return;
    _pending.add(write);
    unawaited(retry());
  }

  bool _background = false, _disposed = false;
  Future<void>? _writing;

  void background() {
    if (_disposed || _background) return;
    _background = true;
    _candidate = capture();
    _away
      ..reset()
      ..start();
    _debounce = Timer(const Duration(seconds: 1), _qualify);
  }

  Future<void> resume() async {
    // Android may suspend the Dart timer while backgrounded.
    if (_background && _away.elapsed >= const Duration(seconds: 1)) _qualify();
    _background = false;
    _candidate = null;
    _away.stop();
    _debounce?.cancel();
    await retry();
  }

  Future<void> retry() =>
      _writing ??= _persist().whenComplete(() => _writing = null);

  Future<void> _persist() async {
    while (!_disposed && _pending.isNotEmpty) {
      final write = _pending.first;
      try {
        await write();
      } catch (_) {
        // Retain the same ID and timestamp until SQLite acknowledges the write.
        return;
      }
      if (_disposed) return;
      _pending.removeAt(0);
      if (!_disposed && !_background) await onQueued();
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _pending.clear();
  }
}
