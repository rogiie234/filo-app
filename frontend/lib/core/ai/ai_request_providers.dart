import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/session_gate.dart';
import 'ai_request_guard.dart';

final aiRequestGuardProvider = Provider<AiRequestGuard>((ref) {
  final guard = AiRequestGuard();
  ref.onDispose(() => unawaited(guard.close()));
  return guard;
});

final aiRequestBusyProvider = StreamProvider<bool>(
  (ref) => ref.watch(aiRequestGuardProvider).watchBusy(),
);

final aiChatCooldownProvider = StreamProvider<Duration>(
  (ref) => ref.watch(aiRequestGuardProvider).watchChatCooldown(),
);

/// Token refresh keeps the identity; a new login/session does not.
String? aiSessionIdentity(Session? session) {
  if (session == null) return null;
  try {
    return '${session.user.id}:${sessionIdFromToken(session.accessToken)}';
  } catch (_) {
    return null;
  }
}
