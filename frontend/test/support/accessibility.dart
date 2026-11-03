import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void a11yScreenTest(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await callback(tester);
  });
}
