import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account_deletion_journal.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/notifications/push_providers.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/sync/background_sync.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database_providers.dart';
import '../../drive_backup/data/drive_backup_service.dart';
import '../../files/application/files_providers.dart';
import '../data/account_deletion_repository.dart';
import '../data/account_deletion_cleanup.dart';

final deletionSessionProvider = Provider<({String userId, String sessionId})?>((
  ref,
) {
  final session = ref.watch(loginSessionProvider).asData?.value;
  if (session == null) return null;
  try {
    return (
      userId: session.user.id,
      sessionId: sessionIdFromToken(session.accessToken),
    );
  } catch (_) {
    return null;
  }
});
final accountDeletionRepositoryProvider = Provider(
  (ref) => AccountDeletionRepository(ref.watch(supabaseClientProvider)),
);
final accountDeletionCleanupProvider = Provider(
  (ref) => AccountDeletionCleanup(ref.watch(userDatabaseManagerProvider)),
);
final deletionSessionCleanupProvider = Provider<Future<void> Function(String)>(
  (ref) => (id) async {
    final client = ref.read(supabaseClientProvider);
    if (client.auth.currentUser != null && client.auth.currentUser!.id != id)
      return;
    final push = ref.read(pushRegistrationProvider);
    final current = push.sessionGuard();
    await stopBackgroundSync(isCurrent: current);
    if (client.auth.currentUser?.id == id) {
      if (!current()) return;
      await push.leave();
      if (client.auth.currentUser?.id == id)
        throw StateError('Local session remains');
    }
    if (client.auth.currentUser != null) return;
    ref.invalidate(syncCoordinatorProvider);
    ref.invalidate(driveBackupProvider);
    ref.invalidate(downloadManagerProvider);
    ref.invalidate(filesRepositoryProvider);
  },
);

class DeletionUi {
  const DeletionUi({this.busyUser, this.errorUser, this.message});
  final String? busyUser, errorUser, message;
}

final accountDeletionProvider = NotifierProvider<AccountDeletion, DeletionUi>(
  AccountDeletion.new,
);

class AccountDeletion extends Notifier<DeletionUi> {
  Object _generation = Object();
  String? _draftUser;
  String _draft = '';
  String draft(String id) => _draftUser == id ? _draft : '';
  void remember(String id, String value) {
    _draftUser = id;
    _draft = value;
  }

  void dismiss(String id) {
    if (state.busyUser == null) {
      remember(id, '');
      state = const DeletionUi();
    }
  }

  Future<void> leaveRecovery(String id) async {
    if (state.busyUser != null) return;
    state = DeletionUi(busyUser: id);
    try {
      await ref.read(deletionSessionCleanupProvider)(id);
    } catch (_) {
      state = DeletionUi(
        errorUser: id,
        message: "Couldn't sign out. Try again.",
      );
    } finally {
      if (state.busyUser == id) state = const DeletionUi();
    }
  }

  @override
  DeletionUi build() {
    ref.listen(deletionSessionProvider, (_, _) {
      _generation = Object();
    });
    return const DeletionUi();
  }

  Future<void> request(String id, String confirmation) async {
    if (state.busyUser != null ||
        ref.read(connectivityProvider).asData?.value != true)
      return;
    final session = ref.read(deletionSessionProvider);
    final records = ref.read(deletionJournalProvider).asData?.value;
    if (records == null) return;
    final previous = records[id];
    if (previous?.stage == DeletionStage.cleanup) return;
    if (session == null ||
        session.userId != id ||
        (previous != null && previous.sessionId != session.sessionId)) {
      state = DeletionUi(
        errorUser: id,
        message: 'Your session expired. Please sign in again.',
      );
      return;
    }
    if (previous?.stage != DeletionStage.pending && confirmation != 'DELETE')
      return;
    final generation = _generation;
    bool current() =>
        ref.mounted &&
        identical(_generation, generation) &&
        ref.read(deletionSessionProvider) == session;
    final journal = ref.read(deletionJournalProvider.notifier);
    final cleanup = ref.read(accountDeletionCleanupProvider);
    final record = DeletionRecord(
      id,
      session.sessionId,
      previous?.stage ?? DeletionStage.uncertain,
    );
    remember(id, confirmation);
    var recorded = previous != null;
    state = DeletionUi(busyUser: id);
    try {
      await journal.put(id, record);
      recorded = true;
      await cleanup.block(id, true);
      if (!current()) return;
      final result = await ref
          .read(accountDeletionRepositoryProvider)
          .request();
      if (!current()) return;
      await journal.put(id, record.at(result));
      if (!current()) return;
      if (result == DeletionStage.cleanup) {
        await _remove(id);
      }
    } on DeletionRejected {
      if (current()) {
        try {
          // A prior accepted/uncertain attempt cannot be disproved by a later denial.
          if (previous == null) {
            await journal.put(id, null);
            await cleanup.block(id, false);
            state = DeletionUi(
              errorUser: id,
              message: "Couldn't delete your account. Try again.",
            );
          } else {
            state = DeletionUi(
              errorUser: id,
              message: "We couldn't confirm whether your account was deleted. Connect and check your account status before trying again.",
            );
          }
        } catch (_) {
          state = DeletionUi(
            errorUser: id,
            message: "We couldn't confirm whether your account was deleted. Connect and check your account status before trying again.",
          );
        }
      }
    } catch (_) {
      if (current())
        state = DeletionUi(
          errorUser: id,
          message: recorded
              ? "We couldn't confirm whether your account was deleted. Connect and check your account status before trying again."
              : "Couldn't delete your account. Try again.",
        );
    } finally {
      if (state.busyUser == id) state = const DeletionUi();
    }
  }

  Future<void> removeLocal(String id) async {
    if (state.busyUser != null ||
        ref.read(deletionJournalProvider).asData?.value[id]?.stage !=
            DeletionStage.cleanup)
      return;
    state = DeletionUi(busyUser: id);
    await _remove(id);
    if (state.busyUser == id) state = const DeletionUi();
  }

  Future<void> _remove(String id) async {
    try {
      await ref.read(deletionSessionCleanupProvider)(id);
      await ref.read(accountDeletionCleanupProvider).remove(id);
      await ref.read(deletionJournalProvider.notifier).put(id, null);
    } catch (_) {
      state = DeletionUi(
        errorUser: id,
        message: "Your account was deleted, but Filo couldn't remove all local files from this device. Try removing them again.",
      );
    }
  }
}
