import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../data/local/app_database.dart';

const notificationTypes = <String, String>{
  'announcement': 'Announcements',
  'material': 'Materials',
  'assignment': 'Assignments',
  'quiz_published': 'New quizzes and exams',
  'grade_returned': 'Returned assignment grades',
  'results_released': 'Quiz and exam results',
  'join_request': 'Join requests',
  'join_approved': 'Approved join requests',
  'join_declined': 'Declined join requests',
  'link_report': 'Reported Drive links',
  'second_chance': 'Another quiz or exam attempt',
  'removed_from_class': 'Removed from a class',
};

class NotificationPreferences {
  NotificationPreferences(Iterable<Map<String, dynamic>> rows)
    : values = {
        for (final row in rows)
          key(row['type'] as String, row['class_id'] as String?):
              row['enabled'] as bool,
      };
  final Map<String, bool> values;
  static String key(String type, String? classId) =>
      '${classId ?? 'global'}:$type';
  bool enabled(String type, [String? classId]) =>
      values[key(type, classId)] ?? true;
  bool classEnabled(String id) =>
      notificationTypes.keys.every((type) => enabled(type, id));
  bool classMixed(String id) {
    final on = notificationTypes.keys.where((type) => enabled(type, id)).length;
    return on > 0 && on < notificationTypes.length;
  }
}

class NotificationSettingsRepository {
  NotificationSettingsRepository(
    this.db,
    this.client,
    this.userId,
    this.isCurrent, {
    required this.online,
  });
  final AppDatabase db;
  final SupabaseClient client;
  final String userId;
  final bool Function() isCurrent, online;
  // Separate repositories in UI/background sync share the account database lock.
  static final _work = Expando<Future<void>>();

  void _check() {
    if (!isCurrent()) throw StateError('Account changed');
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = (_work[db] ?? Future<void>.value()).then((_) {
      _check();
      return action();
    });
    _work[db] = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<NotificationPreferences?> read() async {
    _check();
    final marker = await db
        .customSelect(
          "SELECT id FROM sync_payloads WHERE table_name='notification_preferences_loaded' AND id=?",
          variables: [Variable(userId)],
        )
        .get();
    _check();
    if (marker.isEmpty) return null;
    final rows = await db
        .customSelect(
          "SELECT payload FROM sync_payloads WHERE table_name='notification_settings'",
        )
        .get();
    _check();
    return NotificationPreferences(
      rows
          .map(
            (row) => Map<String, dynamic>.from(
              jsonDecode(row.read<String>('payload')) as Map,
            ),
          )
          .where((row) => row['user_id'] == userId),
    );
  }

  Stream<NotificationPreferences?> watch() {
    late StreamController<NotificationPreferences?> controller;
    StreamSubscription<Set<TableUpdate>>? updates;
    Future<void> reading = Future.value();
    void reload() {
      reading = reading.then((_) async {
        try {
          final value = await read();
          if (!controller.isClosed) controller.add(value);
        } catch (error, stack) {
          if (!controller.isClosed) controller.addError(error, stack);
        }
      });
    }

    controller = StreamController<NotificationPreferences?>(
      onListen: () {
        updates = db
            .tableUpdates(const TableUpdateQuery.onTableName('sync_payloads'))
            .listen((_) => reload());
        reload();
      },
      onCancel: () async {
        await updates?.cancel();
      },
    );
    return controller.stream;
  }

  Map<String, dynamic> _row(dynamic value) {
    final row = Map<String, dynamic>.from(value as Map);
    if (row['user_id'] != userId ||
        row['id'] is! String ||
        row['type'] is! String ||
        row['enabled'] is! bool ||
        (row['class_id'] != null && row['class_id'] is! String))
      throw StateError('Invalid preference response');
    DateTime.parse(row['updated_at'] as String);
    return row;
  }

  Future<void> _store(Map<String, dynamic> row) async {
    final old = await db
        .customSelect(
          "SELECT updated_at FROM sync_payloads WHERE table_name='notification_settings' AND id=?",
          variables: [Variable(row['id'] as String)],
        )
        .get();
    if (old.isNotEmpty &&
        DateTime.parse(old.single.read<String>('updated_at'))
            .isAfter(DateTime.parse(row['updated_at'] as String)))
      return;
    await db.customStatement(
      "INSERT OR REPLACE INTO sync_payloads(table_name,id,payload,updated_at) VALUES('notification_settings',?,?,?)",
      [row['id'], jsonEncode(row), row['updated_at']],
    );
  }

  Future<void> refresh() => _serialize(() async {
    if (!online()) throw StateError('Connect to change notification settings');
    final rows = <Map<String, dynamic>>[];
    String? after;
    while (true) {
      _check();
      var query = client
          .from('notification_settings')
          .select()
          .eq('user_id', userId);
      if (after != null) query = query.gt('id', after);
      final page = await query
          .order('id')
          .limit(200)
          .timeout(const Duration(seconds: 20));
      _check();
      rows.addAll(page.map(_row));
      if (page.length < 200) break;
      final next = page.last['id'] as String;
      if (after != null && next.compareTo(after) <= 0)
        throw StateError('Non-progressing preference page');
      after = next;
    }
    await db.transaction(() async {
      _check();
      final ids = rows.map((r) => r['id']).toSet();
      final cached = await db
          .customSelect(
            "SELECT id FROM sync_payloads WHERE table_name='notification_settings'",
          )
          .get();
      for (final row in cached) {
        if (!ids.contains(row.read<String>('id')))
          await db.customStatement(
            "DELETE FROM sync_payloads WHERE table_name='notification_settings' AND id=?",
            [row.read<String>('id')],
          );
      }
      for (final row in rows) {
        await _store(row);
      }
      await db.customStatement(
        "INSERT OR REPLACE INTO sync_payloads(table_name,id,payload,updated_at) VALUES('notification_preferences_loaded',?,'{}',?)",
        [userId, DateTime.now().toUtc().toIso8601String()],
      );
      _check();
    });
    db.notifyUpdates({const TableUpdate('sync_payloads')});
  });

  Future<void> set(
    String type,
    String? classId,
    bool enabled,
  ) => _serialize(() async {
    if (!notificationTypes.containsKey(type))
      throw ArgumentError('Unknown notification type');
    if (!online()) throw StateError('Connect to change notification settings');
    final response = await client
        .rpc(
          'set_notification_setting',
          params: {'p_type': type, 'p_class_id': classId, 'p_enabled': enabled},
        )
        .timeout(const Duration(seconds: 20));
    _check();
    final row = _row(response);
    if (row['type'] != type ||
        row['class_id'] != classId ||
        row['enabled'] != enabled)
      throw StateError('Mismatched preference response');
    await db.transaction(() async {
      _check();
      await _store(row);
      _check();
    });
    db.notifyUpdates({const TableUpdate('sync_payloads')});
  });

  Future<Set<String>> setClass(
    String classId,
    bool enabled, {
    Set<String>? types,
  }) async {
    final failed = <String>{};
    for (final type in types ?? notificationTypes.keys.toSet()) {
      try {
        await set(type, classId, enabled);
      } catch (_) {
        _check();
        failed.add(type);
      }
    }
    return failed;
  }
}
