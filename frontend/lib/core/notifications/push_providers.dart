import 'dart:async';

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

bool get _firebaseReady =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android &&
    Firebase.apps.isNotEmpty;

void _pushStatus(String message) {
  if (kDebugMode) debugPrint('[Filo push] $message');
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final service = PushRegistration(
    account: () {
      final session = client.auth.currentSession;
      if (session == null) return null;
      try {
        return '${session.user.id}:${sessionIdFromToken(session.accessToken)}';
      } catch (_) {
        return null;
      }
    },
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
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings()
          .timeout(const Duration(seconds: 10));
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
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
      if (_firebaseReady) {
        await FirebaseMessaging.instance
            .setAutoInitEnabled(false)
            .timeout(const Duration(seconds: 5));
        await FirebaseMessaging.instance.deleteToken().timeout(
          const Duration(seconds: 5),
        );
      }
    },
    signOut: () => client.auth.signOut(),
    onStatus: _pushStatus,
  );
  ref.onDispose(service.dispose);
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
    onResume: () => unawaited(service.sync()),
  );
  unawaited(service.sync());
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(refresh?.cancel());
  });
});
