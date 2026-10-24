import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_providers.dart';
import '../../features/drive_backup/data/drive_backup_service.dart';
import '../../features/files/application/files_providers.dart';
import '../connectivity/connectivity_provider.dart';
import '../supabase/session_gate.dart';
import '../supabase/supabase_provider.dart';
import 'background_sync.dart';
import 'sync_coordinator.dart';

final syncCoordinatorProvider = FutureProvider.autoDispose<SyncCoordinator?>((
  ref,
) async {
  final db = await ref.watch(accountDatabaseProvider.future);
  final id = await ref.watch(verifiedUserIdProvider.future);
  if (db == null || id == null || !ref.mounted) {
    return null;
  }
  final files = await ref.watch(filesRepositoryProvider.future);
  DriveBackupService? backup;
  try {
    backup = await ref.watch(driveBackupProvider.future);
  } catch (_) {
    /* Other sync must continue if Drive is unavailable. */
  }
  if (!ref.mounted) {
    return null;
  }
  final client = ref.watch(supabaseClientProvider);
  final coordinator = SyncCoordinator(
    db,
    client,
    id,
    () => ref.mounted && client.auth.currentUser?.id == id,
    canSendLeaveEvents: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    files: files,
    backup: backup,
  );
  ref.onDispose(coordinator.dispose);
  await coordinator.loadStatus();
  return coordinator;
});
final syncLifecycleProvider = Provider.autoDispose<void>((ref) {
  final future = ref.watch(syncCoordinatorProvider.future);
  var disposed = false, foreground = true;
  Future<void> flush() async {
    if (disposed ||
        !foreground ||
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
    try {
      final coordinator = await future;
      if (!disposed) {
        await coordinator?.run();
      }
    } catch (_) {
      /* Status retains a retry path. */
    }
  }

  ref.listen(localFilesProvider, (_, _) {
    unawaited(() async {
      try {
        final coordinator = await future;
        if (!disposed) {
          await coordinator?.backup?.queueLibrary();
        }
        await flush();
      } catch (_) {
        /* Durable queue is retried on reopen/reconnect. */
      }
    }());
  });
  ref.listen(connectivityProvider, (_, next) {
    if (next.asData?.value == true) unawaited(flush());
  });
  final lifecycle = AppLifecycleListener(
    onResume: () {
      foreground = true;
      unawaited(flush());
    },
    onPause: () => foreground = false,
    onHide: () => foreground = false,
  );
  final timer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => unawaited(flush()),
  );
  unawaited(flush());
  unawaited(
    future
        .then((coordinator) async {
          if (!disposed && coordinator != null) {
            await scheduleBackgroundSync(coordinator.userId);
          }
        })
        .catchError((Object _) {}),
  );
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    lifecycle.dispose();
  });
});
