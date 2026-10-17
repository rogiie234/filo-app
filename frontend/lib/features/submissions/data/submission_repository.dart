import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/local/app_database.dart';
import '../../posts/data/post_repository.dart';
import '../domain/assignment_file_rules.dart';

Map<String, dynamic> _cacheJson(Map<String, dynamic> row) => {
  for (final entry in row.entries)
    entry.key.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase()):
        (entry.key.endsWith('_at') || entry.key == 'unsubmit_until') &&
            entry.value != null
        ? DateTime.parse(entry.value as String).millisecondsSinceEpoch
        : entry.value,
};

class _ConcurrentSubmissionWrite implements Exception {}

/// Student-only cache reads are scoped to the signed-in account even when an
/// instructor's RLS permissions would allow reading another student's work.
class SubmissionRepository {
  SubmissionRepository(this.posts, this.client, {required this.isOnline});
  final PostRepository posts;
  final SupabaseClient client;
  final bool Function() isOnline;
  AppDatabase get database => posts.database;
  String get userId => posts.classes.userId;
  final Map<String, Future<void>> _pending = {};
  bool _mutating = false;
  bool _reconciliationRequired = false;
  int _cacheRevision = 0;
  int _activeCacheWrites = 0;

  // Shared with draft item/comment writes. A pull started before or during a
  // confirmed write must never replace that newer state or advance cursors.
  // Wall-clock comparison is insufficient: Drift stores seconds, not micros.
  void beginCacheWrite() {
    _activeCacheWrites++;
    _cacheRevision++;
  }

  void endCacheWrite() {
    _activeCacheWrites--;
    _cacheRevision++;
  }

  Stream<List<CacheSubmission>> watchSubmissions(String classId) {
    final s = database.cacheSubmissions;
    final p = database.cachePosts;
    final query =
        database.select(s).join([innerJoin(p, p.id.equalsExp(s.postId))])
          ..where(
            p.classId.equals(classId) &
                p.deletedAt.isNull() &
                s.studentId.equals(userId),
          );
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(s)).toList(),
    );
  }

  Stream<List<CacheSubmissionItem>> watchItems(String submissionId) {
    final i = database.cacheSubmissionItems;
    final s = database.cacheSubmissions;
    final query =
        database.select(i).join([innerJoin(s, s.id.equalsExp(i.submissionId))])
          ..where(
            i.submissionId.equals(submissionId) &
                i.deletedAt.isNull() &
                s.studentId.equals(userId),
          )
          ..orderBy([OrderingTerm.asc(i.sortOrder), OrderingTerm.asc(i.id)]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(i)).toList(),
    );
  }

  Stream<List<CacheGrade>> watchReturnedGrades(String classId) {
    final g = database.cacheGrades;
    final s = database.cacheSubmissions;
    final p = database.cachePosts;
    final query =
        database.select(g).join([
          innerJoin(s, s.id.equalsExp(g.submissionId)),
          innerJoin(p, p.id.equalsExp(s.postId)),
        ])..where(
          p.classId.equals(classId) &
              p.deletedAt.isNull() &
              s.studentId.equals(userId) &
              g.returnedAt.isNotNull(),
        );
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(g)).toList(),
    );
  }

  Future<void> sync(String classId) =>
      _pending[classId] ??= _pull(classId).whenComplete(() {
        _pending.remove(classId);
      });

  Future<bool> _hasAccess(String classId) async {
    final db = database;
    final room =
        await (db.select(db.cacheClasses)
              ..where((c) => c.id.equals(classId) & c.deletedAt.isNull()))
            .getSingleOrNull();
    if (room == null) {
      return false;
    }
    if (room.ownerId == userId) {
      return true;
    }
    final member =
        await (db.select(db.cacheClassMembers)..where(
              (m) => m.classId.equals(classId) & m.studentId.equals(userId),
            ))
            .getSingleOrNull();
    return member?.status == 'active';
  }

  Future<void> _pull(String classId) async {
    final revision = _cacheRevision;
    // Populate post/profile foreign keys and reconcile class access first.
    await posts.sync(classId);
    if (!await _hasAccess(classId)) {
      return;
    }
    final db = database;
    final keys = [
      'submissions:$classId',
      'submission_items:$classId',
      'submission_grades:$classId',
    ];
    final cursors = {
      for (final row in await (db.select(
        db.syncState,
      )..where((s) => s.syncedTableName.isIn(keys))).get())
        row.syncedTableName: row.lastSyncedAt,
    };
    final changes = <String, List<Map<String, dynamic>>>{};
    for (var index = 0; index < keys.length; index++) {
      final table = [
        'submissions',
        'submission_items',
        'submission_grades',
      ][index];
      final primaryKey = index == 2 ? 'submission_id' : 'id';
      final rows = <Map<String, dynamic>>[];
      String? after;
      while (true) {
        var query = client
            .from(table)
            .select(
              index == 0
                  ? '*,posts!inner(class_id)'
                  : '*,submissions!inner(student_id,posts!inner(class_id))',
            );
        query = index == 0
            ? query.eq('student_id', userId).eq('posts.class_id', classId)
            : query
                  .eq('submissions.student_id', userId)
                  .eq('submissions.posts.class_id', classId);
        final boundary = cursors[keys[index]]?.subtract(
          const Duration(seconds: 1),
        );
        if (boundary != null) {
          query = query.gte('updated_at', boundary.toUtc().toIso8601String());
        }
        if (after != null) {
          query = query.gt(primaryKey, after);
        }
        final page = await query
            .order(primaryKey)
            .limit(500)
            .timeout(const Duration(seconds: 20));
        rows.addAll(
          page.map(
            (row) =>
                Map<String, dynamic>.from(row)
                  ..remove(index == 0 ? 'posts' : 'submissions'),
          ),
        );
        if (page.isEmpty) {
          break;
        }
        after = page.last[primaryKey] as String;
      }
      changes[keys[index]] = rows;
    }
    try {
      await db.transaction(() async {
        if (_activeCacheWrites != 0 || revision != _cacheRevision) {
          return;
        }
        if (!await _hasAccess(classId)) {
          return;
        }
        final postIds =
            (await (db.select(db.cachePosts)..where(
                      (p) => p.classId.equals(classId) & p.deletedAt.isNull(),
                    ))
                    .get())
                .map((p) => p.id)
                .toSet();
        for (final row in changes[keys[0]]!) {
          if (row['deleted_at'] != null) {
            await (db.delete(
              db.cacheSubmissions,
            )..where((s) => s.id.equals(row['id'] as String))).go();
          } else if (postIds.contains(row['post_id'])) {
            await db
                .into(db.cacheSubmissions)
                .insertOnConflictUpdate(
                  CacheSubmission.fromJson(_cacheJson(row)).toCompanion(false),
                );
          }
        }
        final submissionIds =
            (await (db.select(db.cacheSubmissions)..where(
                      (s) =>
                          s.studentId.equals(userId) & s.postId.isIn(postIds),
                    ))
                    .get())
                .map((s) => s.id)
                .toSet();
        for (final row in changes[keys[1]]!) {
          if (row['deleted_at'] != null) {
            await (db.delete(
              db.cacheSubmissionItems,
            )..where((i) => i.id.equals(row['id'] as String))).go();
          } else if (submissionIds.contains(row['submission_id'])) {
            await db
                .into(db.cacheSubmissionItems)
                .insertOnConflictUpdate(
                  CacheSubmissionItem.fromJson(_cacheJson(row))
                      .toCompanion(false),
                );
          }
        }
        for (final row in changes[keys[2]]!) {
          final id = row['submission_id'] as String;
          if (row['deleted_at'] != null || row['returned_at'] == null) {
            await (db.delete(
              db.cacheGrades,
            )..where((g) => g.submissionId.equals(id))).go();
          } else if (submissionIds.contains(id)) {
            await db
                .into(db.cacheGrades)
                .insertOnConflictUpdate(
                  CacheGrade.fromJson(_cacheJson(row)).toCompanion(false),
                );
          }
        }
        for (final entry in changes.entries) {
          var cursor = cursors[entry.key];
          for (final row in entry.value) {
            final updated = DateTime.parse(row['updated_at'] as String);
            if (cursor == null || updated.isAfter(cursor)) {
              cursor = updated;
            }
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
        if (_activeCacheWrites != 0 || revision != _cacheRevision) {
          // A write began while SQLite work yielded. Roll back the snapshot and
          // its checkpoints together; the next ordinary pull will replay it.
          throw _ConcurrentSubmissionWrite();
        }
      });
    } on _ConcurrentSubmissionWrite {
      return;
    }
  }

  // RPCs are never queued or automatically retried: an uncertain response must
  // be reconciled by syncing before a caller offers the action again.
  Future<CacheSubmission> startSubmission(String postId) =>
      _mutate('start_submission', {'p_post': postId});
  Future<CacheSubmission> turnIn(String submissionId, {String? comment}) =>
      _mutate('turn_in', {'p_submission': submissionId, 'p_comment': comment});
  Future<CacheSubmission> unsubmit(String submissionId) =>
      _mutate('unsubmit', {'p_submission': submissionId});

  Future<void> reconcileBeforeWorkWrite() async {
    if (!_reconciliationRequired) {
      return;
    }
    if (_activeCacheWrites != 0) {
      throw StateError('Refresh your submission before changing your work.');
    }
    // A timeout cannot establish whether the server committed. Refresh every
    // accessible cached class before another mutation is offered.
    await posts.classes.sync();
    final rooms = await database.select(database.cacheClasses).get();
    for (final room in rooms) {
      // An earlier coalesced pull may intentionally skip its stale snapshot.
      // Wait it out, then start a fresh pull for actual reconciliation.
      await _pending[room.id];
      await sync(room.id);
    }
    _reconciliationRequired = false;
    throw StateError(
      'Submission state refreshed. Review your work before trying again.',
    );
  }

  Future<CacheSubmission> _mutate(
    String function,
    Map<String, dynamic> params,
  ) async {
    if (!isOnline()) {
      throw StateError('Connect to the internet to change your submission.');
    }
    if (_mutating) {
      throw StateError('A submission change is already in progress.');
    }
    _mutating = true;
    try {
      await reconcileBeforeWorkWrite();
      return await _callMutation(function, params);
    } on PostgrestException {
      // An explicit server refusal is a known outcome, not a transport error.
      rethrow;
    } on StateError {
      rethrow;
    } catch (_) {
      _reconciliationRequired = true;
      rethrow;
    } finally {
      _mutating = false;
    }
  }

  /// Re-read settings and the caller's actual saved items immediately before
  /// turn_in. The RPC remains authoritative if an instructor edits concurrently.
  Future<void> _preflightTurnIn(String submissionId) async {
    final own = await client
        .from('submissions')
        .select('post_id')
        .eq('id', submissionId)
        .eq('student_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (own == null) {
      throw StateError('This item is no longer available.');
    }
    final postRow = await client
        .from('posts')
        .select()
        .eq('id', own['post_id'] as String)
        .isFilter('deleted_at', null)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (postRow == null) {
      throw StateError('This item is no longer available.');
    }
    final post = CachePost.fromJson(_cacheJson(postRow));
    if (post.kind != 'assignment' || !await _hasAccess(post.classId)) {
      throw StateError('This item is no longer available.');
    }
    // Publish the latest settings locally even when the existing files now
    // prevent turn-in, so the screen can explain the required removal.
    await database
        .into(database.cachePosts)
        .insertOnConflictUpdate(post.toCompanion(false));
    final items = await client
        .from('submission_items')
        .select()
        .eq('submission_id', submissionId)
        .isFilter('deleted_at', null)
        .timeout(const Duration(seconds: 20));
    await database.transaction(() async {
      final liveIds = items.map((row) => row['id'] as String).toSet();
      await (database.delete(database.cacheSubmissionItems)..where(
            (item) =>
                item.submissionId.equals(submissionId) &
                item.id.isNotIn(liveIds),
          ))
          .go();
      for (final row in items) {
        await database
            .into(database.cacheSubmissionItems)
            .insertOnConflictUpdate(
              CacheSubmissionItem.fromJson(_cacheJson(row)).toCompanion(false),
            );
      }
    });
    final restriction = submissionFileRestriction(
      post,
      items.where((item) => item['kind'] == 'file').length,
    );
    if (restriction != null) {
      throw StateError(restriction);
    }
  }

  Future<CacheSubmission> _callMutation(
    String function,
    Map<String, dynamic> params,
  ) async {
    beginCacheWrite();
    try {
      if (function == 'turn_in') {
        await _preflightTurnIn(params['p_submission'] as String);
      }
      final result = await client
          .rpc(function, params: params)
          .timeout(const Duration(seconds: 20));
      final raw = result is List ? result.single : result;
      final row = CacheSubmission.fromJson(
        _cacheJson(Map<String, dynamic>.from(raw as Map)),
      );
      if (row.studentId != userId) {
        throw StateError('Submission belongs to another account');
      }
      final db = database;
      // Preserve server confirmation even when a subsequent read fails. Null
      // timestamps are written explicitly after unsubmit, not left stale.
      final post =
          await (db.select(db.cachePosts)
                ..where((p) => p.id.equals(row.postId) & p.deletedAt.isNull()))
              .getSingleOrNull();
      if (post != null && await _hasAccess(post.classId)) {
        await db
            .into(db.cacheSubmissions)
            .insertOnConflictUpdate(row.toCompanion(false));
      }
      return row;
    } finally {
      endCacheWrite();
    }
  }
}
