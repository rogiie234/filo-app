import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/local/app_database.dart';
import 'outbox_processor.dart';

class SqliteOutbox implements OutboxStore {
  SqliteOutbox(this.db);
  final AppDatabase db;
  @override
  Future<QueuedAction?> claim(DateTime now) => db.transaction(() async {
    // Lease prevents foreground/background workers from sending the same job.
    final rows = await db
        .customSelect(
          '''
      SELECT o.* FROM outbox o LEFT JOIN outbox_schedule s ON s.id=o.id
      WHERE o.status IN ('pending','processing')
        AND (s.next_at IS NULL OR s.next_at <= ?)
        AND (s.lease_until IS NULL OR s.lease_until <= ?)
      ORDER BY o.created_at,o.id LIMIT 1
    ''',
          variables: [
            Variable(now.toIso8601String()),
            Variable(now.toIso8601String()),
          ],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single.data;
    await db.customStatement(
      'INSERT OR REPLACE INTO outbox_schedule(id,next_at,lease_until) VALUES(?,NULL,?)',
      [row['id'], now.add(const Duration(minutes: 30)).toIso8601String()],
    );
    await db.customStatement(
      "UPDATE outbox SET status='processing' WHERE id=?",
      [row['id']],
    );
    return QueuedAction(
      row['id'] as String,
      row['action_type'] as String,
      jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      row['attempts'] as int,
    );
  });
  @override
  Future<void> complete(String id) => db.transaction(() async {
    await db.customStatement(
      "UPDATE outbox SET status='complete', last_error=NULL WHERE id=?",
      [id],
    );
    await db.customStatement('DELETE FROM outbox_schedule WHERE id=?', [id]);
    db.notifyUpdates({TableUpdate('outbox')});
  });
  @override
  Future<void> retry(
    String id,
    int attempts,
    DateTime next, {
    required bool failed,
    String? error,
  }) => db.transaction(() async {
    await db.customStatement(
      'UPDATE outbox SET status=?,attempts=?,last_error=? WHERE id=?',
      [
        failed ? 'failed' : 'pending',
        attempts,
        error ??
            (failed
                ? 'Retry limit reached. Open Filo and retry this action.'
                : 'Waiting to retry.'),
        id,
      ],
    );
    await db.customStatement(
      'INSERT OR REPLACE INTO outbox_schedule(id,next_at,lease_until) VALUES(?,?,NULL)',
      [id, next.toIso8601String()],
    );
  });

  Future<void> enqueue(
    String id,
    String type,
    Map<String, dynamic> payload,
  ) async {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: id,
            actionType: type,
            payload: jsonEncode(payload),
            status: 'pending',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> retryFailed() => db.transaction(() async {
    await db.customStatement(
      "DELETE FROM outbox_schedule WHERE id IN (SELECT id FROM outbox WHERE status='failed')",
    );
    await db.customStatement(
      "UPDATE outbox SET status='pending',attempts=0,last_error=NULL WHERE status='failed'",
    );
  });
}
