import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../application/post_providers.dart';

/// Shared material/assignment attachment opener; signed URLs stay in memory.
class PostAttachmentTile extends ConsumerStatefulWidget {
  const PostAttachmentTile({
    super.key,
    required this.classId,
    required this.postId,
    required this.attachment,
    this.onUnavailable,
  });
  final String classId, postId;
  final CachePostAttachment attachment;
  final VoidCallback? onUnavailable;
  @override
  ConsumerState<PostAttachmentTile> createState() => _PostAttachmentTileState();
}

class _PostAttachmentTileState extends ConsumerState<PostAttachmentTile> {
  final Set<String> _opening = {};
  Future<void> _open(CachePostAttachment attachment) async {
    if (!_opening.add(attachment.id)) return;
    setState(() {});
    try {
      if (ref.read(connectivityProvider).asData?.value != true) {
        throw StateError('offline');
      }
      final available = await ref
          .read(supabaseClientProvider)
          .from('posts')
          .select('id')
          .eq('id', widget.postId)
          .eq('class_id', widget.classId)
          .isFilter('deleted_at', null)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (available == null) {
        if (mounted) widget.onUnavailable?.call();
        return;
      }
      final repository = await ref.read(
        postAttachmentRepositoryProvider.future,
      );
      if (repository == null) throw StateError('unavailable');
      String? address;
      if (attachment.kind == 'file') {
        address = await repository
            .signedFileLink(attachment.id)
            .timeout(const Duration(seconds: 20));
      } else {
        final row = await ref
            .read(supabaseClientProvider)
            .from('post_attachments')
            .select('url')
            .eq('id', attachment.id)
            .eq('post_id', widget.postId)
            .isFilter('deleted_at', null)
            .maybeSingle()
            .timeout(const Duration(seconds: 20));
        address = row?['url'] as String?;
      }
      final uri = address == null ? null : Uri.tryParse(address);
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw StateError('invalid link');
      }
      if (!await launchUrl(
        uri,
        mode: attachment.kind == 'file'
            ? LaunchMode.externalApplication
            : LaunchMode.inAppBrowserView,
      )) {
        // Link attachments must use the browser, including Drive links.
        throw StateError('open failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(connectivityProvider).asData?.value == false
                  ? 'Connect to the internet to open this attachment. Tap it again to retry.'
                  : 'Could not open this attachment. Tap it again to retry.',
            ),
          ),
        );
      }
    } finally {
      _opening.remove(attachment.id);
      if (mounted) setState(() {});
    }
  }

  IconData _icon(CachePostAttachment file) {
    final name = file.name.toLowerCase();
    if (file.mimeType?.startsWith('image/') == true ||
        RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(name)) {
      return Icons.image_outlined;
    }
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (RegExp(r'\.(docx?|txt|rtf)$').hasMatch(name)) {
      return Icons.description_outlined;
    }
    if (RegExp(r'\.(xlsx?|csv)$').hasMatch(name)) {
      return Icons.table_chart_outlined;
    }
    if (RegExp(r'\.(pptx?)$').hasMatch(name)) return Icons.slideshow_outlined;
    if (file.mimeType?.startsWith('audio/') == true) {
      return Icons.audio_file_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _size(int? bytes) {
    if (bytes == null) return 'Size unavailable';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final host = Uri.tryParse(attachment.url ?? '')?.host.toLowerCase();
    final drive =
        attachment.kind == 'link' &&
        (host == 'drive.google.com' || host == 'docs.google.com');
    return Card(
      child: ListTile(
        leading: Icon(
          attachment.kind == 'file'
              ? _icon(attachment)
              : drive
              ? Icons.add_to_drive
              : Icons.link,
        ),
        title: Text(drive ? 'Google Drive' : attachment.name),
        subtitle: Text(
          attachment.kind == 'file'
              ? _size(attachment.sizeBytes)
              : attachment.url ?? '',
        ),
        trailing: _opening.contains(attachment.id)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.open_in_new),
        onTap: _opening.contains(attachment.id)
            ? null
            : () => _open(attachment),
      ),
    );
  }
}
