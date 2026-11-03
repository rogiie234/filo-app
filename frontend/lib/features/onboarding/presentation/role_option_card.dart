import 'package:flutter/material.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/widgets/filo_motion_widgets.dart';
import '../../../core/theme/animation_constants.dart';
import '../data/profile_repository.dart';

class RoleOptionCard extends StatefulWidget {
  const RoleOptionCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onPressed,
  });
  final AccountRole role;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<RoleOptionCard> createState() => _RoleOptionCardState();
}

class _RoleOptionCardState extends State<RoleOptionCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final selected = widget.selected;
    final onPressed = widget.onPressed;
    final description = role == AccountRole.student
        ? 'Join classes, submit work, and view your grades.'
        : 'Create classes, post activities, and manage assessments.';
    return FiloMotionTween(
      value: _pressed ? .98 : 1,
      duration: FiloAnimation.cardDuration,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: FiloAnimation.roleCardEdge),
          child: Semantics(
            label: '${role.label}. $description',
            checked: selected,
            inMutuallyExclusiveGroup: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                onHighlightChanged: (pressed) {
                  if (_pressed != pressed) setState(() => _pressed = pressed);
                },
                borderRadius: BorderRadius.circular(24),
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.surface
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: FiloIcon(
                            role == AccountRole.student
                                ? FiloIcons.student
                                : FiloIcons.book,
                            color: Theme.of(context).colorScheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role.label,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FiloSelectionIndicator(selected: selected),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
