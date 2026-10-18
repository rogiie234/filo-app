import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/drive_backup_service.dart';

class DriveBackupScreen extends ConsumerWidget {
  const DriveBackupScreen({super.key});

  Future<void> _enable(BuildContext context, DriveBackupService service) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Drive backup?'),
        content: const Text(
          'Filo needs permission to create and manage the backup files it '
          'creates in your Google Drive. This permission does not give Filo '
          'access to all your Drive files. You can use local files without '
          'turning on backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to Google'),
          ),
        ],
      ),
    );
    if (accepted == true && service.active) {
      await service.enable();
    }
  }

  Future<void> _choose(BuildContext context, DriveBackupService service) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || !service.active) {
        return;
      }
      final picked = result.files.single;
      if (picked.path == null) {
        throw StateError('No local path');
      }
      await service.enqueue(File(picked.path!), picked.name);
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
      body: backup.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(driveBackupProvider),
            child: const Text('Could not open backup. Retry'),
          ),
        ),
        data: (service) => service == null
            ? const Center(child: Text('Sign in to use Drive backup.'))
            : ListenableBuilder(
                listenable: service,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Save copies of files from this phone to your own Google '
                      'Drive, in a folder named Filo Backup. Backup is one-way.',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Turn on Drive backup'),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Back up on Wi-Fi only'),
                      subtitle: const Text(
                        'Wait for Wi-Fi before uploading to save mobile data.',
                      ),
                      value: service.wifiOnly,
                      onChanged: service.busy ? null : service.setWifiOnly,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose downloaded files with Android’s file picker. '
                      'Only selected files are backed up. Keep Filo open to '
                      'upload; pending files resume when you reopen it.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: service.enabled && !service.busy
                          ? () => _choose(context, service)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Choose a file to back up'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          service.enabled &&
                              !service.busy &&
                              service.pendingCount > 0
                          ? service.run
                          : null,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Back up now / Retry'),
                    ),
                    if (service.busy) const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(service.message)),
                    const SizedBox(height: 12),
                    Text(
                      service.lastSuccess == null
                          ? 'No backups yet.'
                          : 'Last selected-file backup: '
                                '${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(service.lastSuccess!).toLocal())}, '
                                '${TimeOfDay.fromDateTime(DateTime.parse(service.lastSuccess!).toLocal()).format(context)}',
                    ),
                    Text('${service.pendingCount} files pending'),
                    const SizedBox(height: 16),
                    for (final job in service.jobs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          job['status'] == 'complete'
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_upload_outlined,
                        ),
                        title: Text(job['name'] as String),
                        subtitle: Text(
                          job['status'] == 'complete'
                              ? '${job['size']} bytes backed up'
                                    '${(job['elapsed_ms'] as int? ?? 0) > 0 ? ' · ${((job['elapsed_ms'] as int) / 1000).toStringAsFixed(2)} s (latest upload attempt)' : ''}'
                              : '${job['uploaded']} / ${job['size']} bytes',
                        ),
                      ),
                    TextButton.icon(
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
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View Google Drive'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
