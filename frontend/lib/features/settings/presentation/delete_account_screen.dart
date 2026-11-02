import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account_deletion_journal.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/account_deletion.dart';

const studentDeletionWarning =
    "Your name, email address, and profile photo will be removed. Your submissions and grades will stay in your instructors' records as Deleted User. You will leave all your classes. Downloaded files stored in Filo on this device will be removed. If you selected the wrong role, you can sign in again after deleting your account and choose your role again. To join your classes again, you will need to request to join and receive instructor approval.";

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({required this.userId, super.key});
  final String userId;
  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  late final TextEditingController _confirmation;
  @override
  void initState() {
    super.initState();
    _confirmation = TextEditingController(
      text: ref.read(accountDeletionProvider.notifier).draft(widget.userId),
    );
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId;
    final record = ref.watch(deletionJournalProvider).asData?.value[id];
    final ui = ref.watch(accountDeletionProvider);
    final busy = ui.busyUser != null;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final session = ref.watch(deletionSessionProvider);
    final sameSession =
        session?.userId == id &&
        (record == null || record.sessionId == session?.sessionId);
    final cleanup = record?.stage == DeletionStage.cleanup;
    final pending = record?.stage == DeletionStage.pending;
    final message = ui.errorUser == id ? ui.message : null;
    ref.listen(accountDeletionProvider, (_, next) {
      if (next.busyUser == null &&
          ref.read(deletionJournalProvider).asData?.value[id]?.stage ==
              DeletionStage.uncertain) {
        _confirmation.clear();
        ref.read(accountDeletionProvider.notifier).remember(id, '');
      }
    });
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !busy && record == null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delete your account?'),
          automaticallyImplyLeading: !busy && record == null,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!cleanup)
                FiloPanel(
                  color: colors.errorContainer,
                  child: Text(
                    studentDeletionWarning,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              const SizedBox(height: 20),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (cleanup && !busy && message == null)
                const Text(
                  "Your account was deleted, but Filo couldn't remove all local files from this device. Try removing them again.",
                ),
              if (pending)
                const Text(
                  'Your account deletion is still processing. Resume deletion continues the accepted request; it does not undo it.',
                ),
              if (record?.stage == DeletionStage.uncertain &&
                  !busy &&
                  message == null)
                const Text(
                  "We couldn't confirm whether your account was deleted. Connect and check your account status before trying again.",
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Semantics(liveRegion: true, child: Text(message)),
                ),
              if (!cleanup && !pending) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _confirmation,
                  enabled: !busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE',
                    helperText:
                        'Enter DELETE exactly to enable account deletion.',
                    helperMaxLines: 3,
                  ),
                  onChanged: (value) {
                    ref
                        .read(accountDeletionProvider.notifier)
                        .remember(id, value);
                    setState(() {});
                  },
                ),
              ],
              const SizedBox(height: 20),
              if (!online && !cleanup)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Connect to the internet to delete your account.',
                  ),
                ),
              if (!sameSession && !cleanup)
                const Text('Your session expired. Please sign in again.'),
              FiloButton(
                label: busy
                    ? cleanup
                          ? 'Removing local files\u2026'
                          : 'Deleting account\u2026'
                    : cleanup
                    ? 'Remove local files'
                    : pending
                    ? 'Resume deletion'
                    : message != null
                    ? 'Retry'
                    : 'Delete my account',
                destructive: true,
                busy: busy,
                onPressed: busy
                    ? null
                    : cleanup
                    ? () => ref
                          .read(accountDeletionProvider.notifier)
                          .removeLocal(id)
                    : sameSession &&
                          online &&
                          (pending || _confirmation.text == 'DELETE')
                    ? () => ref
                          .read(accountDeletionProvider.notifier)
                          .request(id, _confirmation.text)
                    : null,
              ),
              const SizedBox(height: 16),
              if (!busy && record == null)
                FiloButton(
                  label: 'Cancel',
                  secondary: true,
                  onPressed: () {
                    ref.read(accountDeletionProvider.notifier).dismiss(id);
                    Navigator.of(context).maybePop();
                  },
                ),
              if (!busy && record != null && !cleanup)
                FiloButton(
                  label: 'Sign out',
                  secondary: true,
                  onPressed: () => ref
                      .read(accountDeletionProvider.notifier)
                      .leaveRecovery(id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
