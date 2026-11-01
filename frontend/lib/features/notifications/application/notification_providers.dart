import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../data/inbox_repository.dart';
import '../data/alarm_repository.dart';
import '../data/notification_destination_repository.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/sync/sync_providers.dart';
import '../../classes/application/class_providers.dart';
import '../../posts/application/post_providers.dart';

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

final notificationDestinationRepositoryProvider =
    FutureProvider.autoDispose<NotificationDestinationRepository>((ref) async {
      final db = await ref.watch(accountDatabaseProvider.future);
      final userId = await ref.watch(verifiedUserIdProvider.future);
      final sync = await ref.watch(syncCoordinatorProvider.future);
      final client = ref.watch(supabaseClientProvider);
      final sessionId = client.auth.currentSession == null
          ? null
          : sessionIdFromToken(client.auth.currentSession!.accessToken);
      if (db == null || userId == null || sync == null || !ref.mounted) {
        throw StateError('No verified account database');
      }
      bool current() =>
          ref.mounted &&
          client.auth.currentUser?.id == userId &&
          ref.read(verifiedUserIdProvider).asData?.value == userId &&
          ref.read(accountDatabaseProvider).asData?.value == db &&
          client.auth.currentSession != null &&
          sessionIdFromToken(client.auth.currentSession!.accessToken) ==
              sessionId;
      return NotificationDestinationRepository(
        db: db,
        client: client,
        sync: sync,
        userId: userId,
        online: () => ref.read(connectivityProvider).asData?.value == true,
        isCurrent: current,
        prepare: (destination) async {
          if (!current()) throw StateError('Account changed');
          final classes = await ref.read(classRepositoryProvider.future);
          if (classes == null) throw StateError('No class repository');
          await classes.sync();
          if (!current()) throw StateError('Account changed');
          final room = await (db.select(
            db.cacheClasses,
          )..where((c) => c.id.equals(destination.classId))).getSingleOrNull();
          if (room == null || room.deletedAt != null)
            throw const NotificationUnavailable();
          if (room.ownerId != userId) {
            final member =
                await (db.select(db.cacheClassMembers)..where(
                      (m) =>
                          m.classId.equals(destination.classId) &
                          m.studentId.equals(userId) &
                          m.status.equals('active'),
                    ))
                    .getSingleOrNull();
            if (member == null) throw const NotificationUnavailable();
          }
          if (destination.screen == NotificationScreen.post ||
              destination.screen == NotificationScreen.assignment) {
            final posts = await ref.read(postRepositoryProvider.future);
            if (posts == null) throw StateError('No post repository');
            await posts.sync(destination.classId);
          }
        },
      );
    });
