import 'dart:async';

import 'ai_cancellation.dart';

class AiRequestInProgress implements Exception {
  const AiRequestInProgress();
}

/// The root ProviderScope shares this guard across roles, screens and accounts.
class AiRequestGuard {
  AiRequestGuard({
    Duration Function()? elapsed,
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future<void>.delayed {
    final clock = Stopwatch()..start();
    _elapsed = elapsed ?? () => clock.elapsed;
  }

  late final Duration Function() _elapsed;
  final Future<void> Function(Duration) _sleep;
  final _changes = StreamController<bool>.broadcast(sync: true);
  final _chatDispatches = StreamController<void>.broadcast(sync: true);
  AiCancelToken? _active;
  Duration? _lastChatDispatch;
  bool _closed = false;
  bool get isBusy => _active != null;
  Duration get chatCooldownRemaining {
    final last = _lastChatDispatch;
    if (last == null) return Duration.zero;
    final remaining = const Duration(seconds: 3) - (_elapsed() - last);
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  Stream<Duration> watchChatCooldown() => Stream.multi((listener) {
    Timer? timer;
    void publish() {
      timer?.cancel();
      final remaining = chatCooldownRemaining;
      listener.add(remaining);
      if (remaining > Duration.zero) {
        timer = Timer(
          remaining < const Duration(seconds: 1)
              ? remaining
              : const Duration(seconds: 1),
          publish,
        );
      }
    }

    final subscription = _chatDispatches.stream.listen(
      (_) => publish(),
      onDone: () {
        timer?.cancel();
        listener.close();
      },
    );
    publish();
    listener.onCancel = () {
      timer?.cancel();
      return subscription.cancel();
    };
  });

  Stream<bool> watchBusy() => Stream.multi((listener) {
    final subscription = _changes.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.add(isBusy);
    listener.onCancel = subscription.cancel;
  });

  Future<T> run<T>(
    AiCancelToken cancel,
    Future<T> Function(AiCancelToken) work, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    cancel.check();
    if (_closed) throw const AiCancelled();
    if (isBusy) throw const AiRequestInProgress();
    final operation = AiCancelToken();
    _active = operation;
    _changes.add(true);
    unawaited(cancel.cancelled.then((_) => operation.cancel()));
    try {
      return await operation.wait(work(operation)).timeout(timeout);
    } finally {
      // Abort the phone's transport; the server may still finalize its request.
      operation.cancel();
      _active = null;
      if (!_closed) _changes.add(false);
    }
  }

  Future<void> waitForChat(AiCancelToken cancel) async {
    final last = _lastChatDispatch;
    if (last != null) {
      final remaining = const Duration(seconds: 3) - (_elapsed() - last);
      if (remaining > Duration.zero) await cancel.wait(_sleep(remaining));
    }
    cancel.check();
  }

  void markChatDispatched() {
    _lastChatDispatch = _elapsed();
    if (!_closed) _chatDispatches.add(null);
  }

  Future<void> close() async {
    _closed = true;
    _active?.cancel();
    await _changes.close();
    await _chatDispatches.close();
  }
}
