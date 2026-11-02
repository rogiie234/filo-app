import 'dart:async';

import 'package:filo/core/sync/background_sync.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

class FixtureWorkmanager extends WorkmanagerPlatform {
  final events = <String>[];
  Completer<void>? cancelGate;
  @override
  Future<void> cancelByUniqueName(String name) async {
    events.add('cancel');
    await cancelGate?.future;
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    events.add('schedule:${inputData!['user_id']}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkmanagerPlatform previous;
  late FixtureWorkmanager work;
  setUp(() {
    previous = WorkmanagerPlatform.instance;
    work = FixtureWorkmanager();
    WorkmanagerPlatform.instance = work;
    FlutterSecureStorage.setMockInitialValues({'filo.sync.active': 'a'});
  });
  tearDown(() {
    WorkmanagerPlatform.instance = previous;
  });

  test('old stop completes before next account schedule; retained marker belongs to next account', () async {
    final gate = work.cancelGate = Completer<void>();
    final stop = stopBackgroundSync(isCurrent: () => true);
    await Future<void>.delayed(Duration.zero);
    final next = scheduleBackgroundSync('b');
    await Future<void>.delayed(Duration.zero);
    expect(work.events, ['cancel']);
    gate.complete();
    await Future.wait([stop, next]);
    expect(work.events, ['cancel', 'schedule:b']);
    expect(
      await const FlutterSecureStorage().read(key: 'filo.sync.active'),
      'b',
    );
  });

  test('obsolete stop never cancels replacement work', () async {
    await stopBackgroundSync(isCurrent: () => false);
    expect(work.events, isEmpty);
    expect(
      await const FlutterSecureStorage().read(key: 'filo.sync.active'),
      'a',
    );
    var checks = 0;
    await stopBackgroundSync(isCurrent: () => ++checks == 1);
    expect(work.events, isEmpty);
    await scheduleBackgroundSync('b');
    expect(work.events, ['schedule:b']);
  });
  test('deletion removes matching background marker but preserves replacement account', () async {
    await stopBackgroundSyncForAccount('b');
    expect(work.events, isEmpty);
    await stopBackgroundSyncForAccount('a');
    expect(work.events, ['cancel']);
    expect(
      await const FlutterSecureStorage().read(key: 'filo.sync.active'),
      isNull,
    );
    await scheduleBackgroundSync('b');
    await stopBackgroundSyncForAccount('a');
    expect(
      await const FlutterSecureStorage().read(key: 'filo.sync.active'),
      'b',
    );
    expect(work.events, ['cancel', 'schedule:b']);
  });
}
