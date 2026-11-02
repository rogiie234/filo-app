import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/local/app_database.dart';

class PhoneGuideCapabilities {
  const PhoneGuideCapabilities(this.sdk, this.xiaomi);
  final int sdk;
  final bool xiaomi;
  bool get exactStep => sdk >= 31;
}

class DeadlineBridge {
  const DeadlineBridge();
  static const channel = MethodChannel('com.filo.filo/deadline_reminders');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> activate(String account, String lease, String database) async {
    if (supported)
      await channel.invokeMethod<void>('activate', {
        'accountId': account,
        'lease': lease,
        'database': database,
      });
  }

  Future<void> reconcile(String account, String lease) async {
    if (supported)
      await channel.invokeMethod<void>('reconcile', {
        'accountId': account,
        'lease': lease,
      });
  }

  Future<void> clearAccount(String accountId) async {
    if (supported)
      await channel.invokeMethod<void>('clearAccount', {
        'accountId': accountId,
      });
  }

  Future<void> clear() async {
    if (supported) await channel.invokeMethod<void>('clear');
  }

  Future<List<dynamic>> reconcileStudy(String account, String lease) async =>
      supported
      ? (await channel.invokeListMethod<dynamic>('studyReconcile', {
          'accountId': account,
          'lease': lease,
        }))!
      : [];

  Future<Map<String, dynamic>> status() async => supported
      ? Map<String, dynamic>.from(
          (await channel.invokeMapMethod<String, dynamic>('status'))!,
        )
      : {'enabled': false, 'exact': false, 'error': false};
  Future<void> openSettings(String section) async {
    if (supported)
      await channel.invokeMethod<void>('openSettings', {'section': section});
  }

  Future<PhoneGuideCapabilities> guideCapabilities() async {
    if (!supported) return const PhoneGuideCapabilities(0, false);
    final data = await channel.invokeMapMethod<String, dynamic>(
      'guideCapabilities',
    );
    final sdk = data?['sdk'], xiaomi = data?['xiaomi'];
    if (sdk is! int || sdk < 0 || xiaomi is! bool)
      throw StateError('Phone capabilities unavailable');
    return PhoneGuideCapabilities(sdk, xiaomi);
  }

  Future<String> guideOpenSettings(String section) async {
    if (!supported) return 'failed';
    final result = await channel.invokeMethod<String>('guideOpenSettings', {
      'section': section,
    });
    if (!['direct', 'app_details', 'failed'].contains(result))
      throw StateError('Phone settings unavailable');
    return result!;
  }
}

List<DateTime> deadlineTimes(DateTime due, DateTime now) => [
  due.toUtc().subtract(const Duration(hours: 24)),
  due.toUtc().subtract(const Duration(hours: 1)),
].where((time) => time.isAfter(now.toUtc())).toList();

class DeadlineReminders {
  DeadlineReminders(
    this.db,
    this.userId,
    this.isCurrent, {
    this.bridge = const DeadlineBridge(),
  });
  final AppDatabase db;
  final String userId;
  final bool Function() isCurrent;
  final DeadlineBridge bridge;
  static final _work = Expando<Future<void>>();
  void _check() {
    if (!isCurrent()) throw StateError('Reminder account changed');
  }

  Future<String> _setting(String key) async {
    final rows = await db
        .customSelect(
          'SELECT value FROM file_settings WHERE key=?',
          variables: [Variable(key)],
        )
        .get();
    return rows.isEmpty ? '' : rows.single.read<String>('value');
  }

  Future<void> _save(String key, String value) => db.customStatement(
    'INSERT OR REPLACE INTO file_settings(key,value) VALUES(?,?)',
    [key, value],
  );

  Future<void> reconcile({bool? trusted, String? confirmedPostId}) {
    if (!bridge.supported) return Future.value();
    final result = (_work[db] ?? Future<void>.value()).then(
      (_) => _reconcile(trusted, confirmedPostId),
    );
    _work[db] = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _reconcile(bool? trusted, String? confirmedPostId) async {
    _check();
    try {
      if (trusted != null) await _save('deadline_trusted', trusted ? '1' : '0');
      final complete = await _setting('deadline_trusted') == '1';
      final profile = await db.readProfile(userId);
      final posts = {
        for (final p in await db.select(db.cachePosts).get()) p.id: p,
      };
      final rooms = {
        for (final c in await db.select(db.cacheClasses).get()) c.id: c,
      };
      final members = {
        for (final m in await (db.select(
          db.cacheClassMembers,
        )..where((m) => m.studentId.equals(userId))).get())
          m.classId: m,
      };
      final submissions = {
        for (final s in await (db.select(
          db.cacheSubmissions,
        )..where((s) => s.studentId.equals(userId))).get())
          s.postId: s,
      };
      final previous = await db.select(db.deadlineReminders).get();
      final oldPlan = await _setting('deadline_desired');
      final oldContent = {
        for (final row
            in oldPlan.isEmpty ? <dynamic>[] : jsonDecode(oldPlan) as List)
          (row as Map)['id']: Map<String, dynamic>.from(row),
      };
      final now = db.now().toUtc();
      var next = int.tryParse(await _setting('deadline_next_id')) ?? 0;
      for (final row in previous) {
        if (row.systemAlarmId > next) next = row.systemAlarmId;
      }
      final desired = <Map<String, dynamic>>[];
      bool knownInvalid(String postId) {
        final post = posts[postId];
        final room = rooms[post?.classId];
        final member = members[post?.classId];
        return profile != null &&
                (profile.role != 'student' || profile.deletedAt != null) ||
            post != null &&
                (post.deletedAt != null ||
                    post.kind != 'assignment' ||
                    post.dueAt == null) ||
            room != null &&
                (room.deletedAt != null || room.archivedAt != null) ||
            member != null && member.status != 'active' ||
            submissions[postId]?.status == 'turned_in';
      }

      // Incomplete pulls may cancel confirmed invalid rows, never infer absence.
      if (!complete) {
        for (final old in previous) {
          if (!knownInvalid(old.postId) &&
              old.fireAt.toUtc().isAfter(now) &&
              old.postId != confirmedPostId &&
              oldContent[old.systemAlarmId] != null)
            desired.add(oldContent[old.systemAlarmId]!);
        }
      }
      for (final post in posts.values) {
        if (profile?.role != 'student') continue;
        if (!complete && post.id != confirmedPostId) continue;
        if (knownInvalid(post.id)) continue;
        final room = rooms[post.classId];
        if (room == null || members[room.id]?.status != 'active') continue;
        if (!complete && submissions[post.id]?.status != 'draft') continue;
        final due = post.dueAt!.toUtc();
        for (final fire in deadlineTimes(due, now)) {
          final matching = previous.where(
            (r) => r.postId == post.id && r.fireAt.toUtc() == fire,
          );
          final id = matching.isEmpty ? ++next : matching.first.systemAlarmId;
          if (id > 2147483647) throw StateError('Reminder IDs exhausted');
          desired.add({
            'id': id,
            'postId': post.id,
            'fireAt': fire.millisecondsSinceEpoch,
            'dueAt': due.millisecondsSinceEpoch,
            'title': post.title,
            'className': '${room.section} · ${room.course}',
          });
        }
      }
      _check();
      await db.transaction(() async {
        _check();
        await db.delete(db.deadlineReminders).go();
        for (final row in desired) {
          await db
              .into(db.deadlineReminders)
              .insert(
                DeadlineRemindersCompanion.insert(
                  postId: row['postId'] as String,
                  fireAt: DateTime.fromMillisecondsSinceEpoch(
                    row['fireAt'] as int,
                    isUtc: true,
                  ),
                  systemAlarmId: row['id'] as int,
                ),
              );
        }
        await _save('deadline_next_id', '$next');
        await _save('deadline_desired', jsonEncode(desired));
        _check();
      });
      final lease = await _setting('deadline_lease');
      _check();
      if (lease.isNotEmpty) await bridge.reconcile(userId, lease);
      _check();
      await _save('deadline_error', '');
    } catch (_) {
      if (isCurrent())
        await _save(
          'deadline_error',
          'Could not update deadline reminders. Retry.',
        );
      rethrow;
    }
  }
}
