import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/sync/outbox_processor.dart';

class MemoryOutbox implements OutboxStore {
  MemoryOutbox(this.action);
  QueuedAction action;
  bool done = false, failed = false, loseFirstAcknowledgement = false;
  DateTime? next;
  @override
  Future<QueuedAction?> claim(DateTime now) async =>
      done || failed || next != null && now.isBefore(next!) ? null : action;
  @override
  Future<void> complete(String id) async {
    if (loseFirstAcknowledgement) {
      loseFirstAcknowledgement = false;
      throw StateError('local acknowledgement lost');
    }
    done = true;
  }

  @override
  Future<void> retry(
    String id,
    int attempts,
    DateTime next, {
    required bool failed,
    String? error,
  }) async {
    action = QueuedAction(action.id, action.type, action.payload, attempts);
    this.next = next;
    this.failed = failed;
  }
}

void main() {
  test(
    'network failures back off, do not retry early, and stop at the limit',
    () async {
      var now = DateTime.utc(2026, 10, 18);
      final store = MemoryOutbox(
        const QueuedAction('event-1', 'leave_event', {}, 0),
      );
      var calls = 0;
      final worker = OutboxProcessor(
        store,
        (_) async {
          calls++;
          throw StateError('offline');
        },
        policy: const RetryPolicy(maxAttempts: 2),
        clock: () => now,
      );
      await worker.flush();
      expect(calls, 1);
      expect(store.next, now.add(const Duration(seconds: 5)));
      await worker.flush();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 5));
      await worker.flush();
      expect(calls, 2);
      expect(store.failed, isTrue);
      now = now.add(const Duration(days: 1));
      await worker.flush();
      expect(calls, 2);
    },
  );

  test('lost completion retries the same event ID without a duplicate server effect', () async {
    var now = DateTime.utc(2026, 10, 18);
    final store = MemoryOutbox(
      const QueuedAction('stable-event', 'leave_event', {
        'session_id': 'session',
      }, 0),
    )..loseFirstAcknowledgement = true;
    final serverEvents = <String>{};
    final requests = <String>[];
    final worker = OutboxProcessor(store, (action) async {
      requests.add(action.id);
      serverEvents.add(
        action.id,
      ); // Server log_leave uses ON CONFLICT(event id).
    }, clock: () => now);
    await worker.flush();
    now = now.add(const Duration(seconds: 5));
    await worker.flush();
    expect(requests, ['stable-event', 'stable-event']);
    expect(serverEvents, {'stable-event'});
    expect(store.done, isTrue);
  });

  test('Wi-Fi or permission deferral preserves retry allowance', () async {
    final now = DateTime.utc(2026, 10, 18);
    final store = MemoryOutbox(
      const QueuedAction('backup', 'drive_backup', {}, 0),
    );
    await OutboxProcessor(
      store,
      (_) async => throw const DeferredAction(),
      clock: () => now,
    ).flush();
    expect(store.action.attempts, 0);
    expect(store.failed, isFalse);
    expect(store.next, now.add(const Duration(minutes: 1)));
  });
}
