import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network availability is a hint, not proof that an auth request will succeed.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  final controller = StreamController<bool>();
  var revision = 0;
  void publish(List<ConnectivityResult> results) {
    controller.add(results.any((result) => result != ConnectivityResult.none));
  }

  Future<void> check() async {
    final current = ++revision;
    try {
      final results = await connectivity.checkConnectivity();
      if (!controller.isClosed && current == revision) publish(results);
    } catch (error, stack) {
      if (!controller.isClosed && current == revision) {
        controller.addError(error, stack);
      }
    }
  }

  final subscription = connectivity.onConnectivityChanged.listen((results) {
    revision++;
    publish(results);
  }, onError: controller.addError);
  final lifecycle = AppLifecycleListener(onResume: check);
  unawaited(check());
  ref.onDispose(() {
    revision++;
    lifecycle.dispose();
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream.distinct();
});
