import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_provider.dart';
import '../connectivity/connectivity_provider.dart';

final deviceHashProvider = FutureProvider<String>((ref) async {
  const storage = FlutterSecureStorage();
  var secret = await storage.read(key: 'filo_device_secret');
  if (secret == null) {
    final random = Random.secure();
    secret = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
    await storage.write(key: 'filo_device_secret', value: secret);
  }
  return sha256.convert(utf8.encode(secret)).toString();
});

/// Emit every auth change, including refreshes for the same account.
final loginSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentSession;
  await for (final event in client.auth.onAuthStateChange) {
    yield event.session;
  }
});

String sessionIdFromToken(String token) {
  final claims = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
  ) as Map<String, dynamic>;
  final id = claims['session_id'];
  if (id is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)) {
    throw const FormatException('Login token has no valid session ID');
  }
  return id;
}

bool offlineSessionMatches(String saved, String sessionId, String deviceHash) {
  try {
    final record = jsonDecode(saved) as Map<String, dynamic>;
    return record['session_id'] == sessionId &&
        record['device_hash'] == deviceHash;
  } catch (_) {
    return false;
  }
}

/// Offline access is limited to an already verified session on this device.
/// This unlocks the local account cache only; backend RLS remains authoritative.
final verifiedUserIdProvider = FutureProvider<String?>((ref) async {
  final session = await ref.watch(loginSessionProvider.future);
  if (session == null) return null;
  final sessionId = sessionIdFromToken(session.accessToken);
  final hash = await ref.watch(deviceHashProvider.future);
  final online = await ref.watch(connectivityProvider.future);
  final client = ref.watch(supabaseClientProvider);
  const storage = FlutterSecureStorage();
  final key = 'filo.offline_verified.${session.user.id}';
  Future<String?> offline() async {
    final saved = await storage.read(key: key);
    if (!ref.mounted ||
        client.auth.currentSession?.accessToken != session.accessToken ||
        saved == null)
      return null;
    return offlineSessionMatches(saved, sessionId, hash)
        ? session.user.id
        : null;
  }

  if (!online) return await offline();
  try {
    final device = await client
        .rpc('check_device_session', params: {'p_device_hash': hash})
        .timeout(const Duration(seconds: 20));
    if (!ref.mounted ||
        client.auth.currentSession?.accessToken != session.accessToken)
      return null;
    if (device is! Map ||
        device['needs_otp'] != false ||
        device['verified'] != true) {
      await storage.delete(key: key);
      return null;
    }
    final verified = await client
        .rpc('is_session_verified')
        .timeout(const Duration(seconds: 20));
    if (!ref.mounted ||
        client.auth.currentSession?.accessToken != session.accessToken)
      return null;
    if (verified != true) {
      await storage.delete(key: key);
      return null;
    }
    await storage.write(
      key: key,
      value: jsonEncode({'session_id': sessionId, 'device_hash': hash}),
    );
    return ref.mounted ? session.user.id : null;
  } on TimeoutException {
    return await offline();
  } on SocketException {
    return await offline();
  }
});
