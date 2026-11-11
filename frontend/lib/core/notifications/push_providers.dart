import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, SignOutScope, Session;

import 'deadline_reminders.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_provider.dart';
import '../supabase/session_gate.dart';
import '../supabase/supabase_provider.dart';
import 'push_registration.dart';
import 'push_events.dart';
import '../../features/onboarding/application/notification_permission.dart';

bool get _firebaseReady =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android &&
    Firebase.apps.isNotEmpty;

void _pushStatus(String message) {
  if (kDebugMode) debugPrint('[Filo push] $message');
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final client = ref.watch(supabaseClientProvider);
  String? identityFor(Session? session) {
    if (session == null) return null;
    try {
      return '${session.user.id}:${sessionIdFromToken(session.accessToken)}';
    } catch (_) {
      return null;
    }
  }

  String? identity() => identityFor(client.auth.currentSession);
  var generation = Object();
  var observed = identity();
  bool Function() currentSession() {
    final owner = identity();
    final captured = generation;
    return () =>
        ref.mounted &&
        owner != null &&
        identity() == owner &&
        identical(generation, captured);
  }

  final service = PushRegistration(
    account: identity,
    canRegister: () async {
      if (!_firebaseReady) {
        _pushStatus('Firebase unavailable');
        return false;
      }
      if (ref.read(connectivityProvider).asData?.value != true) {
        _pushStatus('Waiting for connectivity');
        return false;
      }
      final user = ref.read(verifiedUserIdProvider).asData?.value;
      if (user == null || client.auth.currentUser?.id != user) {
        _pushStatus('Waiting for verified sign-in');
        return false;
      }
      if (!await ref.read(notificationPermissionProvider).enabled()) {
        _pushStatus('Notification permission is not allowed');
        return false;
      }
      await FirebaseMessaging.instance
          .setAutoInitEnabled(true)
          .timeout(const Duration(seconds: 10));
      return true;
    },
    getToken: () async {
      if (!_firebaseReady) return null;
      try {
        if (kDebugMode) {
          return await const MethodChannel('com.filo.filo/notifications')
              .invokeMethod<String>('debugToken')
              .timeout(const Duration(seconds: 10));
        }
        return await FirebaseMessaging.instance.getToken().timeout(
          const Duration(seconds: 10),
        );
      } on PlatformException catch (error) {
        if (error.code == 'FCM_NATIVE_FAILURE') {
          _pushStatus('Native FCM failure: ${error.message}');
        }
        rethrow;
      } on FirebaseException catch (error) {
        // SDK code only; messages/details may contain private installation data.
        _pushStatus('FCM SDK error code: ${error.code}');
        rethrow;
      }
    },
    deviceHash: () => ref.read(deviceHashProvider.future),
    register: (token, hash) async {
      await client
          .rpc(
            'register_device_token',
            params: {
              'p_fcm_token': token,
              'p_device_hash': hash,
              'p_platform': 'android',
            },
          )
          .timeout(const Duration(seconds: 10));
    },
    unregister: (token) async {
      await client
          .rpc('unregister_device_token', params: {'p_fcm_token': token})
          .timeout(const Duration(seconds: 5));
    },
    deleteToken: () async {
      final current = currentSession();
      if (_firebaseReady) {
        try {
          await FirebaseMessaging.instance
              .setAutoInitEnabled(false)
              .timeout(const Duration(seconds: 5));
        } finally {
          if (current() || identity() == null) {
            await FirebaseMessaging.instance.deleteToken().timeout(
              const Duration(seconds: 5),
            );
          }
        }
      }
    },
    signOutDeleted: () async {
      final current = currentSession();
      if (current()) await client.auth.signOut(scope: SignOutScope.local);
    },
    signOut: () async {
      final current = currentSession();
      final accountId = client.auth.currentUser?.id;
      try {
        if (accountId != null) {
          await const DeadlineBridge().clearAccount(accountId);
        }
      } catch (_) {
        _pushStatus('Sign-out cleanup pending: deadline reminders');
      }
      if (current()) await client.auth.signOut(scope: SignOutScope.local);
    },
    onStatus: _pushStatus,
  );
  final authChanges = client.auth.onAuthStateChange.listen((event) {
    final next = identityFor(event.session);
    if (next != observed || event.event == AuthChangeEvent.signedOut) {
      observed = next;
      generation = Object();
      service.accountChanged();
    }
  });
  ref.onDispose(() {
    service.dispose();
    unawaited(authChanges.cancel());
  });
  return service;
});

final pushLifecycleProvider = Provider<void>((ref) {
  final service = ref.watch(pushRegistrationProvider);
  ref.listen(verifiedUserIdProvider, (_, _) => unawaited(service.sync()));
  ref.listen(connectivityProvider, (_, next) {
    if (next.asData?.value == true) unawaited(service.sync());
  });
  ref.listen(loginSessionProvider, (_, _) => unawaited(service.sync()));
  StreamSubscription<String>? refresh;
  if (_firebaseReady) {
    refresh = FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => unawaited(service.sync()),
      onError: (Object _) {},
    );
  }
  final lifecycle = AppLifecycleListener(
    onResume: () {
      ref.invalidate(notificationAccessProvider);
      unawaited(service.sync());
    },
  );
  unawaited(service.sync());
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(refresh?.cancel());
  });
});

final pushMessagesLifecycleProvider = Provider<void>((ref) {
  final events = ref.watch(pushEventsProvider);
  ref.listen(loginSessionProvider, (previous, next) {
    final before = previous?.asData?.value?.user.id;
    if (before != null &&
        next.asData != null &&
        before != next.asData?.value?.user.id) {
      events.clear();
    }
  });
  if (!_firebaseReady) return;
  final client = ref.read(supabaseClientProvider);
  void receive(RemoteMessage message, bool open) {
    if (!ref.mounted) return;
    events.receive(
      message.data,
      open: open,
      accountId: client.auth.currentUser?.id,
    );
  }

  final foreground = FirebaseMessaging.onMessage.listen(
    (m) => receive(m, false),
    onError: (Object _) {},
  );
  final opened = FirebaseMessaging.onMessageOpenedApp.listen(
    (m) => receive(m, true),
    onError: (Object _) {},
  );
  unawaited(
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null) receive(message, true);
        })
        .catchError((Object _) {}),
  );
  ref.onDispose(() {
    unawaited(foreground.cancel());
    unawaited(opened.cancel());
  });
});
