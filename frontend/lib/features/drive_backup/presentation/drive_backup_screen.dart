import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../data/drive_backup_service.dart';
import '../../../core/sync/sync_providers.dart';
import '../../files/application/files_providers.dart';

class DriveBackupScreen extends ConsumerWidget {
  const DriveBackupScreen({super.key});

  Future<void> _enable(BuildContext context, DriveBackupService service) async {
    final accepted = await showFiloConfirmation(
      context,
      title: 'Allow Drive backup?',
      icon: FiloIcons.cloudUpload,
      message:
          'Filo needs permission to create and manage the backup files it '
          'creates in your Google Drive. This permission does not give Filo '
          'access to all your Drive files. You can use local files without '
          'turning on backup.',
      confirmLabel: 'Continue to Google',
      cancelLabel: 'Not now',
    );
    if (accepted == true && service.active) {
      await service.enable();
    }
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    DriveBackupService service,
  ) async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null || !service.active) {
        return;
      }
      if (picked.path == null) {
        throw StateError('No local path');
      }
      final repository = await ref.read(filesRepositoryProvider.future);
      if (repository == null) {
        return;
      }
      await repository.importFile(File(picked.path!), picked.name, null);
      await service.queueLibrary();
      await (await ref.read(syncCoordinatorProvider.future))
          ?.run(retryFailed: true);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not select the file. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(driveBackupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Drive backup')),
      body: SafeArea(
        top: false,
        child: backup.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading Drive backup',
            ),
          ),
          error: (_, _) => _BackupUnavailable(
            message: 'Could not open backup.',
            onRetry: () => ref.invalidate(driveBackupProvider),
          ),
          data: (service) => service == null
              ? const _BackupUnavailable(
                  message: 'Sign in to use Drive backup.',
                )
              : ListenableBuilder(
                  listenable: service,
                  builder: (context, _) => _content(context, ref, service),
                ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    DriveBackupService service,
  ) {
    final canBackUp = service.enabled && !service.busy;
    final email = service.client.auth.currentUser?.email;
    final last = DateTime.tryParse(service.lastSuccess ?? '')?.toLocal();
    final lastLabel = last == null
        ? 'No backups yet.'
        : 'Last backup: '
              '${MaterialLocalizations.of(context).formatMediumDate(last)}, '
              '${TimeOfDay.fromDateTime(last).format(context)}';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _BackupIcon(icon: FiloIcons.cloudUpload, size: 72),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Back up your files.',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: FiloColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Save copies of files from this phone to your own Google '
                      'Drive, in a folder named Filo Backup. Backup is one-way.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: FiloColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (email != null && email.isNotEmpty) ...[
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                          color: FiloColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      'Use your Google account to save copies of your files. '
                      'Google may ask you to allow Drive access.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: FiloColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FiloPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Turn on Drive backup',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            value: service.enabled,
                            onChanged: service.busy && !service.enabled
                                ? null
                                : (value) async {
                                    if (value) {
                                      await _enable(context, service);
                                    } else {
                                      await service.disable();
                                    }
                                  },
                          ),
                          const Divider(color: FiloColors.border, height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Back up on Wi-Fi only',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text(
                              'Wait for Wi-Fi before uploading to save mobile data.',
                              style: TextStyle(
                                color: FiloColors.secondary,
                                height: 1.4,
                              ),
                            ),
                            value: service.wifiOnly,
                            onChanged: service.busy
                                ? null
                                : service.setWifiOnly,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FiloPanel(
                      color: FiloColors.tint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ExcludeSemantics(
                                child: FiloIcon(
                                  service.enabled
                                      ? FiloIcons.cloudUpload
                                      : FiloIcons.drive,
                                  color: FiloColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  service.enabled
                                      ? 'Backup status'
                                      : 'Drive backup is off',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              service.message,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ),
                          if (service.busy) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(
                              semanticsLabel: 'Drive backup in progress',
                              minHeight: 4,
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(color: FiloColors.border, height: 1),
                          const SizedBox(height: 16),
                          Text(
                            lastLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${service.pendingCount} files pending',
                            style: const TextStyle(color: FiloColors.secondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FiloButton(
                      label: 'Back up now / Retry',
                      icon: FiloIcons.cloudUpload,
                      busy: service.busy,
                      onPressed: canBackUp
                          ? () async {
                              await service.queueLibrary();
                              await (await ref.read(
                                syncCoordinatorProvider.future,
                              ))?.run(retryFailed: true);
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    FiloButton(
                      secondary: true,
                      label: 'Choose a file to back up',
                      icon: FiloIcons.add,
                      onPressed: canBackUp
                          ? () => _choose(context, ref, service)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose downloaded files with Android\u2019s file picker. '
                      'All files in My Files are backed up. Keep Filo open to '
                      'upload; pending files resume when you reopen it.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: FiloColors.secondary,
                      ),
                    ),
                    if (service.jobs.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'Files in backup',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: service.jobs.length,
                itemBuilder: (context, index) {
                  final job = service.jobs[index];
                  final complete = job['status'] == 'complete';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FiloPanel(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BackupIcon(
                            icon: complete
                                ? FiloIcons.cloudReady
                                : FiloIcons.cloudUpload,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  complete
                                      ? '${job['size']} bytes backed up'
                                            '${(job['elapsed_ms'] as int? ?? 0) > 0 ? ' \u00b7 ${((job['elapsed_ms'] as int) / 1000).toStringAsFixed(2)} s (latest upload attempt)' : ''}'
                                      : '${job['uploaded']} / ${job['size']} bytes',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: FiloColors.secondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              sliver: SliverToBoxAdapter(
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () async {
                    final opened = await launchUrl(
                      Uri.parse('https://drive.google.com/drive/my-drive'),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Open drive.google.com in your browser.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const FiloIcon(FiloIcons.openExternal),
                  label: const Text('View Google Drive'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupIcon extends StatelessWidget {
  const _BackupIcon({required this.icon, this.size = 40});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FiloColors.selected,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: FiloIcon(icon, size: size * .5, color: FiloColors.primary),
    ),
  );
}

class _BackupUnavailable extends StatelessWidget {
  const _BackupUnavailable({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: FiloPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BackupIcon(icon: FiloIcons.drive, size: 64),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FiloButton(label: 'Retry', onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
