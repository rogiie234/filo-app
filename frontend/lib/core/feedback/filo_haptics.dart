import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class FiloHaptics {
  static void confirmed(BuildContext context) =>
      _send(context, HapticFeedback.lightImpact);
  static void selection(BuildContext context) =>
      _send(context, HapticFeedback.selectionClick);

  static void _send(BuildContext context, Future<void> Function() feedback) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!context.mounted ||
        ModalRoute.of(context)?.isCurrent == false ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed))
      return;
    unawaited(_tryFeedback(feedback));
  }

  static Future<void> _tryFeedback(Future<void> Function() feedback) async {
    try {
      await feedback();
    } on MissingPluginException {
      // Feedback is optional on platforms without a haptic implementation.
    } on PlatformException {
      // A device feedback failure must not change an operation's outcome.
    }
  }
}
