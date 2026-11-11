import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../supabase/session_gate.dart';
import '../supabase/supabase_provider.dart';
import '../../features/notifications/application/notification_providers.dart';
import '../../data/local/user_database_manager.dart';
import 'deadline_reminders.dart';
import 'push_events.dart';
import '../../features/notifications/data/alarm_repository.dart';

final deadlineBridgeProvider = Provider<DeadlineBridge>(
  (ref) => const DeadlineBridge(),
);
final deadlineSessionProvider = FutureProvider.autoDispose<DeadlineReminders?>((
  ref,
) async {
  final bridge = ref.watch(deadlineBridgeProvider);
  if (!bridge.supported) return null;
  final id = await ref.watch(verifiedUserIdProvider.future);
  if (id == null || !ref.mounted) return null;
  final account = await ref.watch(inboxRepositoryProvider.future);
  final session = ref.watch(supabaseClientProvider).auth.currentSession;
  if (session == null) return null;
  final lease = sessionIdFromToken(session.accessToken);
  final root = await getApplicationSupportDirectory();
  if (!ref.mounted || !account.isCurrent()) return null;
  await account.db.customStatement(
    "INSERT OR REPLACE INTO file_settings(key,value) VALUES('deadline_lease',?)",
    [lease],
  );
  if (!ref.mounted || !account.isCurrent()) return null;
  await bridge.activate(
    id,
    lease,
    '${root.path}/databases/${UserDatabaseManager.filenameForUser(id)}',
  );
  final service = DeadlineReminders(
    account.db,
    id,
    () => ref.mounted && account.isCurrent(),
    bridge: bridge,
  );
  try {
    await service.reconcile();
  } catch (_) {
    /* Durable deadline error remains visible. */
  }
  try {
    await AlarmRepository(
      account.db,
      service.isCurrent,
      userId: id,
      bridge: bridge,
    ).reconcileStudy();
  } catch (_) {
    /* Study failures remain separate from deadline status. */
  }
  return ref.mounted ? service : null;
});

final deadlineStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final result = await ref.watch(deadlineBridgeProvider).status();
    final service = await ref.watch(deadlineSessionProvider.future);
    if (service != null && service.isCurrent()) {
      final error = await service.db
          .customSelect(
            "SELECT value FROM file_settings WHERE key='deadline_error'",
          )
          .get();
      if (error.isNotEmpty && error.single.read<String>('value').isNotEmpty) {
        result['error'] = true;
      }
    }
    return result;
  },
);

final deadlineLifecycleProvider = Provider<void>((ref) {
  final bridge = ref.watch(deadlineBridgeProvider);
  if (!bridge.supported) return;
  StreamSubscription<Set<TableUpdate>>? changes;
  Future<void> reconcile() async {
    try {
      final service = await ref.read(deadlineSessionProvider.future);
      try {
        await service?.reconcile();
      } catch (_) {
        /* Study scheduling is independent. */
      }
      if (service != null) {
        await AlarmRepository(
          service.db,
          service.isCurrent,
          userId: service.userId,
          bridge: bridge,
        ).reconcileStudy();
      }
    } catch (_) {
      /* Persisted status offers Retry; confirmed work is unaffected. */
    }
    if (ref.mounted) ref.invalidate(deadlineStatusProvider);
  }

  ref.listen(deadlineSessionProvider, (_, next) {
    unawaited(changes?.cancel());
    final service = next.asData?.value;
    if (service != null) {
      changes = service.db
          .tableUpdates(
            TableUpdateQuery.allOf([
              TableUpdateQuery.onTable(service.db.cachePosts),
              TableUpdateQuery.onTable(service.db.cacheSubmissions),
              TableUpdateQuery.onTable(service.db.cacheClasses),
              TableUpdateQuery.onTable(service.db.cacheClassMembers),
            ]),
          )
          .listen((_) => unawaited(reconcile()));
    }
  }, fireImmediately: true);
  ref.listen(loginSessionProvider, (previous, next) {
    final before = previous?.asData?.value?.user.id;
    if (before != null &&
        next.asData != null &&
        before != next.asData?.value?.user.id) {
      unawaited(bridge.clear().catchError((Object _) {}));
    }
  });
  DeadlineBridge.channel.setMethodCallHandler((call) async {
    if (call.method == 'tap' && call.arguments is Map && ref.mounted) {
      ref.read(pushEventsProvider).receiveReminder(call.arguments as Map);
    }
  });
  unawaited(
    DeadlineBridge.channel
        .invokeMapMethod<dynamic, dynamic>('takeTap')
        .then((tap) {
          if (tap != null && ref.mounted) {
            ref.read(pushEventsProvider).receiveReminder(tap);
          }
        })
        .catchError((Object _) {}),
  );
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(reconcile()),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(changes?.cancel());
    DeadlineBridge.channel.setMethodCallHandler(null);
  });
});
