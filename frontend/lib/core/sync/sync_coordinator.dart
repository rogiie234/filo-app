import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import '../../data/local/app_database.dart';
import '../../features/classes/data/class_remote.dart';
import '../../features/classes/data/class_repository.dart';
import '../../features/drive_backup/data/drive_backup_service.dart';
import '../../features/drive_backup/data/drive_api.dart';
import '../../features/files/data/files_repository.dart';
import '../../features/exams/data/exam_remote.dart';
import 'outbox_processor.dart';
import 'sqlite_outbox.dart';

class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator(
    this.db,
    this.client,
    this.userId,
    this.isCurrent, {
    this.backup,
    this.files,
    this.currentAccountCheck,
    this.canSendLeaveEvents,
  });
  final AppDatabase db;
  final SupabaseClient client;
  final String userId;
  final bool Function() isCurrent;
  final DriveBackupService? backup;
  final FilesRepository? files;
  final Future<bool> Function()? currentAccountCheck;
  final bool Function()? canSendLeaveEvents;
  bool _accessChanged = false;
  bool syncing = false, _disposed = false;
  DateTime? lastSynced;
  final errors = <String, String>{};
  DateTime? _lastSnapshot;
  Future<void>? _pending;
  void _notify() {
    if (!_disposed && isCurrent()) {
      notifyListeners();
    }
  }

  Future<void> loadStatus() async {
    final rows = await db
        .customSelect("SELECT value FROM file_settings WHERE key='last_sync'")
        .get();
    if (rows.isNotEmpty) {
      lastSynced = DateTime.tryParse(rows.single.read<String>('value'));
    }
  }

  Future<void> queueNotificationRead(String notificationId) async {
    final stamp = DateTime.now().toUtc();
    await SqliteOutbox(db).enqueue(
      'read:$notificationId',
      'notification_read',
      {'notification_id': notificationId, 'read_at': stamp.toIso8601String()},
    );
    await (db.update(db.cacheNotifications)
          ..where((n) => n.id.equals(notificationId)))
        .write(CacheNotificationsCompanion(readAt: Value(stamp)));
  }

  Future<void> queueLeaveEvent(
    String eventId,
    String sessionId,
    DateTime leftAt,
  ) => SqliteOutbox(db).enqueue(eventId, 'leave_event', {
    'session_id': sessionId,
    'left_at': leftAt.toUtc().toIso8601String(),
  });

  Future<void> dispatch(QueuedAction action) async {
    if (!isCurrent() ||
        currentAccountCheck != null && !await currentAccountCheck!()) {
      throw const DeferredAction();
    }
    switch (action.type) {
      case 'notification_read':
        await client
            .from('notifications')
            .update({'read_at': action.payload['read_at']})
            .eq('id', action.payload['notification_id'] as String)
            .eq('recipient_id', userId);
      case 'leave_event':
        if (canSendLeaveEvents?.call() == false) throw const DeferredAction();
        try {
          await client.rpc(
            'log_leave',
            params: {
              'p_event': action.id,
              'p_session': action.payload['session_id'],
              'p_left_at': action.payload['left_at'],
            },
          );
        } catch (error) {
          throw OutboxActionFailure(examFailure(error).message);
        }
      case 'drive_backup':
        if (backup == null || files == null || !backup!.enabled) {
          throw const DeferredAction();
        }
        final file = await files!.get(action.payload['file_id'] as String);
        if (file == null) {
          await files!.discardBackupCopies(action.payload['file_id'] as String);
        }
        if (file != null && file.backedUpAt == null) {
          try {
            await backup!.backupLocalFile(file, files!);
          } on DriveFailure catch (error) {
            throw OutboxActionFailure(error.message);
          }
        }
      default:
        throw StateError('Unsupported queued action');
    }
  }

  Future<void> run({bool retryFailed = false}) =>
      _pending ??= _run(retryFailed: retryFailed)
          .whenComplete(() => _pending = null);

  Future<void> _run({bool retryFailed = false}) async {
    if (syncing || !isCurrent() || _disposed) {
      return;
    }
    syncing = true;
    _notify();
    _accessChanged = false;
    final snapshot =
        _lastSnapshot == null ||
        DateTime.now().difference(_lastSnapshot!) > const Duration(minutes: 15);
    try {
      final store = SqliteOutbox(
        db,
        includeLeaveEvents: canSendLeaveEvents?.call() ?? true,
      );
      if (retryFailed) {
        await store.retryFailed();
      }
      await backup?.reload();
      if (backup?.enabled == true) {
        await backup!.queueLibrary();
      }
      await OutboxProcessor(store, dispatch).flush();
      await backup?.markLibrarySuccess();
      errors.remove('queue');
      if (!isCurrent() ||
          currentAccountCheck != null && !await currentAccountCheck!()) {
        return;
      }
      try {
        await client.rpc('finalize_accessible_exams');
        errors.remove('exam_expiry');
      } catch (_) {
        errors['exam_expiry'] =
            'Could not refresh exam status. Retry when connected.';
      }
      // Reconcile newly visible old rows, hard deletes and access revocations.
      // Failures do not prevent other tables from pulling.
      try {
        await ClassRepository(db, SupabaseClassRemote(client), userId).sync();
        errors.remove('class_access');
      } catch (_) {
        errors['class_access'] = 'Could not reconcile class access.';
      }
      final profile = await db.readProfile(userId);
      final tables = [
        'profiles',
        'classes',
        'class_members',
        'posts',
        'post_attachments',
        'submissions',
        'submission_items',
        'submission_grades',
        'quizzes',
        'notifications',
        'device_tokens',
        'notification_settings',
        if (profile?.role == 'instructor') ...[
          'questions',
          'exam_sessions',
          'exam_answers',
          'bank_questions',
        ],
      ];
      for (final table in tables) {
        if (!isCurrent()) {
          return;
        }
        try {
          await _pull(table, snapshot || _accessChanged);
          errors.remove(table);
        } catch (_) {
          errors[table] = 'Could not refresh $table. Retry when connected.';
        }
      }
      await _results();
      if (snapshot || _accessChanged) {
        _lastSnapshot = errors.isEmpty ? DateTime.now() : null;
      }
      if (isCurrent()) {
        await _evictRevoked();
        final failed = await db
            .customSelect(
              "SELECT count(*) AS n FROM outbox WHERE status='failed'",
            )
            .getSingle();
        if (failed.read<int>('n') > 0) {
          errors['outbox'] = 'Some pending actions need Retry.';
        } else {
          errors.remove('outbox');
        }
        if (errors.isEmpty) {
          lastSynced = DateTime.now();
          await db.customStatement(
            "INSERT OR REPLACE INTO file_settings(key,value) VALUES('last_sync',?)",
            [lastSynced!.toUtc().toIso8601String()],
          );
        }
      }
    } catch (_) {
      errors['queue'] = 'Could not send pending changes. Try again.';
    } finally {
      syncing = false;
      _notify();
    }
  }

  Future<void> _pull(String table, bool snapshot) async {
    final saved = await db
        .customSelect(
          'SELECT stamp FROM sync_cursors WHERE table_name=?',
          variables: [Variable(table)],
        )
        .get();
    final lower = snapshot || saved.isEmpty
        ? '1970-01-01T00:00:00Z'
        : saved.single.read<String>('stamp');
    final key = table == 'submission_grades' ? 'submission_id' : 'id';
    String? cursorStamp, cursorId, maximum;
    final seen = <String>{};
    while (true) {
      if (currentAccountCheck != null && !await currentAccountCheck!()) {
        return;
      }
      var query = client.from(table).select().gte('updated_at', lower);
      if (cursorStamp != null) {
        query = query.or(
          'updated_at.gt.$cursorStamp,and(updated_at.eq.$cursorStamp,$key.gt.$cursorId)',
        );
      }
      final page = await query
          .order('updated_at', ascending: true)
          .order(key, ascending: true)
          .limit(200)
          .timeout(const Duration(seconds: 20));
      if (!isCurrent()) {
        return;
      }
      if (page.isEmpty) break;
      await db.transaction(() async {
        for (final raw in page) {
          final row = Map<String, dynamic>.from(raw);
          final id = row[key] as String, stamp = row['updated_at'] as String;
          seen.add(id);
          final previous = await db
              .customSelect(
                'SELECT updated_at FROM sync_payloads WHERE table_name=? AND id=?',
                variables: [Variable(table), Variable(id)],
              )
              .get();
          if (previous.isNotEmpty &&
              DateTime.parse(previous.single.read<String>('updated_at'))
                  .isAfter(DateTime.parse(stamp))) {
            continue;
          }
          if (table == 'class_members' &&
              (previous.isEmpty ||
                  previous.single.read<String>('updated_at') != stamp)) {
            _accessChanged = true;
          }
          if (!await _cachedIsNewer(table, id, stamp)) {
            await _apply(table, row);
          }
          await db.customStatement(
            'INSERT OR REPLACE INTO sync_payloads(table_name,id,payload,updated_at) VALUES(?,?,?,?)',
            [table, id, jsonEncode(row), stamp],
          );
        }
      });
      final last = page.last;
      if (cursorStamp == last['updated_at'] && cursorId == last[key]) {
        throw StateError('Non-progressing pull cursor');
      }
      cursorStamp = last['updated_at'] as String;
      cursorId = last[key] as String;
      maximum = cursorStamp;
    }
    if (snapshot) {
      final stale = await db
          .customSelect(
            'SELECT id FROM sync_payloads WHERE table_name=?',
            variables: [Variable(table)],
          )
          .get();
      for (final row in stale) {
        final id = row.read<String>('id');
        if (!seen.contains(id)) {
          await _remove(table, id);
          await db.customStatement(
            'DELETE FROM sync_payloads WHERE table_name=? AND id=?',
            [table, id],
          );
        }
      }
    }
    if (maximum != null) {
      await db.customStatement(
        'INSERT OR REPLACE INTO sync_cursors(table_name,stamp) VALUES(?,?)',
        [table, maximum],
      );
    }
  }

  Map<String, dynamic> _json(Map<String, dynamic> row) => {
    for (final entry in row.entries)
      entry.key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (m) => m[1]!.toUpperCase(),
      ): (entry.key.endsWith('_at') || entry.key == 'unsubmit_until') &&
              entry.value != null
          ? DateTime.parse(entry.value as String).millisecondsSinceEpoch
          : entry.value,
  };
  Future<bool> _exists(String table, String key, dynamic id) async =>
      id == null ||
      (await db
              .customSelect(
                'SELECT 1 FROM $table WHERE $key=?',
                variables: [Variable(id as String)],
              )
              .get())
          .isNotEmpty;

  Future<bool> _cachedIsNewer(
    String table,
    String id,
    String remoteStamp,
  ) async {
    const tables = {
      'profiles': 'cache_profiles',
      'classes': 'cache_classes',
      'class_members': 'cache_class_members',
      'posts': 'cache_posts',
      'post_attachments': 'cache_post_attachments',
      'submissions': 'cache_submissions',
      'submission_items': 'cache_submission_items',
      'submission_grades': 'cache_grades',
      'quizzes': 'cache_quizzes',
    };
    final local = tables[table];
    if (local == null) {
      return false;
    }
    final key = table == 'submission_grades' ? 'submission_id' : 'id';
    final rows = await db
        .customSelect(
          'SELECT updated_at FROM $local WHERE $key=?',
          variables: [Variable(id)],
        )
        .get();
    if (rows.isEmpty) {
      return false;
    }
    final raw = rows.single.data['updated_at'];
    final cached = raw is int
        ? DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true)
        : DateTime.parse(raw as String);
    return cached.isAfter(DateTime.parse(remoteStamp));
  }

  Future<void> _apply(String table, Map<String, dynamic> row) async {
    final data = _json(row);
    switch (table) {
      case 'profiles':
        await db
            .into(db.cacheProfiles)
            .insertOnConflictUpdate(
              CacheProfile.fromJson(data).toCompanion(false),
            );
      case 'classes':
        if (await _exists('cache_profiles', 'id', row['owner_id'])) {
          await db
              .into(db.cacheClasses)
              .insertOnConflictUpdate(
                CacheClassesData.fromJson(data).toCompanion(false),
              );
        }
      case 'class_members':
        if (await _exists('cache_classes', 'id', row['class_id']) &&
            await _exists('cache_profiles', 'id', row['student_id']) &&
            await _exists('cache_profiles', 'id', row['decided_by'])) {
          await db
              .into(db.cacheClassMembers)
              .insertOnConflictUpdate(
                CacheClassMember.fromJson(data).toCompanion(false),
              );
        }
      case 'posts':
        if (await _exists('cache_classes', 'id', row['class_id']) &&
            await _exists('cache_profiles', 'id', row['author_id'])) {
          await db
              .into(db.cachePosts)
              .insertOnConflictUpdate(
                CachePost.fromJson(data).toCompanion(false),
              );
        }
      case 'post_attachments':
        if (await _exists('cache_posts', 'id', row['post_id'])) {
          await db
              .into(db.cachePostAttachments)
              .insertOnConflictUpdate(
                CachePostAttachment.fromJson(data).toCompanion(false),
              );
        }
      case 'submissions':
        if (row['student_id'] == userId &&
            await _exists('cache_posts', 'id', row['post_id'])) {
          await db
              .into(db.cacheSubmissions)
              .insertOnConflictUpdate(
                CacheSubmission.fromJson(data).toCompanion(false),
              );
        }
      case 'submission_items':
        if (await _exists('cache_submissions', 'id', row['submission_id'])) {
          await db
              .into(db.cacheSubmissionItems)
              .insertOnConflictUpdate(
                CacheSubmissionItem.fromJson(data).toCompanion(false),
              );
        }
      case 'submission_grades':
        if (row['returned_at'] != null &&
            await _exists('cache_submissions', 'id', row['submission_id']) &&
            await _exists('cache_profiles', 'id', row['graded_by'])) {
          await db
              .into(db.cacheGrades)
              .insertOnConflictUpdate(
                CacheGrade.fromJson(data).toCompanion(false),
              );
        }
      case 'quizzes':
        if (await _exists('cache_classes', 'id', row['class_id']) &&
            await _exists('cache_profiles', 'id', row['author_id'])) {
          await db
              .into(db.cacheQuizzes)
              .insertOnConflictUpdate(
                CacheQuizze.fromJson(data).toCompanion(false),
              );
        }
      case 'notifications':
        if (await _exists('cache_profiles', 'id', row['recipient_id'])) {
          if (!await _exists('cache_classes', 'id', row['class_id'])) {
            data['classId'] = null;
          }
          await db
              .into(db.cacheNotifications)
              .insertOnConflictUpdate(
                CacheNotification.fromJson(data).toCompanion(false),
              );
        }
    }
  }

  Future<void> _remove(String table, String id) async {
    const names = {
      'profiles': 'cache_profiles',
      'classes': 'cache_classes',
      'class_members': 'cache_class_members',
      'posts': 'cache_posts',
      'post_attachments': 'cache_post_attachments',
      'submissions': 'cache_submissions',
      'submission_items': 'cache_submission_items',
      'submission_grades': 'cache_grades',
      'quizzes': 'cache_quizzes',
      'notifications': 'cache_notifications',
    };
    final local = names[table];
    // Profile references may survive account deletion; anonymized server rows are authoritative.
    if (local != null && table != 'profiles') {
      await db.customStatement(
        'DELETE FROM $local WHERE ${table == 'submission_grades' ? 'submission_id' : 'id'}=?',
        [id],
      );
      db.notifyUpdates({TableUpdate(local)});
    }
  }

  Future<void> _results() async {
    for (final cached in await db.select(db.cacheResults).get()) {
      if (!isCurrent()) {
        return;
      }
      try {
        final raw = await client
            .rpc('get_result', params: {'p_session': cached.sessionId})
            .timeout(const Duration(seconds: 20));
        final result = Map<String, dynamic>.from(raw as Map);
        await db
            .into(db.cacheResults)
            .insertOnConflictUpdate(
              CacheResult(
                sessionId: cached.sessionId,
                score: result['score'] as int,
                totalPoints: result['total_points'] as int,
                percent: result['percent'] as int,
                passed: result['passed'] as bool?,
                review: result['review'] == null
                    ? null
                    : jsonEncode(result['review']),
              ),
            );
        errors.remove('result:${cached.sessionId}');
      } on PostgrestException catch (error) {
        if (error.code == '42501' ||
            error.message.contains('Session not found') ||
            error.message.contains('not available yet')) {
          await (db.delete(
            db.cacheResults,
          )..where((r) => r.sessionId.equals(cached.sessionId))).go();
        }
        if (error.code == '42501' ||
            error.message.contains('Session not found') ||
            error.message.contains('not available yet')) {
          errors.remove('result:${cached.sessionId}');
        } else {
          errors['result:${cached.sessionId}'] =
              'Could not refresh released result.';
        }
      } catch (_) {
        errors['result:${cached.sessionId}'] =
            'Could not refresh released result.';
      }
    }
  }

  Future<void> _evictRevoked() async {
    final memberships = await db
        .customSelect(
          "SELECT payload FROM sync_payloads WHERE table_name='class_members'",
        )
        .get();
    for (final item in memberships) {
      final row =
          jsonDecode(item.read<String>('payload')) as Map<String, dynamic>;
      if (row['student_id'] == userId &&
          ['removed', 'left', 'declined'].contains(row['status'])) {
        await (db.delete(db.cacheClasses)..where(
              (c) =>
                  c.id.equals(row['class_id'] as String) &
                  c.ownerId.equals(userId).not(),
            ))
            .go();
        // Drop content payloads too; local_files/local_folders have no cache FK.
        final payloads = await db
            .customSelect(
              "SELECT table_name,id,payload FROM sync_payloads WHERE table_name IN ('classes','posts','post_attachments','submissions','submission_items','submission_grades','quizzes')",
            )
            .get();
        final postIds = <String>{}, subIds = <String>{};
        for (final record in payloads) {
          final value = jsonDecode(
            record.read<String>('payload'),
          ) as Map<String, dynamic>;
          if (record.read<String>('table_name') == 'posts' &&
              value['class_id'] == row['class_id']) {
            postIds.add(record.read<String>('id'));
          }
        }
        for (final record in payloads) {
          final value = jsonDecode(
            record.read<String>('payload'),
          ) as Map<String, dynamic>;
          if (record.read<String>('table_name') == 'submissions' &&
              postIds.contains(value['post_id'])) {
            subIds.add(record.read<String>('id'));
          }
        }
        for (final record in payloads) {
          final value = jsonDecode(
            record.read<String>('payload'),
          ) as Map<String, dynamic>;
          if (value['class_id'] == row['class_id'] ||
              postIds.contains(value['post_id']) ||
              subIds.contains(value['submission_id']) ||
              record.read<String>('table_name') == 'classes' &&
                  value['id'] == row['class_id']) {
            await db.customStatement(
              'DELETE FROM sync_payloads WHERE table_name=? AND id=?',
              [record.read<String>('table_name'), record.read<String>('id')],
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
