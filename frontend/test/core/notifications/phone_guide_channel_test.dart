import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class GuideChannelBridge extends DeadlineBridge {
  @override
  bool get supported => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeadlineBridge.channel, null),
  );
  test('capabilities and launch outcomes use guide-only methods', () async {
    final calls = <MethodCall>[];
    var result = 'app_details';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeadlineBridge.channel, (call) async {
          calls.add(call);
          if (call.method == 'guideCapabilities') {
            return {'sdk': 31, 'xiaomi': true};
          }
          return result;
        });
    final bridge = GuideChannelBridge();
    final caps = await bridge.guideCapabilities();
    expect(caps.exactStep, isTrue);
    expect(caps.xiaomi, isTrue);
    expect(await bridge.guideOpenSettings('battery'), 'app_details');
    result = 'failed';
    expect(await bridge.guideOpenSettings('autostart'), 'failed');
    result = 'direct';
    expect(await bridge.guideOpenSettings('alarm'), 'direct');
    expect(calls.map((c) => c.method), [
      'guideCapabilities',
      'guideOpenSettings',
      'guideOpenSettings',
      'guideOpenSettings',
    ]);
    expect(calls[1].arguments, {'section': 'battery'});
  });
  test('unknown capability or launch responses remain errors', () async {
    final bridge = GuideChannelBridge();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeadlineBridge.channel,
          (call) async =>
              call.method == 'guideCapabilities' ? {'sdk': 31} : null,
        );
    await expectLater(bridge.guideCapabilities(), throwsStateError);
    await expectLater(bridge.guideOpenSettings('alarm'), throwsStateError);
  });
}
