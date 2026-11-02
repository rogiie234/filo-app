import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/auth_providers.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../drive_backup/presentation/drive_backup_screen.dart';
import '../../files/presentation/download_file_card.dart' show fileSize;
import '../application/storage_settings.dart';
import '../../files/data/file_storage.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({required this.userId, super.key});
  final String userId;
  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  final _scroll = ScrollController();
  bool _confirming = false, _clearing = false, _accountLost = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    ref.invalidate(storageSettingsProvider);
  }

  bool get _current =>
      mounted &&
      !_accountLost &&
      ref.read(authUserIdProvider).asData?.value == widget.userId;

  Future<void> _clear() async {
    if (_confirming || _clearing || !_current) return;
    _confirming = true;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Clear cache?',
      message: 'This removes temporary cached data from Filo on this device. Your downloaded files will stay.',
      confirmLabel: 'Clear cache',
      cancelLabel: 'Cancel',
    );
    _confirming = false;
    if (!confirmed || !_current) return;
    setState(() => _clearing = true);
    final cleared = await ref.read(storageSettingsProvider.notifier).clear();
    if (!_current) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _clearing = false);
    if (cleared)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cache cleared. Your downloaded files are still on this device.',
          ),
        ),
      );
  }

  Widget _size(String label, int bytes) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Semantics(
          label: '$label: $bytes bytes',
          excludeSemantics: true,
          child: Text(
            fileSize(bytes),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (_, next) {
      if (next.asData != null && next.asData!.value != widget.userId)
        _accountLost = true;
    });
    final account = ref.watch(authUserIdProvider);
    if (_accountLost || account.asData?.value != widget.userId) {
      if (!account.isLoading)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final usage = ref.watch(storageSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(24),
          children: [
            usage.when(
              skipLoadingOnRefresh: false,
              data: (value) => FiloPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _size('Downloads and personal files', value.filesBytes),
                    const Divider(),
                    _size('Temporary cache', value.cacheBytes),
                  ],
                ),
              ),
              loading: () => FiloPanel(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _clearing
                            ? 'Clearing cache\u2026'
                            : 'Calculating storage\u2026',
                      ),
                    ],
                  ),
                ),
              ),
              error: (error, _) => Semantics(
                liveRegion: true,
                child: EmptyState(
                  title: error is FileProblem && error.kind == 'cache-clear'
                      ? error.message
                      : "Couldn't read storage usage. Try again.",
                  pose: 'confused',
                  bob: false,
                  action: FiloButton(
                    label: 'Retry',
                    onPressed:
                        error is FileProblem && error.kind == 'cache-clear'
                        ? _clear
                        : _refresh,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'These sizes cover files for this account on this device. They exclude the database, active transfers, queued backups and other app data.',
            ),
            const SizedBox(height: 16),
            FiloButton(
              label: 'Refresh',
              secondary: true,
              onPressed: usage.isLoading || _clearing ? null : _refresh,
            ),
            const SizedBox(height: 16),
            FiloButton(
              label: 'Clear cache',
              busy: _clearing,
              onPressed:
                  !usage.isLoading &&
                      (usage.asData?.value.cacheBytes ?? 0) > 0 &&
                      !_clearing
                  ? _clear
                  : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'Clearing the cache in Filo does not delete your downloaded files.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Only unused temporary files are cleared. The cache may already be empty.',
            ),
            const SizedBox(height: 24),
            FiloPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your files are kept inside Filo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Downloaded files are stored inside Filo on this phone. Uninstalling Filo or clearing its app data removes these files. Drive backup can protect them by saving copies to your own Google Drive.',
                  ),
                  const SizedBox(height: 16),
                  FiloButton(
                    label: 'Set up Drive backup',
                    secondary: true,
                    onPressed: _clearing
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const DriveBackupScreen(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
