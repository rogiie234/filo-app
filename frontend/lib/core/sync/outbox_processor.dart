import 'dart:math' as math;

class QueuedAction {
  const QueuedAction(this.id, this.type, this.payload, this.attempts);
  final String id, type;
  final Map<String, dynamic> payload;
  final int attempts;
}

class OutboxActionFailure implements Exception {
  const OutboxActionFailure(this.message);
  final String message;
}

class DeferredAction implements Exception {
  const DeferredAction();
}

abstract interface class OutboxStore {
  Future<QueuedAction?> claim(DateTime now);
  Future<void> complete(String id);
  Future<void> retry(
    String id,
    int attempts,
    DateTime next, {
    required bool failed,
    String? error,
  });
}

class RetryPolicy {
  const RetryPolicy({this.maxAttempts = 8, this.baseSeconds = 5});
  final int maxAttempts, baseSeconds;
  Duration delay(int attempts) => Duration(
    seconds: math.min(
      3600,
      baseSeconds * math.pow(2, math.max(0, attempts - 1)).toInt(),
    ),
  );
}

class OutboxProcessor {
  OutboxProcessor(
    this.store,
    this.send, {
    this.policy = const RetryPolicy(),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final OutboxStore store;
  final Future<void> Function(QueuedAction) send;
  final RetryPolicy policy;
  final DateTime Function() clock;
  Future<void> flush() async {
    for (var count = 0; count < 100; count++) {
      final action = await store.claim(clock().toUtc());
      if (action == null) {
        return;
      }
      try {
        // Payloads contain a stable event/file ID and immutable read timestamp.
        await send(action);
        await store.complete(action.id);
      } on DeferredAction {
        await store.retry(
          action.id,
          action.attempts,
          clock().toUtc().add(const Duration(minutes: 1)),
          failed: false,
          error: 'Waiting for connectivity or authorization.',
        );
      } catch (error) {
        final attempts = action.attempts + 1;
        await store.retry(
          action.id,
          attempts,
          clock().toUtc().add(policy.delay(attempts)),
          failed: attempts >= policy.maxAttempts,
          error: error is OutboxActionFailure
              ? error.message
              : error.runtimeType.toString(),
        );
      }
    }
  }
}
