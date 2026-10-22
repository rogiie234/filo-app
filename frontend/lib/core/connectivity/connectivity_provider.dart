import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shares platform events and explicit rechecks without recreating the stream
/// watched by authentication, repositories and screens.
class ConnectivityMonitor {
  ConnectivityMonitor({
    Connectivity? connectivity,
    bool observeLifecycle = true,
  }) : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _revision++;
        _publish(results);
      },
      onError: (Object error, StackTrace stack) {
        _revision++;
        _publishError(error, stack);
      },
    );
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: _checkSilently);
    }
    unawaited(_checkSilently());
  }

  final Connectivity _connectivity;
  final _events = StreamController<bool>.broadcast(sync: true);
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;
  bool? _online;
  Object? _error;
  StackTrace? _errorStack;
  int _revision = 0;

  Stream<bool> get stream => Stream<bool>.multi((sink) {
    final subscription = _events.stream.listen(
      sink.addSync,
      onError: (Object error, StackTrace stack) =>
          sink.addErrorSync(error, stack),
      onDone: sink.closeSync,
    );
    sink.onCancel = subscription.cancel;
    final error = _error;
    if (error != null) {
      sink.addErrorSync(error, _errorStack);
    } else if (_online != null) {
      sink.addSync(_online!);
    }
  });

  void _publish(List<ConnectivityResult> results) {
    if (_disposed) return;
    final online = results.any((result) => result != ConnectivityResult.none);
    // Suppress repeated values, but emit after an error so a successful recheck
    // can clear AsyncError even when the last good value was the same.
    final changed = _online != online || _error != null;
    _online = online;
    _error = null;
    _errorStack = null;
    if (changed) _events.add(online);
  }

  void _publishError(Object error, StackTrace stack) {
    if (_disposed) return;
    _error = error;
    _errorStack = stack;
    _events.addError(error, stack);
  }

  /// Network availability is a hint, not proof of working internet access.
  Future<bool> recheck() async {
    if (_disposed) throw StateError('Connectivity monitor is closed.');
    final revision = ++_revision;
    try {
      final results = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 5),
      );
      if (_disposed) throw StateError('Connectivity monitor is closed.');
      if (revision != _revision) {
        if (_error != null) {
          Error.throwWithStackTrace(_error!, _errorStack ?? StackTrace.current);
        }
        return _online ??
            results.any((result) => result != ConnectivityResult.none);
      }
      _publish(results);
      return _online!;
    } catch (error, stack) {
      // A delayed failure from an older request must not replace a newer event.
      if (!_disposed &&
          revision != _revision &&
          _error == null &&
          _online != null) {
        return _online!;
      }
      if (!_disposed && revision == _revision) _publishError(error, stack);
      rethrow;
    }
  }

  Future<void> _checkSilently() async {
    try {
      await recheck();
    } catch (_) {
      /* The stream exposes a retryable error. */
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _lifecycle?.dispose();
    await _subscription.cancel();
    await _events.close();
  }
}

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  ref.onDispose(() => unawaited(monitor.dispose()));
  return monitor;
});

final connectivityProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityMonitorProvider).stream,
);
