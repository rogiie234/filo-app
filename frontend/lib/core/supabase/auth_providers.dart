import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_provider.dart';

/// Emits the restored account first, then login/logout/account changes.
/// Token refreshes for the same account do not reopen its database.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  var userId = client.auth.currentUser?.id;
  yield userId;
  await for (final event in client.auth.onAuthStateChange) {
    final nextId = event.session?.user.id;
    if (nextId != userId) {
      userId = nextId;
      yield userId;
    }
  }
});
