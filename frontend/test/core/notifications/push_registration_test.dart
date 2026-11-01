import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/notifications/push_registration.dart';

class Fixture {
  String? account = 'account-a:session-a';
  String token = 'synthetic-token-one';
  bool permitted = true, failRegister = false, failUnregister = false;
  Future<void>? waitForToken, waitForRegister;
  final events = <String>[];
  final statuses = <String>[];
  late final service = PushRegistration(
    onStatus: statuses.add,
    account: () => account,
    canRegister: () async => permitted,
    getToken: () async {
      await waitForToken;
      return token;
    },
    deviceHash: () async => 'synthetic-hash',
    register: (token, hash) async {
      events.add('register:$account:$token');
      await waitForRegister;
      if (failRegister) throw StateError('synthetic-private-error-content');
    },
    unregister: (token) async {
      events.add('unregister:$token');
      if (failUnregister) throw StateError('offline');
    },
    deleteToken: () async {
      events.add('delete-token');
    },
    signOut: () async {
      events.add('sign-out');
      account = null;
    },
  );
}

void main() {
  test('permission and verification eligibility gate registration', () async {
    final f = Fixture()..permitted = false;
    await f.service.sync();
    expect(f.events, isEmpty);
    f.permitted = true;
    await f.service.sync();
    expect(f.events, ['register:account-a:session-a:synthetic-token-one']);
    f.service.dispose();
  });
  test(
    'registration deduplicates and refreshed token registers again',
    () async {
      final f = Fixture();
      await Future.wait([f.service.sync(), f.service.sync()]);
      await f.service.sync();
      expect(f.events.length, 1);
      f.token = 'synthetic-token-two';
      await f.service.sync();
      expect(f.events.last, 'register:account-a:session-a:synthetic-token-two');
      f.service.dispose();
    },
  );
  test('registration failure retries on next lifecycle signal', () async {
    final f = Fixture()..failRegister = true;
    await f.service.sync();
    f.failRegister = false;
    await f.service.sync();
    expect(f.events.length, 2);
    f.service.dispose();
  });
  test('account switch during token loading discards stale work', () async {
    final gate = Completer<void>();
    final f = Fixture()..waitForToken = gate.future;
    final first = f.service.sync();
    await Future<void>.delayed(Duration.zero);
    f.account = 'account-b:session-b';
    final second = f.service.sync();
    gate.complete();
    await Future.wait([first, second]);
    expect(f.events, ['register:account-b:session-b:synthetic-token-one']);
    f.service.dispose();
  });
  test(
    'sign-out waits for registration and cleans before auth sign-out',
    () async {
      final gate = Completer<void>();
      final f = Fixture()..waitForRegister = gate.future;
      final registration = f.service.sync();
      await Future<void>.delayed(Duration.zero);
      final leaving = f.service.leave();
      await f.service.sync();
      gate.complete();
      await Future.wait([registration, leaving]);
      expect(f.events, [
        'register:account-a:session-a:synthetic-token-one',
        'unregister:synthetic-token-one',
        'delete-token',
        'sign-out',
      ]);
      f.account = 'account-b:session-b';
      await f.service.sync();
      expect(f.events.last, 'register:account-b:session-b:synthetic-token-one');
      f.service.dispose();
    },
  );
  test(
    'offline unregister failure still invalidates FCM and signs out',
    () async {
      final f = Fixture()..failUnregister = true;
      await f.service.sync();
      await f.service.leave();
      expect(f.events.sublist(1), [
        'unregister:synthetic-token-one',
        'delete-token',
        'sign-out',
      ]);
      f.service.dispose();
    },
  );
  test(
    'signed-out session clears local FCM and disposal blocks late registration',
    () async {
      final f = Fixture()..account = null;
      await f.service.sync();
      expect(f.events, ['delete-token']);
      f.account = 'account-a:session-a';
      final gate = Completer<void>();
      f.waitForToken = gate.future;
      final work = f.service.sync();
      await Future<void>.delayed(Duration.zero);
      f.service.dispose();
      gate.complete();
      await work;
      expect(f.events, ['delete-token']);
    },
  );
  test(
    'diagnostics identify failure stage without token or exception content',
    () async {
      final f = Fixture()..failRegister = true;
      await f.service.sync();
      expect(f.statuses.last, 'Registration pending: registration RPC failed');
      expect(f.statuses.join(' '), isNot(contains(f.token)));
      expect(
        f.statuses.join(' '),
        isNot(contains('synthetic-private-error-content')),
      );
      f.service.dispose();
    },
  );
}
