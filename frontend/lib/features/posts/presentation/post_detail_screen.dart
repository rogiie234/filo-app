import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../application/post_providers.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.classId,
    required this.postId,
  });
  final String classId;
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final Set<String> _opening = {};
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && ref.read(connectivityProvider).asData?.value == true) {
        try {
          await _available();
        } catch (_) {
          /* Cached reading remains available. */
        }
      }
    });
  }

  String _date(BuildContext context, DateTime value) {
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} · '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Future<bool> _available() async {
    final row = await ref
        .read(supabaseClientProvider)
        .from('posts')
        .select('id')
        .eq('id', widget.postId)
        .eq('class_id', widget.classId)
        .isFilter('deleted_at', null)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (mounted) setState(() => _unavailable = row == null);
    return row != null;
  }

  Future<void> _open(CachePostAttachment attachment) async {
    if (!_opening.add(attachment.id)) return;
    setState(() {});
    try {
      if (ref.read(connectivityProvider).asData?.value != true) {
        throw StateError('offline');
      }
      if (!await _available()) return;
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
    ref.watch(postSyncLifecycleProvider(widget.classId));
    final sync = ref.watch(postSyncProvider(widget.classId));
    ref.listen(postSyncProvider(widget.classId), (_, next) async {
      if (next.hasValue &&
          !next.isLoading &&
          ref.read(connectivityProvider).asData?.value == true) {
        try {
          await _available();
        } catch (_) {
          /* Keep cached content on network failure. */
        }
      }
    });
    final posts = ref.watch(postsProvider(widget.classId));
    final attachments = ref.watch(postAttachmentsProvider(widget.postId));
    CachePost? post;
    for (final item in posts.asData?.value ?? <CachePost>[]) {
      if (item.id == widget.postId) post = item;
    }
    final online = ref.watch(connectivityProvider).asData?.value == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post detail'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: online
                ? () {
                    ref.invalidate(postsProvider(widget.classId));
                    ref.invalidate(postAttachmentsProvider(widget.postId));
                    ref.invalidate(postSyncProvider(widget.classId));
                  }
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _unavailable ||
              (post == null &&
                  posts.hasValue &&
                  sync.hasValue &&
                  !sync.hasError &&
                  !posts.hasError &&
                  !sync.isLoading &&
                  online)
          ? const Center(child: Text('This item is no longer available.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!online)
                  const Text(
                    'You’re offline. Cached content is shown. Connect to open attachments.',
                  ),
                if (sync.hasError || posts.hasError)
                  const Text(
                    'Could not refresh this post. Use Refresh to retry.',
                  ),
                if (post == null)
                  if (posts.isLoading || sync.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    const Text('Connect and refresh to load this post.')
                else ...[
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(_date(context, post.createdAt)),
                  if (post.kind == 'assignment') ...[
                    Text('${post.points ?? 0} points'),
                    Text(
                      post.dueAt == null
                          ? 'No due date'
                          : 'Due ${_date(context, post.dueAt!)}',
                    ),
                  ],
                  const SizedBox(height: 24),
                  SelectableText(post.body ?? ''),
                  const SizedBox(height: 24),
                  if (attachments.isLoading) const LinearProgressIndicator(),
                  if (attachments.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(
                        postAttachmentsProvider(widget.postId),
                      ),
                      child: const Text('Could not load attachments. Retry'),
                    ),
                  for (final attachment
                      in attachments.asData?.value ?? <CachePostAttachment>[])
                    _attachment(attachment),
                ],
              ],
            ),
    );
  }

  Widget _attachment(CachePostAttachment attachment) {
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
