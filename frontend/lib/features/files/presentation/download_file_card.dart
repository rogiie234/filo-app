import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../drive_backup/presentation/drive_backup_screen.dart';
import '../application/files_providers.dart';
import '../data/download_manager.dart';
import 'file_viewer_screen.dart';

String fileSize(int? size) => size == null
    ? 'Size unavailable'
    : size < 1024
    ? '$size B'
    : size < 1048576
    ? '${(size / 1024).toStringAsFixed(1)} KB'
    : '${(size / 1048576).toStringAsFixed(1)} MB';
IconData fileIcon(String name, [String? mime]) =>
    mime?.startsWith('image/') == true ||
        RegExp(
          r'\.(jpe?g|png|webp|gif|bmp)$',
          caseSensitive: false,
        ).hasMatch(name)
    ? FiloIcons.image
    : name.toLowerCase().endsWith('.pdf')
    ? FiloIcons.pdf
    : RegExp(r'\.(xlsx?|csv)$', caseSensitive: false).hasMatch(name)
    ? FiloIcons.spreadsheet
    : RegExp(r'\.(pptx?)$', caseSensitive: false).hasMatch(name)
    ? FiloIcons.slides
    : FiloIcons.document;

class DownloadFileCard extends ConsumerStatefulWidget {
  const DownloadFileCard({
    super.key,
    required this.classId,
    required this.postId,
    required this.attachment,
    this.postTitle,
  });
  final String classId, postId;
  final String? postTitle;
  final CachePostAttachment attachment;
  @override
  ConsumerState<DownloadFileCard> createState() => _DownloadFileCardState();
}

class _DownloadFileCardState extends ConsumerState<DownloadFileCard> {
  bool _reporting = false;
  static final _notices = <String>{};
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _browser() async {
    if (ref.read(connectivityProvider).asData?.value != true) {
      _message("You're offline. Connect to open this link.");
      return;
    }
    final uri = Uri.tryParse(widget.attachment.url ?? '');
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message('Could not open this link. Try again.');
      }
    } catch (_) {
      _message('Could not open this link. Try again.');
    }
  }

  Future<void> _download(DownloadManager manager) async {
    final row = await manager.download(
      widget.attachment,
      widget.classId,
      widget.postId,
    );
    if (!mounted) {
      return;
    }
    final problem = manager.states[widget.attachment.id]?.error;
    if (row == null) {
      if (problem?.kind == 'browser') {
        await _browser();
      }
      return;
    }
    final user = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (user == null || !_notices.add(user)) {
      return;
    }
    try {
      if (!await manager.files.needsStorageNotice() || !mounted) {
        return;
      }
      final backup = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Your files are kept inside Filo'),
          content: const Text(
            'Downloaded files are stored inside Filo on this phone. Uninstalling Filo or clearing its app data removes these files. Drive backup can protect them by saving copies to your own Google Drive.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set up Drive backup'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      if (backup != null) {
        await manager.files.acknowledgeStorageNotice();
      }
      if (backup == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DriveBackupScreen()),
        );
      }
    } finally {
      _notices.remove(user);
    }
  }

  Future<void> _report() async {
    if (_reporting) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notify your instructor?'),
        content: const Text(
          "Report that you can't download this file so your instructor can check its sharing settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Notify instructor'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) {
      return;
    }
    setState(() => _reporting = true);
    try {
      await ref
          .read(supabaseClientProvider)
          .rpc('report_locked_link', params: {'p_post': widget.postId})
          .timeout(const Duration(seconds: 20));
      _message('Your report was sent to your instructor.');
    } on PostgrestException catch (error) {
      _message(
        error.message.toLowerCase().contains('already reported')
            ? "You've already reported a link on this post today."
            : "Couldn't send your report. Try again.",
      );
    } on TimeoutException {
      _message(
        "We couldn't confirm whether your report was sent. Try again when you're connected.",
      );
    } catch (_) {
      _message("Couldn't send your report. Try again.");
    } finally {
      if (mounted) {
        setState(() => _reporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final manager = ref.watch(downloadManagerProvider).asData?.value;
    final local = ref
        .watch(localFilesProvider)
        .asData
        ?.value
        .where((f) => f.sourceAttachmentId == a.id)
        .firstOrNull;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final downloadable =
        a.kind == 'file' ||
        (DownloadManager.driveId(a.url ?? '') != null &&
            !DownloadManager.video(a.url ?? ''));
    Widget content(bool exists) {
      final state = manager?.states[a.id] ?? const DownloadState();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FiloIcon(
                    a.kind == 'link'
                        ? FiloIcons.link
                        : fileIcon(a.name, a.mimeType),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      a.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${fileSize(a.sizeBytes)} · ${MaterialLocalizations.of(context).formatMediumDate(a.createdAt.toLocal())}',
              ),
              if (widget.postTitle != null) Text(widget.postTitle!),
              if (exists && local != null) ...[
                const Row(
                  children: [
                    FiloIcon(FiloIcons.checkCircle, size: 18),
                    SizedBox(width: 6),
                    Text('Available offline'),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FileViewerScreen(
                        file: local,
                        repository: manager!.files,
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ] else if (state.running)
                Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(value: state.progress),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.progress == null
                            ? 'Downloading…'
                            : 'Downloading… ${(state.progress! * 100).round()}%',
                      ),
                    ),
                    TextButton(
                      onPressed: () => manager?.cancel(a.id),
                      child: const Text('Cancel'),
                    ),
                  ],
                )
              else ...[
                if (local != null)
                  const Text('This file is no longer on your device.'),
                if (state.error != null) Text(state.error!.message),
                if (!online)
                  Text(
                    downloadable
                        ? "You're offline. Connect to download."
                        : "You're offline. Connect to open this link.",
                  ),
                TextButton.icon(
                  onPressed: !online || manager == null
                      ? null
                      : downloadable
                      ? () => _download(manager)
                      : _browser,
                  icon: FiloIcon(
                    downloadable ? FiloIcons.download : FiloIcons.openExternal,
                  ),
                  label: Text(
                    downloadable
                        ? state.error == null
                              ? 'Download'
                              : 'Retry'
                        : 'Open in browser',
                  ),
                ),
                if (state.error?.kind == 'locked' && manager != null)
                  FutureBuilder<CacheProfile?>(
                    future: manager.files.db.readProfile(
                      ref.read(supabaseClientProvider).auth.currentUser!.id,
                    ),
                    builder: (context, profile) =>
                        profile.data?.role == 'student'
                        ? TextButton(
                            onPressed: online && !_reporting ? _report : null,
                            child: const Text('Notify instructor'),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    Widget body() => local == null || manager == null
        ? content(false)
        : FutureBuilder<bool>(
            future: manager.files.storage.file(local.relativePath).exists(),
            builder: (_, snapshot) => content(snapshot.data == true),
          );
    return manager == null
        ? body()
        : ListenableBuilder(listenable: manager, builder: (_, _) => body());
  }
}
