import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Connectivity extends Fake implements Connectivity {
  final events = StreamController<List<ConnectivityResult>>.broadcast(
    sync: true,
  );
  Future<List<ConnectivityResult>> Function() probe = () =>
      Future.value([ConnectivityResult.none]);
  @override
  Future<List<ConnectivityResult>> checkConnectivity() => probe();
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events.stream;
}

void main() {
  Future<void> settleEvents() => Future<void>.delayed(Duration.zero);

  test(
    'explicit recheck recovers a missed reconnect event on the same stream',
    () async {
      final platform = _Connectivity();
      final monitor = ConnectivityMonitor(
        connectivity: platform,
        observeLifecycle: false,
      );
      final values = <bool>[];
      final subscription = monitor.stream.listen(values.add);
      addTearDown(() async {
        await subscription.cancel();
        await monitor.dispose();
        await platform.events.close();
      });
      await settleEvents();
      expect(values, [false]);
      // Wi-Fi returns but the platform never sends an onConnectivityChanged event.
      platform.probe = () => Future.value([ConnectivityResult.wifi]);
      expect(await monitor.recheck(), true);
      expect(values, [false, true]);
      await monitor.recheck();
      expect(values, [false, true]); // No redundant auth/cache invalidation.
    },
  );

  test(
    'a delayed initial offline check cannot replace a newer online event',
    () async {
      final platform = _Connectivity();
      final pending = Completer<List<ConnectivityResult>>();
      platform.probe = () => pending.future;
      final monitor = ConnectivityMonitor(
        connectivity: platform,
        observeLifecycle: false,
      );
      final values = <bool>[];
      final subscription = monitor.stream.listen(values.add);
      addTearDown(() async {
        await subscription.cancel();
        await monitor.dispose();
        await platform.events.close();
      });
      platform.events.add([ConnectivityResult.wifi]);
      pending.complete([ConnectivityResult.none]);
      await settleEvents();
      expect(values, [true]);
    },
  );

  test(
    'same online value after an error is delivered so AsyncError can recover',
    () async {
      final platform = _Connectivity()
        ..probe = () => Future.value([ConnectivityResult.wifi]);
      final monitor = ConnectivityMonitor(
        connectivity: platform,
        observeLifecycle: false,
      );
      final values = <bool>[];
      final errors = <Object>[];
      final subscription = monitor.stream.listen(
        values.add,
        onError: (Object error, StackTrace stack) => errors.add(error),
      );
      addTearDown(() async {
        await subscription.cancel();
        await monitor.dispose();
        await platform.events.close();
      });
      await settleEvents();
      platform.probe = () => Future.error(StateError('platform check failed'));
      await expectLater(monitor.recheck(), throwsStateError);
      platform.probe = () => Future.value([ConnectivityResult.wifi]);
      expect(await monitor.recheck(), true);
      expect(errors, hasLength(1));
      expect(values, [true, true]);
    },
  );
}
