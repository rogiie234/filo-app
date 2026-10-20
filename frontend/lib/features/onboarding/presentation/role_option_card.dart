import 'package:flutter/material.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_theme.dart';
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
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : FiloAnimation.pressDuration;
    final description = role == AccountRole.student
        ? 'Join classes, submit work, and view your grades.'
        : 'Create classes, post activities, and manage assessments.';
    return AnimatedScale(
      scale: _pressed ? FiloAnimation.roleCardPressScale : 1,
      duration: duration,
      curve: FiloAnimation.uiCurve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? FiloColors.primary : FiloColors.border,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedPadding(
          duration: duration,
          curve: FiloAnimation.uiCurve,
          padding: EdgeInsets.only(
            top: _pressed ? 2 : 0,
            bottom: _pressed ? 1 : FiloAnimation.roleCardEdge,
          ),
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
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : FiloAnimation.pressDuration,
                    curve: FiloAnimation.uiCurve,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: selected
                          ? FiloColors.selected
                          : FiloColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? FiloColors.primary
                            : FiloColors.border,
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
                                ? FiloColors.surface
                                : FiloColors.tint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: FiloIcon(
                            role == AccountRole.student
                                ? FiloIcons.student
                                : FiloIcons.book,
                            color: FiloColors.primary,
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: FiloColors.ink,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: FiloColors.secondary,
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
