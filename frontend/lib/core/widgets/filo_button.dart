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
    this.iconOnly = false,
    this.leading,
    this.animateArrow = false,
    this.animateLabelSize = false,
    this.labelDuration = FiloAnimation.labelDuration,
    this.labelSizeCurve = Curves.easeInOutCubic,
    this.labelInCurve = FiloAnimation.labelInCurve,
    this.busy = false,
    this.showBusyIndicator = true,
    this.minHeight = FiloControlSize.primary,
    this.labelVariants = const [],
  }) : assert(!iconOnly || icon != null);
  final bool idlePulse;
  final bool secondary;
  final bool destructive;
  final bool outlined;
  final bool text;
  final IconData? icon;
  final bool iconOnly;
  final Widget? leading;
  final bool animateArrow;

  /// Slide the trailing icon as a changing label grows or shrinks.
  final bool animateLabelSize;
  final Duration labelDuration;
  final Curve labelSizeCurve;
  final Curve labelInCurve;
  final bool busy;

  /// Keep label/leading feedback visible while still blocking busy actions.
  final bool showBusyIndicator;
  final double minHeight;

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
        ? (flat ? tokens.destructive : tokens.onDestructive)
        : flat
        ? colors.primary
        : widget.secondary
        ? colors.onSurface
        : colors.onPrimary;
    final fill = flat
        ? FiloPaint.transparent
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
        // Bypass AnimatedSize when disabled: zero-duration resizing can mutate layout.
        final labelContent = AnimatedSwitcher(
          key: ValueKey(reduced),
          switchInCurve: widget.labelInCurve,
          switchOutCurve: FiloAnimation.labelOutCurve,
          duration: reduced ? Duration.zero : widget.labelDuration,
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
                if (widget.animateLabelSize)
                  Positioned(top: 0, child: ExcludeSemantics(child: child))
                else
                  ExcludeSemantics(child: child),
              ?current,
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
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    FiloAnimation.labelRise * (1 - animation.value),
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
        );
        final button = DecoratedBox(
          decoration: BoxDecoration(
            color: disabled || flat
                ? FiloPaint.transparent
                : widget.destructive
                ? tokens.destructiveEdge
                : widget.secondary
                ? tokens.mint
                : tokens.primaryEdge,
            borderRadius: BorderRadius.circular(FiloRadii.pill),
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
                          ? BorderSide(
                              color: widget.destructive
                                  ? tokens.destructive
                                  : tokens.controlBorder,
                              width: 1.5,
                            )
                          : null,
                      minimumSize: Size(
                        double.infinity,
                        flat
                            ? FiloControlSize.compact
                            : widget.minHeight - edge,
                      ),
                      padding: widget.iconOnly
                          ? EdgeInsets.zero
                          : EdgeInsets.symmetric(
                              horizontal: FiloSpacing.s20,
                              vertical: flat
                                  ? FiloSpacing.s12
                                  : FiloSpacing.s16,
                            ),
                      shape: widget.iconOnly
                          ? const CircleBorder()
                          : const StadiumBorder(),
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
                            : FiloPaint.transparent,
                      ),
                    ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.busy)
                      Semantics(
                        label: widget.label,
                        liveRegion: true,
                        child: widget.showBusyIndicator
                            ? SizedBox.square(
                                dimension: 20,
                                child: FiloCircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: foreground,
                                ),
                              )
                            : const SizedBox(
                                height: 20,
                                width: double.infinity,
                              ),
                      ),
                    ExcludeSemantics(
                      excluding: widget.busy,
                      child: Opacity(
                        opacity: widget.busy && widget.showBusyIndicator
                            ? 0
                            : 1,
                        child: widget.iconOnly
                            ? Tooltip(
                                message: widget.label,
                                child: Semantics(
                                  label: widget.label,
                                  child: ExcludeSemantics(
                                    child: FiloIcon(widget.icon!, size: 32),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (widget.leading != null) ...[
                                    widget.leading!,
                                    const SizedBox(width: FiloSpacing.s12),
                                  ],
                                  Flexible(
                                    child:
                                        reduced ||
                                            !widget.animateLabelSize ||
                                            widget.labelDuration ==
                                                Duration.zero
                                        ? labelContent
                                        : AnimatedSize(
                                            duration: widget.labelDuration,
                                            curve: widget.labelSizeCurve,
                                            child: labelContent,
                                          ),
                                  ),
                                  if (widget.icon != null) ...[
                                    const SizedBox(width: FiloSpacing.s12),
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
