import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../drive_backup/presentation/drive_backup_screen.dart';
import '../application/files_providers.dart';
import '../data/download_manager.dart';
import 'file_viewer_screen.dart';
import 'remote_file_preview.dart';

String fileSize(int? size) => size == null
    ? 'Size unavailable'
    : size < 1024
    ? '$size B'
    : size < 1048576
    ? '${(size / 1024).toStringAsFixed(1)} KB'
    : '${(size / 1048576).toStringAsFixed(1)} MB';
IconData fileIcon(String name, [String? mime]) =>
    FiloFileDetails.fromName(name, mimeType: mime).type.icon;

class DownloadFileCard extends ConsumerStatefulWidget {
  const DownloadFileCard({
    super.key,
    required this.classId,
    this.showMascot = false,
    required this.postId,
    required this.attachment,
    this.postTitle,
  });
  final bool showMascot;
  final String classId, postId;
  final String? postTitle;
  final CachePostAttachment attachment;
  @override
  ConsumerState<DownloadFileCard> createState() => _DownloadFileCardState();
}

class _DownloadFileCardState extends ConsumerState<DownloadFileCard> {
  Future<Uri> _previewSource() async {
    final client = ref.read(supabaseClientProvider);
    await client
        .from('posts')
        .select('id')
        .eq('id', widget.postId)
        .eq('class_id', widget.classId)
        .isFilter('deleted_at', null)
        .single();
    final source = await client
        .from('post_attachments')
        .select()
        .eq('id', widget.attachment.id)
        .eq('post_id', widget.postId)
        .isFilter('deleted_at', null)
        .single();
    if (source['kind'] == 'link') {
      final uri = Uri.tryParse(source['url'] as String? ?? '');
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        throw StateError('Unavailable preview');
      }
      return uri;
    }
    return Uri.parse(
      await client.storage
          .from('materials')
          .createSignedUrl(source['storage_path'] as String, 3600),
    );
  }

  Future<void> _preview(
    LocalFileRecord? local,
    DownloadManager? manager,
    bool exists,
  ) async {
    if (exists && local != null && manager != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileViewerScreen(
            showMascot: widget.showMascot,
            file: local,
            repository: manager.files,
          ),
        ),
      );
      return;
    }
    if (ref.read(connectivityProvider).asData?.value != true) {
      _message('Connect to the internet to preview this file.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RemoteFilePreview(
          name: widget.attachment.name,
          mimeType: widget.attachment.mimeType,
          browserOnly: widget.attachment.kind == 'link',
          load: _previewSource,
        ),
      ),
    );
  }

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
      final backup = await showFiloDialog<bool>(
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
    final yes = await showFiloDialog<bool>(
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
    final localFiles = ref.watch(localFilesProvider);
    final local = localFiles.asData?.value
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
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: FiloSpacing.s12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FiloRadii.large),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FiloSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(FiloRadii.small),
                onTap: () => _preview(local, manager, exists),
                child: Tooltip(
                  message: 'Preview file',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: FiloSpacing.s4,
                    ),
                    child: Row(
                      children: [
                        FiloFileTypeTile(
                          details: FiloFileDetails.fromName(
                            a.name,
                            mimeType: a.mimeType,
                            kind: a.kind,
                          ),
                        ),
                        const SizedBox(width: FiloSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              FiloFileTypeLabel(
                                details: FiloFileDetails.fromName(
                                  a.name,
                                  mimeType: a.mimeType,
                                  kind: a.kind,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const FiloIcon(FiloIcons.chevronRight),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FiloSpacing.s4),
              Text(
                '${fileSize(a.sizeBytes)} · ${MaterialLocalizations.of(context).formatMediumDate(a.createdAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.postTitle != null) ...[
                const SizedBox(height: FiloSpacing.s4),
                Text(
                  widget.postTitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: FiloSpacing.s4),
                child: Divider(height: 1),
              ),
              if (exists && local != null) ...[
                FiloStatusChip.preset(FiloStatusPreset.availableOffline),
              ] else if (state.running)
                Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: FiloCircularProgressIndicator(
                        value: state.progress,
                      ),
                    ),
                    const SizedBox(width: FiloSpacing.s12),
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
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: FiloSpacing.s8,
                  overflowSpacing: FiloSpacing.s4,
                  children: [
                    if (downloadable &&
                        manager != null &&
                        localFiles.hasValue &&
                        !localFiles.isLoading &&
                        !localFiles.hasError &&
                        local == null &&
                        state.error == null)
                      FiloStatusChip.preset(FiloStatusPreset.cloudOnly)
                    else
                      const SizedBox.shrink(),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(112, 48),
                      ),
                      onPressed: !online || manager == null
                          ? null
                          : downloadable
                          ? () => _download(manager)
                          : _browser,
                      icon: FiloIcon(
                        downloadable
                            ? FiloIcons.download
                            : FiloIcons.openExternal,
                      ),
                      label: Text(
                        downloadable
                            ? state.error == null
                                  ? 'Download'
                                  : 'Retry'
                            : 'Open in browser',
                      ),
                    ),
                  ],
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
