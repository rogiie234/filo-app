import 'package:flutter/material.dart';

import 'filo_icon.dart';
import 'filo_motion_widgets.dart';
import '../theme/filo_motion.dart';
import '../theme/app_theme.dart';
import '../theme/animation_constants.dart';

/// Reusable tactile action with stable label colors in every interaction state.
class FiloButton extends StatefulWidget {
  const FiloButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.idlePulse = false,
    this.secondary = false,
    this.destructive = false,
    this.outlined = false,
    this.text = false,
    this.icon,
    this.leading,
    this.animateArrow = false,
    this.busy = false,
    this.labelVariants = const [],
  });
  final bool idlePulse;
  final bool secondary;
  final bool destructive;
  final bool outlined;
  final bool text;
  final IconData? icon;
  final Widget? leading;
  final bool animateArrow;
  final bool busy;

  /// Reserve the largest label so text and trailing icon never jump sideways.
  final List<String> labelVariants;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<FiloButton> createState() => _FiloButtonState();
}

class _FiloButtonState extends State<FiloButton>
    with SingleTickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final _pulse = AnimationController(
    vsync: this,
    duration: FiloAnimation.idlePulseDuration,
  );
  @override
  void initState() {
    super.initState();
    _states.update(
      WidgetState.disabled,
      widget.busy || widget.onPressed == null,
    );
    _states.addListener(_syncPulse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant FiloButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seed child-owned states before FilledButton can notify our outer builders.
    final unavailable = widget.busy || widget.onPressed == null;
    _states.update(WidgetState.disabled, unavailable);
    if (unavailable) _states.update(WidgetState.pressed, false);
    _syncPulse();
  }

  void _syncPulse() {
    final enabled =
        widget.idlePulse &&
        widget.onPressed != null &&
        !widget.busy &&
        !_states.value.contains(WidgetState.pressed) &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _states.removeListener(_syncPulse);
    _pulse.dispose();
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = !FiloMotion.enabled(context);
    // Busy is a temporary guard: preserve its active palette while unavailable
    // actions use a distinct, reusable disabled design.
    final disabled = widget.onPressed == null && !widget.busy;
    final colors = Theme.of(context).colorScheme;
    final tokens = FiloThemeTokens.of(context);
    final flat = widget.outlined || widget.text;
    final edge = disabled || flat
        ? 0.0
        : widget.secondary
        ? 3.0
        : 4.0;
    final foreground = disabled
        ? tokens.disabledInk
        : widget.destructive
        ? tokens.onDestructive
        : flat
        ? colors.primary
        : widget.secondary
        ? colors.onSurface
        : colors.onPrimary;
    final fill = flat
        ? Colors.transparent
        : disabled
        ? tokens.disabledFill
        : widget.destructive
        ? tokens.destructive
        : widget.secondary
        ? colors.surface
        : colors.primary;
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, _) {
        final pressed =
            states.contains(WidgetState.pressed) && !disabled && !widget.busy;
        final button = DecoratedBox(
          decoration: BoxDecoration(
            color: disabled || flat
                ? Colors.transparent
                : widget.destructive
                ? tokens.destructiveEdge
                : widget.secondary
                ? tokens.mint
                : tokens.primaryEdge,
            borderRadius: BorderRadius.circular(32),
            boxShadow: disabled || flat
                ? const []
                : const [
                    BoxShadow(
                      color: FiloAnimation.shadowColor,
                      blurRadius: FiloAnimation.shadowBlur,
                      offset: FiloAnimation.shadowOffset,
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: edge),
            child: FiloMotionTween(
              value: pressed && !flat ? 3 : 0,
              duration: disabled || reduced
                  ? Duration.zero
                  : pressed
                  ? FiloAnimation.pressDuration
                  : FiloAnimation.releaseDuration,
              builder: (_, value, child) =>
                  Transform.translate(offset: Offset(0, value), child: child),
              child: FilledButton(
                statesController: _states,
                onPressed: widget.busy ? null : widget.onPressed,
                style:
                    FilledButton.styleFrom(
                      backgroundColor: fill,
                      foregroundColor: foreground,
                      disabledForegroundColor: foreground,
                      disabledBackgroundColor: fill,
                      overlayColor: FiloAnimation.pressOverlay,
                      splashFactory: NoSplash.splashFactory,
                      side: widget.text
                          ? BorderSide.none
                          : disabled
                          ? BorderSide(color: tokens.disabledBorder)
                          : widget.secondary || widget.outlined
                          ? BorderSide(color: colors.outline, width: 1.5)
                          : null,
                      minimumSize: Size(double.infinity, flat ? 48 : 56 - edge),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: flat ? 12 : 14,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ).copyWith(
                      animationDuration: Duration.zero,
                      foregroundColor: WidgetStatePropertyAll(foreground),
                      iconColor: WidgetStatePropertyAll(foreground),
                      overlayColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.focused) ||
                                (flat && states.contains(WidgetState.pressed))
                            ? colors.primary.withValues(alpha: .12)
                            : Colors.transparent,
                      ),
                    ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.busy)
                      Semantics(
                        label: widget.label,
                        liveRegion: true,
                        child: SizedBox.square(
                          dimension: 20,
                          child: FiloCircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                      ),
                    ExcludeSemantics(
                      excluding: widget.busy,
                      child: Opacity(
                        opacity: widget.busy ? 0 : 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.leading != null) ...[
                              widget.leading!,
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: AnimatedSwitcher(
                                key: ValueKey(reduced),
                                switchInCurve: FiloAnimation.labelInCurve,
                                switchOutCurve: FiloAnimation.labelOutCurve,
                                duration: reduced
                                    ? Duration.zero
                                    : FiloAnimation.labelDuration,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    for (final label in widget.labelVariants)
                                      ExcludeSemantics(
                                        child: Opacity(
                                          opacity: 0,
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: foreground),
                                          ),
                                        ),
                                      ),
                                    for (final child in previous)
                                      ExcludeSemantics(child: child),
                                    if (current != null) current,
                                  ],
                                ),
                                transitionBuilder: (child, animation) {
                                  if (reduced) {
                                    return child;
                                  }
                                  return FadeTransition(
                                    opacity: animation,
                                    child: AnimatedBuilder(
                                      animation: animation,
                                      child: child,
                                      builder: (context, child) =>
                                          Transform.translate(
                                            offset: Offset(
                                              0,
                                              FiloAnimation.labelRise *
                                                  (1 - animation.value),
                                            ),
                                            child: child,
                                          ),
                                    ),
                                  );
                                },
                                child: Text(
                                  widget.label,
                                  key: ValueKey(widget.label),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: foreground),
                                ),
                              ),
                            ),
                            if (widget.icon != null) ...[
                              const SizedBox(width: 12),
                              FiloMotionTween(
                                value: pressed && widget.animateArrow
                                    ? FiloAnimation.arrowNudge
                                    : 0,
                                duration: reduced
                                    ? Duration.zero
                                    : FiloAnimation.pressDuration,
                                builder: (context, offset, child) =>
                                    Transform.translate(
                                      offset: Offset(offset, 0),
                                      child: child,
                                    ),
                                child: FiloIcon(
                                  widget.icon,
                                  color: foreground,
                                  size: 20,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return AnimatedBuilder(
          animation: _pulse,
          child: button,
          builder: (context, child) => Transform.scale(
            scale:
                1 +
                (FiloAnimation.idlePulseScale - 1) *
                    FiloAnimation.ambientCurve.transform(_pulse.value),
            child: child,
          ),
        );
      },
    );
  }
}
