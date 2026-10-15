import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final notificationPermissionProvider = Provider(
  (ref) => NotificationPermission(),
);

class NotificationPermission {
  static const _channel = MethodChannel('com.filo.filo/notifications');
  static const _storage = FlutterSecureStorage();

  Future<bool> handled(String userId) async =>
      await _storage.read(key: 'notifications_prompt_$userId') == 'handled';

  Future<void> request() async {
    await _channel.invokeMethod<bool>('request');
  }

  Future<void> markHandled(String userId) =>
      _storage.write(key: 'notifications_prompt_$userId', value: 'handled');
}
