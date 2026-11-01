import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../data/inbox_repository.dart';
import '../data/alarm_repository.dart';

final inboxRepositoryProvider = FutureProvider.autoDispose<InboxRepository>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  final client = ref.watch(supabaseClientProvider);
  final id = client.auth.currentUser?.id;
  if (db == null || id == null || !ref.mounted) {
    throw StateError('No account database');
  }
  return InboxRepository(
    db,
    id,
    () => ref.mounted && client.auth.currentUser?.id == id,
  );
});

final alarmRepositoryProvider = FutureProvider.autoDispose<AlarmRepository>((
  ref,
) async {
  final inbox = await ref.watch(inboxRepositoryProvider.future);
  return AlarmRepository(inbox.db, () => ref.mounted && inbox.isCurrent());
});

final inboxProvider = StreamProvider.autoDispose<List<CacheNotification>>((
  ref,
) async* {
  final repository = await ref.watch(inboxRepositoryProvider.future);
  if (!ref.mounted) return;
  yield* repository.watchInbox();
});

final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((
  ref,
) async* {
  final repository = await ref.watch(inboxRepositoryProvider.future);
  if (!ref.mounted) return;
  yield* repository.watchUnreadCount();
});
