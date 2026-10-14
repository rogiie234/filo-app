import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_provider.dart';

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

/// Server verification must succeed before account data can be opened.
final verifiedUserIdProvider = FutureProvider<String?>((ref) async {
  final session = await ref.watch(loginSessionProvider.future);
  if (session == null) return null;
  sessionIdFromToken(session.accessToken);
  final hash = await ref.watch(deviceHashProvider.future);
  final client = ref.watch(supabaseClientProvider);
  final device = await client.rpc(
    'check_device_session',
    params: {'p_device_hash': hash},
  );
  if (device is! Map ||
      device['needs_otp'] != false ||
      device['verified'] != true) {
    return null;
  }
  final verified = await client.rpc('is_session_verified');
  if (!ref.mounted ||
      client.auth.currentSession?.accessToken != session.accessToken) {
    return null;
  }
  return verified == true ? session.user.id : null;
});
