import 'package:flutter/material.dart';

import 'filo_icon.dart';
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
    this.icon,
    this.leading,
    this.animateArrow = false,
    this.busy = false,
    this.labelVariants = const [],
  });
  final bool idlePulse;
  final bool secondary;
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
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Busy is a temporary guard: preserve its active palette while unavailable
    // actions use a distinct, reusable disabled design.
    final disabled = widget.onPressed == null && !widget.busy;
    final foreground = disabled
        ? FiloColors.disabledButtonInk
        : widget.secondary
        ? FiloAnimation.secondaryLabel
        : FiloAnimation.primaryLabel;
    final fill = disabled
        ? FiloColors.disabledButtonFill
        : widget.secondary
        ? FiloColors.surface
        : FiloColors.primary;
    return ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      builder: (context, states, _) {
        final pressed =
            states.contains(WidgetState.pressed) && !disabled && !widget.busy;
        final button = AnimatedScale(
          scale: pressed ? FiloAnimation.pressScale : 1,
          duration: reduced ? Duration.zero : FiloAnimation.pressDuration,
          curve: FiloAnimation.uiCurve,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : FiloAnimation.pressDuration,
            curve: FiloAnimation.uiCurve,
            decoration: BoxDecoration(
              color: disabled
                  ? FiloColors.disabledButtonFill
                  : widget.secondary
                  ? FiloColors.mint
                  : FiloColors.edge,
              borderRadius: BorderRadius.circular(32),
              boxShadow: disabled
                  ? const []
                  : [
                      BoxShadow(
                        color: FiloAnimation.shadowColor,
                        blurRadius: pressed
                            ? FiloAnimation.pressedShadowBlur
                            : FiloAnimation.shadowBlur,
                        offset: pressed
                            ? FiloAnimation.pressedShadowOffset
                            : FiloAnimation.shadowOffset,
                      ),
                    ],
            ),
            child: AnimatedPadding(
              duration: reduced ? Duration.zero : FiloAnimation.pressDuration,
              curve: FiloAnimation.uiCurve,
              padding: EdgeInsets.only(
                top: pressed ? FiloAnimation.pressDepth : 0,
                bottom: pressed
                    ? FiloAnimation.pressedEdgeDepth
                    : FiloAnimation.buttonEdgeDepth,
              ),
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
                      side: disabled
                          ? const BorderSide(
                              color: FiloColors.disabledButtonBorder,
                            )
                          : widget.secondary
                          ? const BorderSide(color: FiloColors.border)
                          : null,
                      minimumSize: const Size(double.infinity, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ).copyWith(
                      foregroundColor: WidgetStatePropertyAll(foreground),
                      iconColor: WidgetStatePropertyAll(foreground),
                      overlayColor: const WidgetStatePropertyAll(
                        FiloAnimation.pressOverlay,
                      ),
                    ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: AnimatedSize(
                        duration: reduced
                            ? Duration.zero
                            : FiloAnimation.uiDuration,
                        curve: FiloAnimation.uiCurve,
                        child: AnimatedSwitcher(
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
                    ),
                    if (widget.icon != null) ...[
                      const SizedBox(width: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: pressed && widget.animateArrow
                              ? FiloAnimation.arrowNudge
                              : 0,
                        ),
                        duration: reduced
                            ? Duration.zero
                            : FiloAnimation.pressDuration,
                        curve: FiloAnimation.uiCurve,
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
