import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/session_gate.dart';
import 'app_database.dart';
import 'user_database_manager.dart';

/// One manager for the app's root ProviderScope, retained across screens.
final userDatabaseManagerProvider = Provider<UserDatabaseManager>((ref) {
  final manager = UserDatabaseManager();
  ref.onDispose(() => unawaited(manager.close()));
  return manager;
});

/// Screens and repositories await this provider before accessing account data.
/// A null database means that no account is signed in.
final accountDatabaseProvider = FutureProvider<AppDatabase?>((ref) async {
  final manager = ref.watch(userDatabaseManagerProvider);
  // Lock the previous cache while verification is pending or fails.
  final verification = ref.watch(verifiedUserIdProvider.future);
  await manager.close();
  final userId = await verification;
  if (!ref.mounted) return null;
  if (userId == null) {
    await manager.close();
    return null;
  }
  return manager.openForUser(userId);
});
