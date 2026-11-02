import 'dart:async';
import 'dart:io';

import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/core/notifications/push_registration.dart';
import 'package:filo/core/notifications/push_events.dart';
import 'package:filo/core/picked_image_file.dart';
import 'package:filo/features/files/data/account_temporary_file.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deletion FCM failure still signs out and a local-only retry succeeds',
    () async {
      String? account = 'a:s';
      var fail = true, deletes = 0, exits = 0;
      late final PushRegistration service;
      service = PushRegistration(
        account: () => account,
        canRegister: () async => false,
        getToken: () async => null,
        deviceHash: () async => 'fixture',
        register: (_, _) async {},
        unregister: (_) async {},
        deleteToken: () async {
          deletes++;
          if (fail) throw StateError('fixture FCM');
        },
        signOut: () async {
          throw StateError('ordinary path must not run');
        },
        signOutDeleted: () async {
          exits++;
          account = null;
          service.accountChanged();
        },
      );
      addTearDown(service.dispose);
      await expectLater(service.leaveForDeletion('a'), throwsStateError);
      expect(account, isNull);
      expect(exits, 1);
      fail = false;
      await service.leaveForDeletion('a');
      expect(deletes, 2);
      expect(exits, 1);
    },
  );
  test(
    'replacement account never loses its token or session to old cleanup',
    () async {
      String? account = 'a:s';
      final unregister = Completer<void>();
      var deletes = 0, exits = 0;
      final service = PushRegistration(
        account: () => account,
        canRegister: () async => true,
        getToken: () async => 'fixture-token',
        deviceHash: () async => 'fixture-hash',
        register: (_, _) async {},
        unregister: (_) => unregister.future,
        deleteToken: () async {
          deletes++;
        },
        signOut: () async {
          exits++;
        },
      );
      addTearDown(service.dispose);
      await service.sync();
      final cleanup = service.leaveForDeletion('a');
      await Future<void>.delayed(Duration.zero);
      account = 'b:s';
      service.accountChanged();
      unregister.complete();
      await cleanup;
      expect(deletes, 0);
      expect(exits, 0);
      await service.leaveForDeletion('a');
      expect(deletes, 0);
      expect(exits, 0);
    },
  );
  test('targeted native bridge propagates cancellation failure', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeadlineBridge.channel, (call) async {
          calls.add(call);
          throw PlatformException(code: 'FIXTURE');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeadlineBridge.channel, null),
    );
    await expectLater(
      const DeadlineBridge().clearAccount('a'),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.single.method, 'clearAccount');
    expect(calls.single.arguments, {'accountId': 'a'});
  });
  test(
    'owned temporary export lease fences cleanup until sharing ends',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'filo-export-cleanup-',
      );
      addTearDown(() => root.delete(recursive: true));
      final temporary = await AccountTemporaryFile.create(
        'a',
        'grades.csv',
        isCurrent: () => true,
        directoryProvider: () async => root,
      );
      await temporary.file.writeAsString('fixture');
      final storage = FileStorage(Directory(p.join(root.path, 'files', 'a')));
      var idle = false;
      final waiting = storage.waitForIdle().then((_) => idle = true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(idle, isFalse);
      await temporary.close();
      await waiting;
      expect(await temporary.file.exists(), isFalse);
      await expectLater(
        AccountTemporaryFile.create(
          'a',
          '../bad.csv',
          isCurrent: () => true,
          directoryProvider: () async => root,
        ),
        throwsA(isA<FileProblem>()),
      );
    },
  );
  test(
    'picker removes only private intermediate, including read failure',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'filo-picker-cleanup-',
      );
      addTearDown(() => root.delete(recursive: true));
      final cache = await Directory(p.join(root.path, 'cache')).create();
      final picked = await File(p.join(cache.path, 'picked.png'))
          .writeAsString('fixture');
      await expectLater(
        usePickedImage(
          XFile(picked.path),
          () async => throw StateError('decode'),
          directoryProvider: () async => cache,
        ),
        throwsStateError,
      );
      expect(await picked.exists(), isFalse);
      final original = await File(p.join(root.path, 'gallery.png'))
          .writeAsString('preserve');
      await usePickedImage(
        XFile(original.path),
        () => original.readAsBytes(),
        directoryProvider: () async => cache,
      );
      expect(await original.readAsString(), 'preserve');
    },
  );
  test(
    'pending taps of deleted account clear without touching replacement taps',
    () async {
      final events = PushEvents();
      addTearDown(events.dispose);
      final opening = events.openInbox(
        '00000000-0000-0000-0000-000000000001',
        'a',
      );
      events.receive(
        {'notification_id': '00000000-0000-0000-0000-000000000002'},
        open: true,
        accountId: 'b',
      );
      events.clearAccount('a');
      await opening;
      expect(events.take('b', allowOpen: true)!.accountId, 'b');
      expect(events.take('b', allowOpen: true), isNull);
    },
  );
}
