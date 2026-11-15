import '../../../core/widgets/filo_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account_deletion_journal.dart';
import '../../../core/supabase/session_gate.dart';
import '../application/account_deletion.dart';
import 'delete_account_screen.dart';

class DeletionRecoveryGate extends ConsumerWidget {
  const DeletionRecoveryGate({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(deletionJournalProvider);
    final login = ref.watch(loginSessionProvider).asData?.value?.user.id;
    final flow = ref.watch(accountDeletionProvider);
    if (journal.isLoading || journal.hasError) {
      return Navigator(
        key: ValueKey(journal.hasError ? 'recovery-error' : 'recovery-loading'),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: Center(
                child: journal.hasError
                    ? EmptyState(
                        title: 'Account recovery unavailable',
                        body: 'Retry to load the saved recovery status before continuing.',
                        pose: 'confused',
                        primaryAction: EmptyStateAction(
                          label: 'Retry',
                          onPressed: () =>
                              ref.invalidate(deletionJournalProvider),
                        ),
                      )
                    : const FiloCircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    }
    final records = journal.requireValue;
    String? target;
    for (final record in records.values) {
      if (record.stage == DeletionStage.cleanup) {
        target = record.userId;
        break;
      }
    }
    target ??=
        login != null &&
            (records.containsKey(login) ||
                flow.busyUser == login ||
                flow.errorUser == login)
        ? login
        : null;
    if (target == null) return child;
    final id = target;
    return Navigator(
      key: ValueKey('account-deletion-$id'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => DeleteAccountScreen(
          userId: id,
          instructor: records[id]?.instructor ?? flow.instructor,
        ),
      ),
    );
  }
}
