/// Wall time is sampled only when fetching/restarting. Live time is monotonic.
class ExamClock {
  ExamClock({DateTime Function()? wallNow, Duration Function()? elapsed})
    : wallNow = wallNow ?? DateTime.now {
    final stopwatch = Stopwatch()..start();
    this.elapsed = elapsed ?? (() => stopwatch.elapsed);
  }
  final DateTime Function() wallNow;
  late final Duration Function() elapsed;
  DateTime? deadline;
  DateTime? _anchor;
  Duration _anchorElapsed = Duration.zero;
  Duration? offset;
  bool verified = false;

  void synchronize({
    required DateTime serverNow,
    required DateTime deadline,
    required DateTime requestWall,
    required Duration requestElapsed,
    required Duration responseElapsed,
  }) {
    final halfTrip = Duration(
      microseconds: (responseElapsed - requestElapsed).inMicroseconds ~/ 2,
    );
    offset = serverNow.difference(requestWall.add(halfTrip));
    _anchor = serverNow.add(halfTrip);
    _anchorElapsed = responseElapsed;
    this.deadline = deadline;
    verified = true;
  }

  void restore({
    required DateTime serverAtReceipt,
    required DateTime deviceAtReceipt,
    required DateTime deadline,
  }) {
    _anchor = serverAtReceipt.add(
      wallNow().toUtc().difference(deviceAtReceipt),
    );
    _anchorElapsed = elapsed();
    this.deadline = deadline;
    verified = false;
    offset = null;
  }

  DateTime get serverNow => _anchor!.add(elapsed() - _anchorElapsed);
  Duration get remaining {
    if (_anchor == null || deadline == null) return Duration.zero;
    final value = deadline!.difference(serverNow);
    return value.isNegative ? Duration.zero : value;
  }

  bool get expired => verified && _anchor != null && remaining == Duration.zero;
  bool get canEdit => verified && _anchor != null && remaining > Duration.zero;
  bool get acceptanceClosed =>
      verified &&
      _anchor != null &&
      serverNow.isAfter(deadline!.add(const Duration(seconds: 15)));
  String get timeoutMessage => acceptanceClosed
      ? "Time's up. Reconnect to check your submission. Answers that did not reach the server within 15 seconds after the deadline are lost."
      : "Time's up. Reconnect to check your submission. Answers that don't reach the server within 15 seconds after the deadline will be lost.";
  bool get canSend =>
      verified &&
      _anchor != null &&
      serverNow.isBefore(deadline!.add(const Duration(seconds: 14)));
  void invalidate() => verified = false;
}
