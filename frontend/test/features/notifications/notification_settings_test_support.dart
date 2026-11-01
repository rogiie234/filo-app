import 'dart:async';

import 'package:filo/features/notifications/data/notification_settings_repository.dart';

class FakeSettingsRepository implements NotificationSettingsRepository {
  bool current = true;
  Future<void>? waiting;
  final fail = <String>{};
  final calls = <({String type, String? classId, bool enabled})>[];
  final rows = <Map<String, dynamic>>[];
  final changes = StreamController<NotificationPreferences?>.broadcast();
  bool loaded = true;
  @override
  bool Function() get isCurrent =>
      () => current;
  @override
  Future<NotificationPreferences?> read() async =>
      loaded ? NotificationPreferences(rows) : null;
  @override
  Stream<NotificationPreferences?> watch() async* {
    yield await read();
    yield* changes.stream;
  }

  @override
  Future<void> refresh() async {
    loaded = true;
    changes.add(await read());
  }

  @override
  Future<void> set(String type, String? classId, bool enabled) async {
    calls.add((type: type, classId: classId, enabled: enabled));
    await waiting;
    if (fail.contains(type)) throw StateError('fixture');
    rows.removeWhere((r) => r['type'] == type && r['class_id'] == classId);
    rows.add({'type': type, 'class_id': classId, 'enabled': enabled});
    changes.add(await read());
  }

  @override
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
        failed.add(type);
      }
    }
    return failed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
