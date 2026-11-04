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
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    foregroundColor: Theme.of(context).colorScheme.primary,
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
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shadowColor: Theme.of(context).colorScheme.onSurface
          .withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FiloRadii.large),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(FiloSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PostTypeIcon(type: post.postType),
                  const SizedBox(width: FiloSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: FiloTypography.strongLabel(context).copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (post.createdAt != null)
                          Text(
                            _date(context, post.createdAt!),
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (instructor)
                    PopupMenuButton<String>(
                      tooltip: 'Post menu',
                      icon: Icon(
                        FiloIcons.moreVertical,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (action) {
                        if (action == 'edit') {
                          onEdit?.call();
                        } else if (action == 'delete') {
                          onDelete?.call();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: onEdit != null,
                          child: const Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          enabled: onDelete != null,
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: onDelete == null
                                  ? null
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
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
              const SizedBox(height: FiloSpacing.s12),
              Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.message.isNotEmpty) ...[
                const SizedBox(height: FiloSpacing.s8),
                Text(
                  post.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: FiloSpacing.s12),
              const Divider(height: 1),
              const SizedBox(height: FiloSpacing.s12),
              Wrap(
                spacing: FiloSpacing.s8,
                runSpacing: FiloSpacing.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FiloIcon(
                    FiloIcons.attachment,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    '${post.attachments.length} ${post.attachments.length == 1 ? 'attachment' : 'attachments'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (post.points != null)
                    Text(
                      '${post.points} points',
                      style: FiloTypography.strongLabel(context),
                    ),
                ],
              ),
              if (post.assignment) ...[
                const SizedBox(height: FiloSpacing.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FiloIcon(FiloIcons.clock, size: 18),
                    const SizedBox(width: FiloSpacing.s8),
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
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FiloRadii.large),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(FiloSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: FiloThemeTokens.of(context).mint,
                    ),
                    const SizedBox(width: FiloSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line(context, .55),
                          const SizedBox(height: FiloSpacing.s8),
                          _line(context, .4, height: 12),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48, height: 48),
                  ],
                ),
                const SizedBox(height: FiloSpacing.s12),
                _line(context, .8, height: 20),
                const SizedBox(height: FiloSpacing.s8),
                _line(context, 1),
                const SizedBox(height: FiloSpacing.s8),
                _line(context, .65),
                const SizedBox(height: FiloSpacing.s12),
                const Divider(height: 1),
                const SizedBox(height: FiloSpacing.s12),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      color: FiloThemeTokens.of(context).mint,
                    ),
                    const SizedBox(width: FiloSpacing.s8),
                    Expanded(child: _line(context, .35, height: 14)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _line(
    BuildContext context,
    double widthFactor, {
    double height = 16,
  }) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: FiloThemeTokens.of(context).mint,
        borderRadius: BorderRadius.circular(FiloRadii.small),
      ),
    ),
  );
}
