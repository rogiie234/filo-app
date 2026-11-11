import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feedback/filo_haptics.dart';
import '../theme/animation_constants.dart';
import '../theme/filo_motion.dart';
import 'filo_icon.dart';
import 'filo_widgets.dart' show Mascot;

/// Unlike an implicit tween, a preference change snaps even with the same target.
class FiloMotionTween extends StatefulWidget {
  const FiloMotionTween({
    super.key,
    required this.value,
    required this.duration,
    required this.builder,
    this.initialValue,
    this.child,
  });
  final double value;
  final double? initialValue;
  final Duration duration;
  final Widget Function(BuildContext, double, Widget?) builder;
  final Widget? child;
  @override
  State<FiloMotionTween> createState() => _FiloMotionTweenState();
}

class _FiloMotionTweenState extends State<FiloMotionTween>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late double _from = widget.initialValue ?? widget.value, _to = widget.value;
  bool _started = false;
  double get _value =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_controller.value);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!FiloMotion.enabled(context)) {
      _controller.value = 1;
    } else if (!_started && _from != _to) {
      _controller.forward(from: 0);
    }
    _started = true;
  }

  @override
  void didUpdateWidget(FiloMotionTween oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.duration == Duration.zero) _controller.value = 1;
    if (oldWidget.value != widget.value) {
      _from = _value;
      _to = widget.value;
      if (FiloMotion.enabled(context) && widget.duration != Duration.zero) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _value, child),
  );
}

class FiloCardTap extends StatefulWidget {
  const FiloCardTap({super.key, required this.child, required this.enabled});
  final Widget child;
  final bool enabled;
  @override
  State<FiloCardTap> createState() => _FiloCardTapState();
}

class _FiloCardTapState extends State<FiloCardTap> {
  bool _pressed = false;
  Offset? _origin;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!FiloMotion.enabled(context)) _pressed = false;
  }

  @override
  void didUpdateWidget(FiloCardTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (event) => setState(() {
            _origin = event.position;
            _pressed = true;
          })
        : null,
    onPointerMove: (event) {
      if (_pressed &&
          _origin != null &&
          (event.position - _origin!).distance > 18) {
        setState(() => _pressed = false);
      }
    },
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: FiloMotionTween(
      value: _pressed && FiloMotion.enabled(context) ? .98 : 1,
      duration: widget.enabled ? FiloAnimation.cardDuration : Duration.zero,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: widget.child,
    ),
  );
}

class FiloSwitch extends StatelessWidget {
  const FiloSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Switch(
    key: FiloMotion.enabled(context) ? null : ValueKey(value),
    value: value,
    onChanged: onChanged == null
        ? null
        : (next) {
            if (next == value) return;
            FiloHaptics.selection(context);
            onChanged!(next);
          },
  );
}

class FiloSwitchListTile extends StatelessWidget {
  const FiloSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.contentPadding,
    this.secondary,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title, subtitle, secondary;
  final EdgeInsetsGeometry? contentPadding;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: FiloMotion.enabled(context) ? null : ValueKey(value),
    value: value,
    title: title,
    subtitle: subtitle,
    contentPadding: contentPadding,
    secondary: secondary,
    onChanged: onChanged == null
        ? null
        : (next) {
            if (next == value) return;
            FiloHaptics.selection(context);
            onChanged!(next);
          },
  );
}

/// A stable check slot avoids Material's width/color/shape interpolation.
class FiloAnimatedChip extends StatelessWidget {
  const FiloAnimatedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    this.tooltip,
    this.showCheckmark = true,
    this.materialTapTargetSize,
    this.selectedColor,
    this.backgroundColor,
    this.labelStyle,
    this.side,
    this.padding,
  }) : filter = false;
  const FiloAnimatedChip.filter({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
    this.tooltip,
    this.showCheckmark = true,
    this.materialTapTargetSize,
    this.selectedColor,
    this.backgroundColor,
    this.labelStyle,
    this.side,
    this.padding,
  }) : filter = true;
  final Widget label;
  final Widget? avatar;
  final String? tooltip;
  final bool selected, showCheckmark, filter;
  final ValueChanged<bool>? onSelected;
  final MaterialTapTargetSize? materialTapTargetSize;
  final Color? selectedColor, backgroundColor;
  final TextStyle? labelStyle;
  final BorderSide? side;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final check = showCheckmark && selected
        ? ExcludeSemantics(
            child: SizedBox.square(
              dimension: 18,
              child: FiloMotionTween(
                initialValue: 0,
                value: 1,
                duration: FiloAnimation.chipDuration,
                builder: (_, value, child) => Opacity(
                  opacity: value,
                  child: Transform.scale(scale: value, child: child),
                ),
                child: Icon(
                  FiloIcons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          )
        : null;
    final icon = avatar == null
        ? check
        : Stack(alignment: Alignment.center, children: [avatar!, ?check]);
    final style = ChipAnimationStyle(
      selectAnimation: AnimationStyle.noAnimation,
      enableAnimation: AnimationStyle.noAnimation,
      avatarDrawerAnimation: AnimationStyle.noAnimation,
      deleteDrawerAnimation: AnimationStyle.noAnimation,
    );
    if (filter) {
      return FilterChip(
        label: label,
        selected: selected,
        onSelected: onSelected,
        avatar: icon,
        tooltip: tooltip,
        showCheckmark: false,
        chipAnimationStyle: style,
        materialTapTargetSize: materialTapTargetSize,
        selectedColor: selectedColor,
        backgroundColor: backgroundColor,
        labelStyle: labelStyle,
        side: side,
        padding: padding,
      );
    }
    return ChoiceChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      avatar: icon,
      tooltip: tooltip,
      showCheckmark: false,
      chipAnimationStyle: style,
      materialTapTargetSize: materialTapTargetSize,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      labelStyle: labelStyle,
      side: side,
      padding: padding,
    );
  }
}

class FiloRadio<T> extends StatelessWidget {
  const FiloRadio({
    super.key,
    required this.value,
    this.groupValue,
    this.onChanged,
  });
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  @override
  Widget build(BuildContext context) => Radio<T>(
    key: FiloMotion.enabled(context)
        ? null
        : ValueKey(groupValue ?? RadioGroup.maybeOf<T>(context)?.groupValue),
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
  );
}

class FiloRadioListTile<T> extends StatelessWidget {
  const FiloRadioListTile({
    super.key,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.title,
    this.contentPadding,
  });
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget? title;
  final EdgeInsetsGeometry? contentPadding;
  @override
  Widget build(BuildContext context) => RadioListTile<T>(
    key: FiloMotion.enabled(context)
        ? null
        : ValueKey(groupValue ?? RadioGroup.maybeOf<T>(context)?.groupValue),
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
    title: title,
    contentPadding: contentPadding,
  );
}

/// Functional progress keeps truthful values; indeterminate activity is static
/// when motion is disabled, rather than inventing a completion percentage.
class FiloCircularProgressIndicator extends StatelessWidget {
  const FiloCircularProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.strokeWidth = 4,
    this.semanticsLabel,
    this.semanticsValue,
  });
  final double? value;
  final Color? color;
  final double strokeWidth;
  final String? semanticsLabel, semanticsValue;
  @override
  Widget build(BuildContext context) {
    final motion = FiloMotion.enabled(context);
    return TickerMode(
      enabled: motion,
      child: CircularProgressIndicator(
        key: motion ? null : ValueKey(value),
        value: value,
        color: color,
        strokeWidth: strokeWidth,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      ),
    );
  }
}

class FiloLinearProgressIndicator extends StatelessWidget {
  const FiloLinearProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.minHeight,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  });
  final double? value, minHeight;
  final Color? color, backgroundColor;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticsLabel, semanticsValue;
  @override
  Widget build(BuildContext context) {
    final motion = FiloMotion.enabled(context);
    return TickerMode(
      enabled: motion,
      child: LinearProgressIndicator(
        key: motion ? null : ValueKey(value),
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        minHeight: minHeight,
        borderRadius: borderRadius,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      ),
    );
  }
}

class FiloSuccessMoment extends StatelessWidget {
  const FiloSuccessMoment({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: FiloMotionTween(
        initialValue: 0,
        value: 1,
        duration: FiloAnimation.successDuration,
        builder: (_, value, _) => SizedBox(
          width: 144,
          height: 144,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - value,
                child: const Mascot(pose: 'cheerful_note', size: 96),
              ),
              Opacity(
                opacity: value,
                child: const Mascot(pose: 'cheerful', size: 96),
              ),
              if (FiloMotion.enabled(context) && value < 1)
                for (var i = 0; i < 3; i++)
                  Align(
                    alignment: [
                      const Alignment(-.9, -.6),
                      const Alignment(.85, -.8),
                      const Alignment(.9, .5),
                    ][i],
                    child: Opacity(
                      opacity: math.sin(math.pi * value).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: .5 + value * .5,
                        child: Icon(
                          FiloIcons.sparkle,
                          size: 12.0 + i * 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FiloFirstListLoad extends StatefulWidget {
  const FiloFirstListLoad({
    super.key,
    required this.id,
    required this.ready,
    this.hasItems = true,
    required this.child,
  });
  final String id;
  final bool ready;
  final bool hasItems;
  final Widget child;
  @override
  State<FiloFirstListLoad> createState() => _FiloFirstListLoadState();
}

class _FiloFirstListLoadState extends State<FiloFirstListLoad>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: FiloAnimation.listDuration,
    value: 1,
  );
  bool _consumed = false;
  void _settle() {
    if (!widget.ready || _consumed) return;
    final bucket = PageStorage.maybeOf(context);
    final id = (ModalRoute.of(context), widget.id);
    final seen = bucket?.readState(context, identifier: id) == true;
    _consumed = true;
    bucket?.writeState(context, true, identifier: id);
    if (!seen && widget.hasItems && FiloMotion.enabled(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!FiloMotion.enabled(context)) _controller.value = 1;
    _settle();
  }

  @override
  void didUpdateWidget(FiloFirstListLoad oldWidget) {
    super.didUpdateWidget(oldWidget);
    _settle();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ListMotion(animation: _controller, child: widget.child);
}

class _ListMotion extends InheritedWidget {
  const _ListMotion({required this.animation, required super.child});
  final Animation<double> animation;
  @override
  bool updateShouldNotify(_ListMotion oldWidget) =>
      oldWidget.animation != animation;
}

class FiloListItem extends StatelessWidget {
  const FiloListItem({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final animation = context
        .dependOnInheritedWidgetOfExactType<_ListMotion>()
        ?.animation;
    if (animation == null || index >= 6 || !FiloMotion.enabled(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final value = Curves.easeOutCubic.transform(
          ((animation.value * 400 - index * 40) / 200).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Avoid flashing loading feedback for local reads that finish immediately.
class FiloDelayedLoading extends StatefulWidget {
  const FiloDelayedLoading({super.key, required this.child});
  final Widget child;

  @override
  State<FiloDelayedLoading> createState() => _FiloDelayedLoadingState();
}

class _FiloDelayedLoadingState extends State<FiloDelayedLoading> {
  late final Timer _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SizedBox.shrink();
}
