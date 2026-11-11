import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account_deletion_journal.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/notifications/push_providers.dart';
import '../../../core/notifications/deadline_reminders.dart';
import '../../../core/notifications/push_events.dart';
import 'profile_settings.dart';
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
final instructorDeletionEligibilityProvider = FutureProvider.autoDispose
    .family<InstructorDeletionEligibility, String>((ref, id) async {
      final session = ref.watch(deletionSessionProvider);
      final online = ref.watch(connectivityProvider).asData?.value == true;
      if (session?.userId != id || !online) {
        throw StateError('Eligibility unavailable');
      }
      return ref
          .watch(accountDeletionRepositoryProvider)
          .eligibility(
            id,
            isCurrent: () =>
                ref.mounted && ref.read(deletionSessionProvider) == session,
          );
    });
final accountDeletionCleanupProvider = Provider(
  (ref) => AccountDeletionCleanup(ref.watch(userDatabaseManagerProvider)),
);

class DeletionCleanupFailure implements Exception {
  const DeletionCleanupFailure(this.step);
  final String step;
}

final deletionSessionCleanupProvider = Provider<Future<void> Function(String)>(
  (ref) => (id) async {
    final client = ref.read(supabaseClientProvider);
    DeletionCleanupFailure? failure;
    try {
      await stopBackgroundSyncForAccount(id);
    } catch (_) {
      failure = const DeletionCleanupFailure('Stopping background work');
    }
    try {
      await const DeadlineBridge().clearAccount(id);
    } catch (_) {
      failure ??= const DeletionCleanupFailure('Clearing reminders');
    }
    try {
      ref.read(pushEventsProvider).clearAccount(id);
      await ref.read(confirmedProfileProvider.notifier).clearAccount(id);
      ref.invalidate(cachedAccountProfileProvider(id));
      ref.invalidate(accountProfileProvider(id));
    } catch (_) {
      failure ??= const DeletionCleanupFailure('Clearing the saved profile');
    }
    try {
      await ref.read(pushRegistrationProvider).leaveForDeletion(id);
    } catch (_) {
      failure ??= const DeletionCleanupFailure(
        'Clearing notifications and signing out',
      );
    }
    if (client.auth.currentUser?.id == id) {
      failure ??= const DeletionCleanupFailure('Signing out');
    }
    if (failure != null) throw failure;
    if (client.auth.currentUser != null) return;
    ref.invalidate(syncCoordinatorProvider);
    ref.invalidate(driveBackupProvider);
    ref.invalidate(downloadManagerProvider);
    ref.invalidate(filesRepositoryProvider);
  },
);

class DeletionUi {
  const DeletionUi({
    this.busyUser,
    this.errorUser,
    this.message,
    this.instructor = false,
    this.ownedClassCount,
    this.ownershipBlocked = false,
  });
  final bool instructor, ownershipBlocked;
  final int? ownedClassCount;
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

  void refreshEligibility(String id) {
    if (state.busyUser != null) return;
    if (state.errorUser == id) {
      state = DeletionUi(errorUser: id, instructor: state.instructor);
    }
    ref.invalidate(instructorDeletionEligibilityProvider(id));
  }

  Future<void> request(
    String id,
    String confirmation, {
    bool instructor = false,
  }) async {
    if (state.busyUser != null ||
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
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
    if (previous?.stage != DeletionStage.pending && confirmation != 'DELETE') {
      return;
    }
    instructor = previous?.instructor ?? instructor;
    if (instructor && previous == null) {
      final eligibility = ref.read(instructorDeletionEligibilityProvider(id));
      if (eligibility.isLoading ||
          eligibility.hasError ||
          eligibility.asData?.value.count != 0 ||
          (state.errorUser == id && state.ownedClassCount != null)) {
        return;
      }
    }
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
      instructor: instructor,
    );
    remember(id, confirmation);
    var recorded = previous != null;
    var dispatched = false;
    state = DeletionUi(busyUser: id, instructor: instructor);
    try {
      await journal.put(id, record);
      recorded = true;
      await cleanup.block(id, true);
      if (!current()) return;
      dispatched = true;
      final result = await ref
          .read(accountDeletionRepositoryProvider)
          .request();
      if (!current()) return;
      await journal.put(id, record.at(result));
      if (!current()) return;
      if (result == DeletionStage.cleanup) {
        await _remove(id);
      }
    } on DeletionRejected catch (error) {
      if (current()) {
        try {
          // A prior accepted/uncertain attempt cannot be disproved by a later denial.
          if (previous == null) {
            await journal.put(id, null);
            await cleanup.block(id, false);
            if (!current()) return;
            if (error is OwnedClassesExist) {
              remember(id, '');
              ref.invalidate(instructorDeletionEligibilityProvider(id));
              state = DeletionUi(
                errorUser: id,
                instructor: instructor,
                ownershipBlocked: true,
                ownedClassCount: error.count,
              );
            } else {
              state = DeletionUi(
                errorUser: id,
                instructor: instructor,
                message: error.message,
              );
            }
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
      if (current()) {
        // A local preparation failure cannot have sent a deletion request.
        if (!dispatched && previous == null && recorded) {
          try {
            await cleanup.block(id, false);
            await journal.put(id, null);
            recorded = false;
          } catch (_) {
            // Preserve recovery protection if local rollback cannot finish.
          }
        }
        if (!current()) return;
        state = DeletionUi(
          errorUser: id,
          instructor: instructor,
          message: recorded
              ? "We couldn't confirm whether your account was deleted. Connect and check your account status before trying again."
              : "Couldn't delete your account. Try again.",
        );
      }
    } finally {
      if (state.busyUser == id) state = const DeletionUi();
    }
  }

  Future<void> removeLocal(String id) async {
    if (state.busyUser != null ||
        ref.read(deletionJournalProvider).asData?.value[id]?.stage !=
            DeletionStage.cleanup) {
      return;
    }
    state = DeletionUi(busyUser: id);
    await _remove(id);
    if (state.busyUser == id) state = const DeletionUi();
  }

  Future<void> _remove(String id) async {
    var step = 'Clearing notifications and signing out';
    try {
      await ref.read(deletionSessionCleanupProvider)(id);
      step = 'Removing saved files and account data';
      await ref.read(accountDeletionCleanupProvider).remove(id);
      step = 'Finishing account recovery';
      await ref.read(deletionJournalProvider.notifier).put(id, null);
      if (_draftUser == id) {
        _draftUser = null;
        _draft = '';
      }
    } catch (error) {
      final failedStep = error is DeletionCleanupFailure ? error.step : step;
      state = DeletionUi(
        errorUser: id,
        message:
            "Your account was deleted, but Filo couldn't remove all local files from this device. Try removing them again.\n\n$failedStep didn't finish. Close and reopen Filo, then tap Remove local files again.",
      );
    }
  }
}
