import '../../../core/orientation_policy.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/exam_remote.dart';

class ExamWindowState {
  const ExamWindowState({
    this.multiWindow = false,
    this.overlaySupported = false,
    this.obscured = false,
  });
  final bool multiWindow, overlaySupported, obscured;
  bool get blocked => multiWindow || obscured;
}

class ExamScreenSecurity {
  static bool multiWindow = false;
  static Stream<ExamWindowState> windowStates() async* {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      multiWindow = false;
      yield const ExamWindowState();
      return;
    }
    try {
      await for (final raw in const EventChannel(
        'com.filo.filo/exam_window',
      ).receiveBroadcastStream()) {
        final state = Map<String, dynamic>.from(raw as Map);
        multiWindow = state['multi_window'] == true;
        yield ExamWindowState(
          multiWindow: multiWindow,
          obscured: state['obscured'] == true,
          overlaySupported: state['overlay_supported'] == true,
        );
      }
    } on PlatformException {
      multiWindow = false;
      yield const ExamWindowState();
    } on MissingPluginException {
      multiWindow = false;
      yield const ExamWindowState();
    }
  }

  static const channel = MethodChannel('com.filo.filo/exam');

  static Future<void> protect(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (enabled) {
        throw const ExamFailure(
          "We couldn't complete that request. Try again.",
        );
      }
      return;
    }
    try {
      await channel.invokeMethod<void>('protect', enabled);
      FiloOrientationPolicy.examProtected = enabled;
      await FiloOrientationPolicy.refresh();
    } on PlatformException {
      throw const ExamFailure("We couldn't complete that request. Try again.");
    } on MissingPluginException {
      throw const ExamFailure("We couldn't complete that request. Try again.");
    }
  }
}
