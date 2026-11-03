import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

/// Read-only task summary. Only opening the assignment is interactive.
class TodoTaskCard extends StatelessWidget {
  const TodoTaskCard({
    super.key,
    required this.title,
    required this.classLabel,
    required this.dueLabel,
    required this.status,
    required this.onTap,
    this.points,
  });
  final String title, classLabel, dueLabel, status;
  final int? points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final late = status == 'Late';
    final missing = status == 'Missing';
    final statusInk = missing
        ? Theme.of(context).colorScheme.error
        : late
        ? FiloThemeTokens.of(context).warning
        : Theme.of(context).colorScheme.primary;
    final statusIcon = switch (status) {
      'Assigned' => FiloIcons.assessment,
      'Draft' => FiloIcons.edit,
      'Late' => FiloIcons.clock,
      'Missing' => FiloIcons.info,
      _ => FiloIcons.checkCircle,
    };
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FiloIcon(
                        FiloIcons.assessment,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          classLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: FiloIcon(
                      FiloIcons.chevronRight,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: late
                          ? FiloThemeTokens.of(context).warningTint
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: missing
                          ? Border.all(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: FiloIcon(
                            statusIcon,
                            size: 16,
                            color: statusInk,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: statusInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (points != null)
                    Text(
                      '$points points',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: FiloIcon(
                      FiloIcons.calendar,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dueLabel,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodoEmptyState extends StatelessWidget {
  const TodoEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.mascotPose = 'clock',
    this.bob = true,
  });
  final String title, message, mascotPose;
  final bool bob;
  @override
  Widget build(BuildContext context) =>
      EmptyState(title: title, message: message, pose: mascotPose, bob: bob);
}

/// Static placeholders avoid suggesting progress or animating a long list.
class TodoTaskSkeleton extends StatelessWidget {
  const TodoTaskSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading assignments',
    child: ExcludeSemantics(
      child: FiloPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final width in [1.0, .6, .8])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FractionallySizedBox(
                  widthFactor: width,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: FiloThemeTokens.of(context).mint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
