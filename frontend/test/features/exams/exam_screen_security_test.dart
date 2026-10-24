import 'package:filo/features/exams/application/exam_screen_security.dart';
import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(ExamScreenSecurity.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android enables and restores secure window through the native channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(ExamScreenSecurity.channel, (
        call,
      ) async {
        calls.add(call);
      });
      await ExamScreenSecurity.protect(true);
      await ExamScreenSecurity.protect(false);
      expect(calls.map((c) => c.method), ['protect', 'protect']);
      expect(calls.map((c) => c.arguments), [true, false]);
    },
  );

  test('missing native protection fails closed with friendly copy', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await expectLater(
      ExamScreenSecurity.protect(true),
      throwsA(
        isA<ExamFailure>().having(
          (e) => e.message,
          'message',
          "We couldn't complete that request. Try again.",
        ),
      ),
    );
  });
}
