import 'package:filo/features/onboarding/application/notification_permission.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.filo.filo/notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'status is native state and settings/request use the existing channel',
    () async {
      var enabled = false;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'status' ? enabled : null;
      });
      final permission = NotificationPermission();
      expect(await permission.enabled(), isFalse);
      enabled = true;
      expect(await permission.enabled(), isTrue);
      await permission.openSettings();
      await permission.request();
      expect(calls, ['status', 'status', 'openSettings', 'request']);
    },
  );

  test(
    'unknown status and native errors stay errors, not permission denial',
    () async {
      final permission = NotificationPermission();
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await expectLater(permission.enabled(), throwsStateError);
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'STATUS_UNAVAILABLE');
      });
      await expectLater(
        permission.enabled(),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
