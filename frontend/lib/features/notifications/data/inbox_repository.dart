import 'package:drift/drift.dart';

import '../../../core/sync/sqlite_outbox.dart';
import '../../../data/local/app_database.dart';

class InboxRepository {
  InboxRepository(this.db, this.userId, this.isCurrent);
  final AppDatabase db;
  final String userId;
  final bool Function() isCurrent;

  void _checkAccount() {
    if (!isCurrent()) throw StateError('Account changed');
  }

  SimpleSelectStatement<$CacheNotificationsTable, CacheNotification> _inbox() =>
      db.select(db.cacheNotifications)
        ..where((n) => n.recipientId.equals(userId));

  Stream<List<CacheNotification>> watchInbox() {
    _checkAccount();
    return (_inbox()..orderBy([
          (n) => OrderingTerm.desc(n.createdAt),
          (n) => OrderingTerm.desc(n.id),
        ]))
        .watch()
        .map((rows) {
          _checkAccount();
          return rows;
        });
  }

  Stream<int> watchUnreadCount() {
    _checkAccount();
    final count = db.cacheNotifications.id.count();
    return (db.selectOnly(db.cacheNotifications)
          ..addColumns([count])
          ..where(
            db.cacheNotifications.recipientId.equals(userId) &
                db.cacheNotifications.readAt.isNull(),
          ))
        .watchSingle()
        .map((row) {
          _checkAccount();
          return row.read(count)!;
        });
  }

  Future<void> markRead(String id) => _mark(id);
  Future<void> markAllRead() => _mark(null);

  Future<void> _mark(String? id) => db.transaction(() async {
    _checkAccount();
    final query = _inbox()..where((n) => n.readAt.isNull());
    if (id != null) query.where((n) => n.id.equals(id));
    final rows = await query.get();
    final stamp = db.now().toUtc();
    for (final row in rows) {
      await SqliteOutbox(db).enqueue('read:${row.id}', 'notification_read', {
        'notification_id': row.id,
        'read_at': stamp.toIso8601String(),
      });
      await (db.update(db.cacheNotifications)
            ..where((n) => n.id.equals(row.id) & n.recipientId.equals(userId)))
          .write(CacheNotificationsCompanion(readAt: Value(stamp)));
    }
    _checkAccount();
  });
}
