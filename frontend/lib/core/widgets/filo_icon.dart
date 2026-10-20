import 'filo_icons.dart';

import 'package:flutter/material.dart';

import '../theme/animation_constants.dart';
import '../theme/app_theme.dart';

export 'filo_icons.dart';

/// One rendering policy for Filo's Phosphor icon family.
/// Inherit color/opacity from IconTheme so buttons preserve all state colors.
class FiloIcon extends StatelessWidget {
  const FiloIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
    this.animateChanges = false,
  });

  /// Opt in only for stateful status icons; static controls stay lightweight.
  final bool animateChanges;
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;

  static const controlSize = 24.0;
  static const smallSize = 18.0;
  static const featureSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final child = Icon(
      icon,
      key: ValueKey(icon),
      size: size ?? IconTheme.of(context).size ?? controlSize,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: textDirection,
    );
    if (reduced || !animateChanges) {
      return child;
    }
    return AnimatedSwitcher(
      duration: FiloAnimation.iconDuration,
      switchInCurve: FiloAnimation.uiCurve,
      switchOutCurve: FiloAnimation.uiCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final child in previous) ExcludeSemantics(child: child),
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: FiloAnimation.iconSwapScale,
            end: 1,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Selection feedback, not a shape morph: a check fades and scales into place.
/// The parent control supplies the accessible checked/selected state.
class FiloSelectionIndicator extends StatelessWidget {
  const FiloSelectionIndicator({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : FiloAnimation.iconDuration;
    return ExcludeSemantics(
      child: AnimatedContainer(
        width: FiloIcon.controlSize,
        height: FiloIcon.controlSize,
        duration: duration,
        curve: FiloAnimation.uiCurve,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? FiloColors.primary : Colors.transparent,
          border: Border.all(
            color: selected ? FiloColors.primary : FiloColors.secondary,
            width: 2,
          ),
        ),
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: duration,
          curve: FiloAnimation.uiCurve,
          child: AnimatedScale(
            scale: selected ? 1 : FiloAnimation.iconSelectionScale,
            duration: duration,
            curve: FiloAnimation.uiCurve,
            child: const FiloIcon(
              FiloIcons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// ExpansionTile with the same Phosphor disclosure as other Filo controls.
class FiloExpansionTile extends StatefulWidget {
  const FiloExpansionTile({
    super.key,
    required this.title,
    required this.children,
    this.tilePadding,
  });
  final Widget title;
  final List<Widget> children;
  final EdgeInsetsGeometry? tilePadding;

  @override
  State<FiloExpansionTile> createState() => _FiloExpansionTileState();
}

class _FiloExpansionTileState extends State<FiloExpansionTile> {
  final _controller = ExpansibleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : FiloAnimation.iconDuration;
    return ExpansionTile(
      controller: _controller,
      title: widget.title,
      tilePadding: widget.tilePadding,
      expansionAnimationStyle: AnimationStyle(
        duration: duration,
        reverseDuration: duration,
        curve: FiloAnimation.uiCurve,
        reverseCurve: FiloAnimation.uiCurve,
      ),
      trailing: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => AnimatedRotation(
            turns: _controller.isExpanded ? .5 : 0,
            duration: duration,
            curve: FiloAnimation.uiCurve,
            child: child,
          ),
          child: const FiloIcon(FiloIcons.chevronDown),
        ),
      ),
      children: widget.children,
    );
  }
}
