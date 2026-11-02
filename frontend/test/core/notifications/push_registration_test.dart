import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/notifications/push_registration.dart';

class Fixture {
  String? account = 'account-a:session-a';
  String token = 'synthetic-token-one';
  bool permitted = true, failRegister = false, failUnregister = false;
  bool failDelete = false, failSignOut = false, failAfterLocalSignOut = false;
  Future<void>? waitForToken, waitForRegister, waitForUnregister, waitForDelete;
  final events = <String>[];
  final statuses = <String>[];
  late final PushRegistration service = PushRegistration(
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
      await waitForUnregister;
      if (failUnregister) throw StateError('offline');
    },
    deleteToken: () async {
      events.add('delete-token');
      await waitForDelete;
      if (failDelete) throw StateError('offline');
    },
    signOut: () async {
      events.add('sign-out');
      if (failSignOut) throw StateError('offline');
      account = null;
      service.accountChanged();
      if (failAfterLocalSignOut) throw StateError('remote revocation failed');
    },
  );
}

void main() {
  for (final stage in ['token', 'registration', 'unregister', 'delete']) {
    test(
      'session replacement during $stage stops old cleanup including A-B-A',
      () async {
        final gate = Completer<void>();
        final f = Fixture();
        if (stage == 'token') f.waitForToken = gate.future;
        if (stage == 'registration') f.waitForRegister = gate.future;
        if (stage == 'unregister') f.waitForUnregister = gate.future;
        if (stage == 'delete') f.waitForDelete = gate.future;
        final registration = stage == 'registration'
            ? f.service.sync()
            : Future<void>.value();
        await Future<void>.delayed(Duration.zero);
        final leaving = f.service.leave();
        expect(identical(leaving, f.service.leave()), isTrue);
        await Future<void>.delayed(Duration.zero);
        f.account = 'account-b:session-b';
        f.service.accountChanged();
        f.account = 'account-a:session-a';
        f.service.accountChanged();
        gate.complete();
        await Future.wait([registration, leaving]);
        await f.service.sync();
        expect(f.events, isNot(contains('sign-out')));
        if (stage != 'delete')
          expect(f.events, isNot(contains('delete-token')));
        if (stage == 'token' || stage == 'registration') {
          expect(f.events.where((e) => e.startsWith('unregister:')), isEmpty);
        }
        f.service.dispose();
      },
    );
  }

  test('remote error after local session removal does not report a retained session', () async {
    final f = Fixture()..failAfterLocalSignOut = true;
    await f.service.leave();
    expect(f.account, isNull);
    expect(f.events.last, 'sign-out');
    f.service.dispose();
  });

  test('A to B to A registers each new session on the same phone', () async {
    final f = Fixture();
    await f.service.sync();
    await f.service.leave();
    f.account = 'account-b:session-b';
    await f.service.sync();
    await f.service.leave();
    f.account = 'account-a:session-a2';
    await f.service.sync();
    expect(f.events.where((e) => e.startsWith('register:')), [
      'register:account-a:session-a:synthetic-token-one',
      'register:account-b:session-b:synthetic-token-one',
      'register:account-a:session-a2:synthetic-token-one',
    ]);
    f.service.dispose();
  });

  test(
    'late registration response cannot suppress latest account or token',
    () async {
      final gate = Completer<void>();
      final f = Fixture()..waitForRegister = gate.future;
      final first = f.service.sync();
      await Future<void>.delayed(Duration.zero);
      f.account = 'account-b:session-b';
      f.token = 'synthetic-token-two';
      final next = f.service.sync();
      gate.complete();
      await Future.wait([first, next]);
      expect(f.events, [
        'register:account-a:session-a:synthetic-token-one',
        'register:account-b:session-b:synthetic-token-two',
      ]);
      await f.service.sync();
      expect(f.events.length, 2);
      f.service.dispose();
    },
  );

  test(
    'all cleanup failures still permit sign-out and report pending',
    () async {
      final f = Fixture()
        ..failUnregister = true
        ..failDelete = true;
      await f.service.sync();
      await f.service.leave();
      expect(f.account, isNull);
      expect(f.events.last, 'sign-out');
      expect(
        f.statuses,
        contains('Sign-out cleanup pending: unregister failed'),
      );
      expect(
        f.statuses,
        contains('Sign-out cleanup pending: FCM invalidation failed'),
      );
      f.service.dispose();
    },
  );

  test(
    'failed auth sign-out permits current session registration retry',
    () async {
      final f = Fixture()..failSignOut = true;
      await f.service.sync();
      await expectLater(f.service.leave(), throwsStateError);
      await f.service.sync();
      expect(f.events.last, 'register:account-a:session-a:synthetic-token-one');
      f.service.dispose();
    },
  );

  test(
    'rapid refresh signals register the latest token after pending work',
    () async {
      final gate = Completer<void>();
      final f = Fixture()..waitForToken = gate.future;
      final first = f.service.sync();
      await Future<void>.delayed(Duration.zero);
      f.token = 'synthetic-token-two';
      final second = f.service.sync();
      f.token = 'synthetic-token-three';
      final third = f.service.sync();
      gate.complete();
      await Future.wait([first, second, third]);
      expect(f.events, ['register:account-a:session-a:synthetic-token-three']);
      f.service.dispose();
    },
  );

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
