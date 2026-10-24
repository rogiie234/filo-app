import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/exam_remote.dart';

class ExamScreenSecurity {
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
    } on PlatformException {
      throw const ExamFailure("We couldn't complete that request. Try again.");
    } on MissingPluginException {
      throw const ExamFailure("We couldn't complete that request. Try again.");
    }
  }
}
