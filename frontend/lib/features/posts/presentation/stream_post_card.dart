import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/domain/prototype_models.dart';

String _date(BuildContext context, DateTime value, {bool time = false}) {
  final local = value.toLocal();
  final labels = MaterialLocalizations.of(context);
  final date = labels.formatMediumDate(local);
  return time
      ? '$date, ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}'
      : date;
}

String streamDueLabel(BuildContext context, ClassPost post) =>
    post.dueAt != null
    ? 'Due ${_date(context, post.dueAt!, time: true)}'
    : post.dueLabel ?? 'No due date';

class PostTypeIcon extends StatelessWidget {
  const PostTypeIcon({super.key, required this.type});
  final String type;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: FiloColors.surface,
    foregroundColor: FiloColors.primary,
    child: FiloIcon(switch (type) {
      'assignment' => FiloIcons.assessment,
      'material' => FiloIcons.document,
      _ => FiloIcons.announcement,
    }),
  );
}

class StreamPostCard extends StatelessWidget {
  const StreamPostCard({
    super.key,
    required this.post,
    required this.instructor,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });
  final ClassPost post;
  final bool instructor;
  final VoidCallback onOpen;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final type = switch (post.postType) {
      'assignment' => 'Assignment',
      'material' => 'Material',
      _ => 'Announcement',
    };
    return Material(
      color: FiloColors.tint,
      elevation: 1,
      shadowColor: FiloColors.ink.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: FiloColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PostTypeIcon(type: post.postType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (post.createdAt != null)
                          Text(
                            _date(context, post.createdAt!),
                            style: const TextStyle(
                              color: FiloColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (instructor)
                    PopupMenuButton<String>(
                      tooltip: 'Post menu',
                      icon: const FiloIcon(FiloIcons.moreVertical),
                      onSelected: (action) {
                        if (action == 'edit') {
                          onEdit?.call();
                        } else if (action == 'delete') {
                          onDelete?.call();
                        } else {
                          onOpen();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View post'),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          enabled: onEdit != null,
                          child: const Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: onDelete != null,
                          child: const Text('Delete'),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      tooltip: 'Open post',
                      onPressed: onOpen,
                      icon: const FiloIcon(FiloIcons.chevronRight),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const FiloIcon(
                    FiloIcons.attachment,
                    size: 18,
                    color: FiloColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post.attachments.length} ${post.attachments.length == 1 ? 'attachment' : 'attachments'}',
                    style: const TextStyle(color: FiloColors.secondary),
                  ),
                ],
              ),
              if (post.points != null) Text('${post.points} points'),
              if (post.assignment) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FiloIcon(FiloIcons.clock, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(streamDueLabel(context, post))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StreamPostSkeleton extends StatefulWidget {
  const StreamPostSkeleton({super.key});
  @override
  State<StreamPostSkeleton> createState() => _StreamPostSkeletonState();
}

class _StreamPostSkeletonState extends State<StreamPostSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: .45,
    upperBound: 1,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _fade.stop();
      _fade.value = 1;
    } else if (!_fade.isAnimating) {
      _fade.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading posts',
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: _fade,
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FiloPanel(
                  color: FiloColors.tint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(backgroundColor: FiloColors.mint),
                      const SizedBox(height: 16),
                      for (final width in [180.0, double.infinity, 120.0])
                        Container(
                          height: 16,
                          width: width,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: FiloColors.mint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
