import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/local/app_database.dart';
import '../../classes/data/class_repository.dart';
import 'post_attachment_repository.dart';

Map<String, dynamic> _cacheJson(Map<String, dynamic> row) => {
  for (final entry in row.entries)
    entry.key.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (m) => m[1]!.toUpperCase(),
    ): entry.key.endsWith('_at') && entry.value != null
        ? DateTime.parse(entry.value as String).millisecondsSinceEpoch
        : entry.value,
};

class PostRepository {
  PostRepository(this.classes, this.client, this.attachments);
  final ClassRepository classes;
  final SupabaseClient client;
  final PostAttachmentRepository attachments;
  AppDatabase get database => classes.database;
  final Map<String, Future<void>> _pending = {};

  Stream<List<CachePost>> watchPosts(String classId) =>
      (database.select(database.cachePosts)
            ..where((p) => p.classId.equals(classId) & p.deletedAt.isNull())
            ..orderBy([
              (p) => OrderingTerm.desc(p.createdAt),
              (p) => OrderingTerm.desc(p.id),
            ]))
          .watch();

  Future<void> sync(String classId) =>
      _pending[classId] ??= _pull(classId).whenComplete(() {
        // Map.remove returns the stored Future. Returning that value here
        // would make this completion wait on its own result.
        _pending.remove(classId);
      });

  Future<void> _pull(String classId) async {
    // Resolve access first. Existing class sync deletes revoked classes and
    // SQLite cascades through posts and attachments, even outside this screen.
    await classes.sync();
    final db = database;
    final room = await (db.select(
      db.cacheClasses,
    )..where((c) => c.id.equals(classId))).getSingleOrNull();
    if (room == null || room.deletedAt != null) return;
    if (room.ownerId != classes.userId) {
      final member =
          await (db.select(db.cacheClassMembers)..where(
                (m) =>
                    m.classId.equals(classId) &
                    m.studentId.equals(classes.userId),
              ))
              .getSingleOrNull();
      if (member?.status != 'active') {
        await db.transaction(() async {
          await (db.delete(
            db.cachePosts,
          )..where((p) => p.classId.equals(classId))).go();
          await (db.delete(db.syncState)..where(
                (s) => s.syncedTableName.isIn([
                  'posts:$classId',
                  'post_attachments:$classId',
                ]),
              ))
              .go();
        });
        return;
      }
    }
    final keys = ['posts:$classId', 'post_attachments:$classId'];
    final cursors = {
      for (final s in await (db.select(
        db.syncState,
      )..where((s) => s.syncedTableName.isIn(keys))).get())
        s.syncedTableName: s.lastSyncedAt,
    };
    // SQLite timestamps have second precision. Replay a boundary second and
    // advance only from server rows, never the phone clock.
    DateTime? since(String key) =>
        cursors[key]?.subtract(const Duration(seconds: 1));
    final posts = <Map<String, dynamic>>[];
    String? after;
    while (true) {
      var query = client.from('posts').select().eq('class_id', classId);
      final boundary = since(keys[0]);
      if (boundary != null) {
        query = query.gte('updated_at', boundary.toUtc().toIso8601String());
      }
      if (after != null) query = query.gt('id', after);
      final page = await query
          .order('id', ascending: true)
          .limit(500)
          .timeout(const Duration(seconds: 20));
      posts.addAll(page);
      if (page.isEmpty) break;
      after = page.last['id'] as String;
    }
    final files = await attachments.readChanges(classId, since(keys[1]));
    await db.transaction(() async {
      // Class refresh may have revoked access while the network pull ran.
      final current = await (db.select(
        db.cacheClasses,
      )..where((c) => c.id.equals(classId))).getSingleOrNull();
      if (current == null || current.deletedAt != null) return;
      if (current.ownerId != classes.userId) {
        final member =
            await (db.select(db.cacheClassMembers)..where(
                  (m) =>
                      m.classId.equals(classId) &
                      m.studentId.equals(classes.userId),
                ))
                .getSingleOrNull();
        if (member?.status != 'active') return;
      }
      for (final row in posts) {
        if (row['deleted_at'] != null) {
          await (db.delete(
            db.cachePosts,
          )..where((p) => p.id.equals(row['id'] as String))).go();
        } else {
          await db
              .into(db.cachePosts)
              .insertOnConflictUpdate(
                CachePost.fromJson(_cacheJson(row)).toCompanion(false),
              );
        }
      }
      final liveIds =
          (await (db.select(
                db.cachePosts,
              )..where((p) => p.classId.equals(classId))).get())
              .map((p) => p.id)
              .toSet();
      for (final row in files) {
        if (row['deleted_at'] != null) {
          await (db.delete(
            db.cachePostAttachments,
          )..where((a) => a.id.equals(row['id'] as String))).go();
        } else if (liveIds.contains(row['post_id'])) {
          await db
              .into(db.cachePostAttachments)
              .insertOnConflictUpdate(
                CachePostAttachment.fromJson(_cacheJson(row))
                    .toCompanion(false),
              );
        }
      }
      for (final entry in {keys[0]: posts, keys[1]: files}.entries) {
        var cursor = cursors[entry.key];
        for (final row in entry.value) {
          final updated = DateTime.parse(row['updated_at'] as String);
          if (cursor == null || updated.isAfter(cursor)) cursor = updated;
        }
        await db
            .into(db.syncState)
            .insertOnConflictUpdate(
              SyncStateCompanion.insert(
                syncedTableName: entry.key,
                lastSyncedAt: Value(cursor),
              ),
            );
      }
    });
  }
}
