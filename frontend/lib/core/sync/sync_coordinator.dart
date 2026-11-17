import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../data/local/app_database.dart';
import '../../data/local/cache_row_json.dart';
import '../../features/classes/data/class_remote.dart';
import '../../features/classes/data/class_repository.dart';
import '../../features/drive_backup/data/drive_backup_service.dart';
import '../../features/drive_backup/data/drive_api.dart';
import '../../features/files/data/files_repository.dart';
import '../../features/exams/data/exam_remote.dart';
import '../../features/results/data/results_cache.dart';
import '../../features/results/data/quiz_grades_repository.dart';
import '../../features/results/data/results_remote.dart';
import '../../features/results/data/results_failure.dart';
import '../../features/results/data/student_results_repository.dart';
import 'outbox_processor.dart';
import 'sqlite_outbox.dart';
import '../../features/exams/data/exam_store.dart';
import '../notifications/deadline_reminders.dart';
import '../../features/notifications/data/notification_settings_repository.dart';

String classRefreshDiagnostic(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  // Native Drift workers serialize exceptions to strings across isolates.
  final text = cause.toString();
  final code = cause is SqliteException
      ? '${cause.extendedResultCode}'
      : RegExp(r'^SqliteException\((\d+)\)').firstMatch(text)?.group(1);
  if (code == null) {
    return cause is String
        ? 'Database worker error'
        : cause.runtimeType.toString();
  }
  final table = [
    'cache_profiles',
    'cache_classes',
    'cache_class_members',
    'sync_state',
  ].where(text.contains).firstOrNull;
  return 'SQLite $code${table == null ? '' : ', $table'}';
}

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
  bool classesLoaded = false, attemptedSync = false;
  bool get classesFailed =>
      errors.containsKey('class_access') ||
      errors.containsKey('classes') ||
      errors.containsKey('class_members') ||
      (attemptedSync && !classesLoaded && !syncing);
  DateTime? lastSynced;
  final errors = <String, String>{};
  String get failureSummary {
    final pending = errors.containsKey('outbox') || errors.containsKey('queue');
    final refresh = errors.keys.any(
      (key) => !{'outbox', 'queue', 'drive_backup'}.contains(key),
    );
    if (pending && refresh) {
      return 'Some changes could not send, and some information could not refresh.';
    }
    if (pending) return 'Some pending changes could not send.';
    if (refresh) return 'Some information could not refresh. Please try again.';
    return 'Drive backup needs attention. Open Backup details to check permission or retry.';
  }

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

  Future<void>? _notificationRefresh;
  Future<void> _notificationWork = Future.value();
  Future<T> _serializeNotifications<T>(Future<T> Function() action) {
    final result = _notificationWork.then((_) => action());
    _notificationWork = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> refreshNotifications() =>
      _notificationRefresh ??= _serializeNotifications(_refreshNotifications)
          .whenComplete(() => _notificationRefresh = null);

  Future<void> _refreshNotifications() async {
    if (!isCurrent() || _disposed) return;
    await _pull('notifications', false);
    await _reconcileNotifications();
  }

  /// Fetches only this account's canonical row; never trusts push display fields.
  Future<CacheNotification?> refreshNotification(String id) =>
      _serializeNotifications(() => _refreshNotification(id));

  Future<CacheNotification?> _refreshNotification(String id) async {
    if (!isCurrent() || _disposed) throw StateError('Account changed');
    final row = await client
        .from('notifications')
        .select()
        .eq('id', id)
        .eq('recipient_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (!isCurrent() || _disposed) throw StateError('Account changed');
    if (row == null) {
      await db.transaction(() async {
        if (!isCurrent() || _disposed) throw StateError('Account changed');
        await _remove('notifications', id);
        await db.customStatement(
          "DELETE FROM sync_payloads WHERE table_name='notifications' AND id=?",
          [id],
        );
        if (!isCurrent() || _disposed) throw StateError('Account changed');
      });
      return null;
    }
    if (await db.readProfile(userId) == null) {
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 20));
      if (!isCurrent() || _disposed) throw StateError('Account changed');
      await _apply('profiles', profile);
    }
    await db.transaction(() async {
      if (!isCurrent() || _disposed) throw StateError('Account changed');
      final previous = await db
          .customSelect(
            "SELECT updated_at FROM sync_payloads WHERE table_name='notifications' AND id=?",
            variables: [Variable(id)],
          )
          .get();
      if (previous.isEmpty ||
          !DateTime.parse(previous.single.read<String>('updated_at'))
              .isAfter(DateTime.parse(row['updated_at'] as String))) {
        await _apply('notifications', row);
        await db.customStatement(
          "INSERT OR REPLACE INTO sync_payloads(table_name,id,payload,updated_at) VALUES('notifications',?,?,?)",
          [id, jsonEncode(row), row['updated_at']],
        );
      }
      if (!isCurrent() || _disposed) throw StateError('Account changed');
    });
    return (db.select(db.cacheNotifications)
          ..where((n) => n.id.equals(id) & n.recipientId.equals(userId)))
        .getSingleOrNull();
  }

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
            .eq('recipient_id', userId)
            .timeout(const Duration(seconds: 20));
      case 'leave_event':
        if (canSendLeaveEvents?.call() == false) throw const DeferredAction();
        final integrity = await ExamStore(db)
            .integrity(action.payload['session_id'] as String);
        if (integrity.atLimit && !integrity.ready) throw const DeferredAction();
        try {
          await client
              .rpc(
                'log_leave',
                params: {
                  'p_event': action.id,
                  'p_session': action.payload['session_id'],
                  'p_left_at': action.payload['left_at'],
                },
              )
              .timeout(const Duration(seconds: 20));
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

  Future<void>? _classRefresh;
  Future<void> flushLeaveEvents(String sessionId) async {
    if (_disposed || !isCurrent() || canSendLeaveEvents?.call() != true) return;
    final integrity = await ExamStore(db).integrity(sessionId);
    if (integrity.atLimit && !integrity.ready) return;
    // Release deferral delays, never a worker's active lease or network backoff.
    await db.customStatement(
      '''
      UPDATE outbox_schedule SET next_at=NULL
      WHERE id IN (SELECT id FROM outbox WHERE action_type='leave_event'
        AND json_extract(payload,'\$.session_id')=? AND status='pending'
        AND last_error='Waiting for connectivity or authorization.')
    ''',
      [sessionId],
    );
    await OutboxProcessor(
      SqliteOutbox(db, leaveSessionId: sessionId),
      dispatch,
    ).flush();
  }

  Future<void> refreshClasses() => _classRefresh ??= _refreshClasses()
      .whenComplete(() => _classRefresh = null);

  Future<void> _refreshClasses() async {
    if (!isCurrent() || _disposed) return;
    try {
      if (currentAccountCheck != null && !await currentAccountCheck!()) return;
      if (!isCurrent() || _disposed) return;
      await ClassRepository(db, SupabaseClassRemote(client), userId).sync();
      if (!isCurrent() || _disposed) return;
      classesLoaded = true;
      for (final key in ['class_access', 'classes', 'class_members']) {
        errors.remove(key);
      }
    } catch (error, stack) {
      if (!isCurrent() || _disposed) return;
      // Never log SQL, bound values, raw responses or account contents.
      errors['class_access'] =
          'Class refresh failed (${classRefreshDiagnostic(error)}).';
      if (kDebugMode) {
        debugPrint(errors['class_access']);
        debugPrintStack(
          stackTrace: error is DriftRemoteException
              ? error.remoteStackTrace ?? stack
              : stack,
        );
      }
    } finally {
      _notify();
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
      await refreshClasses();
      if (const DeadlineBridge().supported) {
        await db.customStatement(
          "INSERT OR REPLACE INTO file_settings(key,value) VALUES('deadline_trusted','0')",
        );
      }
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
      } catch (_) {
        errors['queue'] = 'Could not send pending changes. Try again.';
      }
      if (!isCurrent() ||
          currentAccountCheck != null && !await currentAccountCheck!()) {
        return;
      }
      try {
        await client
            .rpc('finalize_accessible_exams')
            .timeout(const Duration(seconds: 20));
        errors.remove('exam_expiry');
      } catch (_) {
        errors['exam_expiry'] =
            'Could not refresh exam status. Retry when connected.';
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
          // Inbox hard deletes must reconcile on the next successful sync.
          if (table == 'notifications') {
            await refreshNotifications();
          } else if (table == 'notification_settings') {
            await NotificationSettingsRepository(
              db,
              client,
              userId,
              () => !_disposed && isCurrent(),
              online: () => true,
            ).refresh();
          } else {
            await _pull(table, snapshot || _accessChanged);
          }
          errors.remove(table);
        } catch (_) {
          errors[table] = 'Could not refresh $table. Retry when connected.';
        }
      }
      await _results();
      final quizGrades = QuizGradesRepository(
        ResultsCache(db, userId, isCurrent),
        SupabaseResultsRemote(client, userId),
      );
      final gradeClassIds = <String>{};
      for (final room in await db.select(db.cacheClasses).get()) {
        if (!isCurrent()) return;
        if (room.deletedAt != null) continue;
        if (room.ownerId != userId) {
          final member =
              await (db.select(db.cacheClassMembers)..where(
                    (m) =>
                        m.classId.equals(room.id) &
                        m.studentId.equals(userId) &
                        m.status.equals('active'),
                  ))
                  .getSingleOrNull();
          if (member == null) continue;
        }
        gradeClassIds.add(room.id);
        try {
          await quizGrades.refresh(room.id);
          errors.remove('quiz_grades:${room.id}');
        } catch (_) {
          errors['quiz_grades:${room.id}'] = 'Could not refresh quiz grades.';
        }
      }
      if (!classesFailed) {
        errors.removeWhere(
          (key, _) =>
              key.startsWith('quiz_grades:') &&
              !gradeClassIds.contains(key.substring('quiz_grades:'.length)),
        );
      }
      if (snapshot || _accessChanged) {
        _lastSnapshot = errors.isEmpty ? DateTime.now() : null;
      }
      if (isCurrent()) {
        await _evictRevoked();
        try {
          final trusted = [
            'profiles',
            'classes',
            'class_members',
            'posts',
            'submissions',
            'class_access',
          ].every((key) => !errors.containsKey(key));
          await DeadlineReminders(
            db,
            userId,
            () => !_disposed && isCurrent(),
          ).reconcile(trusted: trusted);
          errors.remove('deadline_reminders');
        } catch (_) {
          errors['deadline_reminders'] =
              'Could not update deadline reminders. Retry.';
        }
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
        final driveFailures = await db
            .customSelect(
              "SELECT count(*) AS n FROM outbox WHERE action_type='drive_backup' AND status='failed'",
            )
            .getSingle();
        if (driveFailures.read<int>('n') > 0 ||
            backup?.permissionRequired == true) {
          errors['drive_backup'] = 'Drive backup needs attention.';
        } else {
          errors.remove('drive_backup');
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
      attemptedSync = true;
      syncing = false;
      _notify();
    }
  }

  Future<void> _reconcileNotifications() async {
    final seen = <String>{};
    String? after;
    while (true) {
      if (!isCurrent() ||
          currentAccountCheck != null && !await currentAccountCheck!()) {
        return;
      }
      var query = client
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId);
      if (after != null) query = query.gt('id', after);
      final page = await query
          .order('id')
          .limit(200)
          .timeout(const Duration(seconds: 20));
      if (!isCurrent()) return;
      if (page.isEmpty) break;
      final next = page.last['id'] as String;
      if (after != null && next.compareTo(after) <= 0) {
        throw StateError('Non-progressing inbox reconciliation');
      }
      seen.addAll(page.map((row) => row['id'] as String));
      after = next;
    }
    if (!isCurrent() ||
        currentAccountCheck != null && !await currentAccountCheck!()) {
      return;
    }
    await db.transaction(() async {
      final local = await (db.select(
        db.cacheNotifications,
      )..where((n) => n.recipientId.equals(userId))).get();
      final payloads = await db
          .customSelect(
            "SELECT id FROM sync_payloads WHERE table_name='notifications'",
          )
          .get();
      final ids = {
        ...local.map((n) => n.id),
        ...payloads.map((r) => r.read<String>('id')),
      };
      for (final id in ids.difference(seen)) {
        if (!isCurrent()) {
          throw StateError('Account changed during reconciliation');
        }
        await _remove('notifications', id);
        await db.customStatement(
          "DELETE FROM sync_payloads WHERE table_name='notifications' AND id=?",
          [id],
        );
      }
      if (!isCurrent() ||
          currentAccountCheck != null && !await currentAccountCheck!()) {
        throw StateError('Account changed during reconciliation');
      }
    });
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
      if (table == 'notifications') query = query.eq('recipient_id', userId);
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
      if (!isCurrent() ||
          currentAccountCheck != null && !await currentAccountCheck!()) {
        return;
      }
      await db.transaction(() async {
        final stale = await db
            .customSelect(
              'SELECT id FROM sync_payloads WHERE table_name=?',
              variables: [Variable(table)],
            )
            .get();
        for (final row in stale) {
          if (!isCurrent()) {
            throw StateError('Account changed during reconciliation');
          }
          final id = row.read<String>('id');
          if (!seen.contains(id)) {
            await _remove(table, id);
            await db.customStatement(
              'DELETE FROM sync_payloads WHERE table_name=? AND id=?',
              [table, id],
            );
          }
        }
        if (!isCurrent()) {
          throw StateError('Account changed during reconciliation');
        }
      });
    }
    if (maximum != null) {
      await db.customStatement(
        'INSERT OR REPLACE INTO sync_cursors(table_name,stamp) VALUES(?,?)',
        [table, maximum],
      );
    }
  }

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

  Future<bool> _requireCached(String table, String key, dynamic id) async {
    if (!await _exists(table, key, id)) {
      throw StateError('Cache dependency unavailable: $table');
    }
    return true;
  }

  Future<void> _apply(String table, Map<String, dynamic> row) async {
    if (const {
          'submissions',
          'submission_items',
          'submission_grades',
        }.contains(table) &&
        (await db.readProfile(userId))?.role == 'instructor') {
      return;
    }
    if (table == 'class_members' &&
        !await _exists('cache_classes', 'id', row['class_id'])) {
      final parent = await db
          .customSelect(
            "SELECT payload FROM sync_payloads WHERE table_name='classes' AND id=?",
            variables: [Variable(row['class_id'] as String)],
          )
          .getSingleOrNull();
      if (!['active', 'pending'].contains(row['status']) ||
          parent != null &&
              (jsonDecode(parent.read<String>('payload'))
                      as Map)['deleted_at'] !=
                  null) {
        return;
      }
    }
    final data = cacheRowJson(row, extraDateFields: const {'unsubmit_until'});
    switch (table) {
      case 'profiles':
        await db
            .into(db.cacheProfiles)
            .insertOnConflictUpdate(
              CacheProfile.fromJson(data).toCompanion(false),
            );
      case 'classes':
        if (row['deleted_at'] != null && row['owner_id'] != userId) {
          await _remove('classes', row['id'] as String);
        } else if (await _requireCached(
          'cache_profiles',
          'id',
          row['owner_id'],
        )) {
          await db
              .into(db.cacheClasses)
              .insertOnConflictUpdate(
                CacheClassesData.fromJson(data).toCompanion(false),
              );
        }
      case 'class_members':
        if (await _requireCached('cache_classes', 'id', row['class_id']) &&
            await _requireCached('cache_profiles', 'id', row['student_id']) &&
            await _requireCached('cache_profiles', 'id', row['decided_by'])) {
          await db
              .into(db.cacheClassMembers)
              .insertOnConflictUpdate(
                CacheClassMember.fromJson(data).toCompanion(false),
              );
        }
      case 'posts':
        if (await _requireCached('cache_classes', 'id', row['class_id']) &&
            await _requireCached('cache_profiles', 'id', row['author_id'])) {
          await db
              .into(db.cachePosts)
              .insertOnConflictUpdate(
                CachePost.fromJson(data).toCompanion(false),
              );
        }
      case 'post_attachments':
        if (await _requireCached('cache_posts', 'id', row['post_id'])) {
          await db
              .into(db.cachePostAttachments)
              .insertOnConflictUpdate(
                CachePostAttachment.fromJson(data).toCompanion(false),
              );
        }
      case 'submissions':
        if (row['student_id'] == userId &&
            await _requireCached('cache_posts', 'id', row['post_id'])) {
          await db
              .into(db.cacheSubmissions)
              .insertOnConflictUpdate(
                CacheSubmission.fromJson(data).toCompanion(false),
              );
        }
      case 'submission_items':
        if (await _requireCached(
          'cache_submissions',
          'id',
          row['submission_id'],
        )) {
          await db
              .into(db.cacheSubmissionItems)
              .insertOnConflictUpdate(
                CacheSubmissionItem.fromJson(data).toCompanion(false),
              );
        }
      case 'submission_grades':
        if (row['returned_at'] != null &&
            await _requireCached(
              'cache_submissions',
              'id',
              row['submission_id'],
            ) &&
            await _requireCached('cache_profiles', 'id', row['graded_by'])) {
          await db
              .into(db.cacheGrades)
              .insertOnConflictUpdate(
                CacheGrade.fromJson(data).toCompanion(false),
              );
        }
      case 'quizzes':
        if (await _requireCached('cache_classes', 'id', row['class_id']) &&
            await _requireCached('cache_profiles', 'id', row['author_id'])) {
          await db
              .into(db.cacheQuizzes)
              .insertOnConflictUpdate(
                CacheQuizze.fromJson(data).toCompanion(false),
              );
        }
      case 'notifications':
        if (row['recipient_id'] != userId) return;
        // A failed/deferred upload must not undo the account's local read mark.
        final pending =
            await (db.select(db.outbox)..where(
                  (o) =>
                      o.id.equals('read:${row['id']}') &
                      o.status.equals('complete').not(),
                ))
                .getSingleOrNull();
        if (pending != null) {
          final payload = jsonDecode(pending.payload) as Map<String, dynamic>;
          data['readAt'] = DateTime.parse(payload['read_at'] as String)
              .millisecondsSinceEpoch;
        }
        if (await _requireCached('cache_profiles', 'id', row['recipient_id'])) {
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
    final cache = ResultsCache(db, userId, isCurrent);
    final repository = StudentResultsRepository(
      cache,
      SupabaseResultsRemote(client, userId),
      () => true,
    );
    final rows = await db
        .customSelect(
          "SELECT id FROM results_snapshots WHERE id LIKE 'student:%'",
        )
        .get();
    final quizIds = rows
        .map((row) => row.read<String>('id').substring('student:'.length))
        .toSet();
    // Older installations may have released rows with only catalog metadata.
    final cachedIds = (await db.select(db.cacheResults).get())
        .map((row) => row.sessionId)
        .toSet();
    for (final row
        in await db
            .customSelect('SELECT id,payload FROM student_quiz_catalog')
            .get()) {
      final payload = jsonDecode(row.read<String>('payload')) as Map;
      if (cachedIds.contains((payload['session'] as Map?)?['session_id'])) {
        quizIds.add(row.read<String>('id'));
      }
    }
    if (!classesFailed && !errors.containsKey('quizzes')) {
      errors.removeWhere(
        (key, _) =>
            key.startsWith('result:') &&
            !quizIds.contains(key.substring('result:'.length)),
      );
    }
    for (final quizId in quizIds) {
      if (!isCurrent()) return;
      try {
        await repository.refresh(quizId);
        errors.remove('result:$quizId');
      } on ResultsFailure catch (error) {
        if (error.unavailable) {
          errors.remove('result:$quizId');
        } else {
          errors['result:$quizId'] = error.message;
        }
      } catch (_) {
        errors['result:$quizId'] = 'Could not refresh released result.';
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
