import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../application/post_providers.dart';
import 'post_attachment_tile.dart';

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
                    PostAttachmentTile(
                      classId: widget.classId,
                      postId: widget.postId,
                      attachment: attachment,
                      onUnavailable: () => setState(() => _unavailable = true),
                    ),
                ],
              ],
            ),
    );
  }
}
