import 'filo_motion_widgets.dart';
import '../theme/animation_constants.dart';
import '../theme/filo_motion.dart';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_icon.dart';

enum FiloStatus {
  neutral,
  assigned,
  success,
  warning,
  error,
  missing,
  info,
  ai,
}

enum FiloStatusPreset {
  assigned('Assigned', FiloIcons.assessment, FiloStatus.assigned),
  turnedIn('Turned in', FiloIcons.check, FiloStatus.success),
  graded('Graded', FiloIcons.checkCircle, FiloStatus.success),
  late('Late', FiloIcons.clock, FiloStatus.error),
  missing('Missing', FiloIcons.error, FiloStatus.missing),
  inProgress('In progress', FiloIcons.clock, FiloStatus.warning),
  notStarted('Not started', FiloIcons.circle, FiloStatus.neutral),
  draft('Draft', FiloIcons.edit, FiloStatus.neutral),
  waitingForApproval(
    'Waiting for approval',
    FiloIcons.pending,
    FiloStatus.warning,
  ),
  availableOffline(
    'Available offline',
    FiloIcons.checkCircle,
    FiloStatus.success,
  ),
  cloudOnly('Cloud only', FiloIcons.cloud, FiloStatus.neutral),
  ai('AI', FiloIcons.sparkle, FiloStatus.ai);

  const FiloStatusPreset(this.label, this.icon, this.tone);
  final String label;
  final IconData icon;
  final FiloStatus tone;
}

class FiloStatusChip extends StatelessWidget {
  const FiloStatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.status = FiloStatus.neutral,
    this.fontWeight,
  });
  factory FiloStatusChip.preset(
    FiloStatusPreset preset, {
    Key? key,
    String? label,
  }) => FiloStatusChip(
    key: key,
    label: label ?? preset.label,
    icon: preset.icon,
    status: preset.tone,
    fontWeight: preset == FiloStatusPreset.graded
        ? FiloTypography.emphasis
        : null,
  );
  final String label;
  final IconData icon;
  final FiloStatus status;
  final FontWeight? fontWeight;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = FiloThemeTokens.of(context);
    final (ink, fill) = switch (status) {
      FiloStatus.success => (t.success, t.successTint),
      FiloStatus.warning => (t.warning, t.warningTint),
      FiloStatus.error => (c.error, c.errorContainer),
      FiloStatus.missing => (c.error, c.surface),
      FiloStatus.info => (t.info, t.infoTint),
      FiloStatus.ai => (t.onLime, t.lime),
      FiloStatus.assigned => (c.onPrimaryContainer, c.primaryContainer),
      FiloStatus.neutral => (c.onSurfaceVariant, c.surface),
    };
    final textStyle =
        (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
          color: ink,
          fontWeight: fontWeight,
        );
    return Chip(
      // Chip otherwise forces one line and fades long status qualifiers.
      label: DefaultTextStyle(
        style: textStyle,
        softWrap: true,
        overflow: TextOverflow.visible,
        child: Text(label),
      ),
      avatar: ExcludeSemantics(child: FiloIcon(icon, size: 18, color: ink)),
      backgroundColor: fill,
      labelStyle: textStyle,
      side: BorderSide(
        color: status == FiloStatus.ai
            ? t.limeDeep
            : status == FiloStatus.missing
            ? c.error
            : c.outline,
      ),
    );
  }
}

class FiloAiBadge extends StatelessWidget {
  const FiloAiBadge({super.key, this.semanticLabel});
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final badge = FiloStatusChip.preset(FiloStatusPreset.ai);
    return semanticLabel == null
        ? badge
        : Semantics(label: semanticLabel, excludeSemantics: true, child: badge);
  }
}

class FiloFilterChip extends StatelessWidget {
  const FiloFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
    avatar: SizedBox.square(
      dimension: 18,
      child: ExcludeSemantics(
        child: FiloMotionTween(
          value: selected ? 1 : 0,
          duration: FiloAnimation.chipDuration,
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.scale(scale: value, child: child),
          ),
          child: Icon(
            FiloIcons.check,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ),
    chipAnimationStyle: ChipAnimationStyle(
      selectAnimation: AnimationStyle.noAnimation,
      enableAnimation: AnimationStyle.noAnimation,
      avatarDrawerAnimation: AnimationStyle.noAnimation,
      deleteDrawerAnimation: AnimationStyle.noAnimation,
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: onSelected == null
          ? FiloThemeTokens.of(context).disabledInk
          : selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurface,
    ),
  );
}

/// Presentation only; feature screens supply content and permission-gated actions.
class FiloCard extends StatelessWidget {
  const FiloCard({
    super.key,
    required this.child,
    this.onTap,
    this.tinted = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool tinted;
  @override
  Widget build(BuildContext context) => FiloCardTap(
    enabled: onTap != null,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: Theme.of(context).colorScheme.onSurface
          .withValues(alpha: .08),
      color: tinted
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FiloRadii.large),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(FiloSpacing.s20),
          child: child,
        ),
      ),
    ),
  );
}

enum FiloToastKind { info, success, error }

VoidCallback? _dismissSheetToast;

void showFiloToast(
  BuildContext context,
  String message, {
  FiloToastKind kind = FiloToastKind.info,
}) {
  _dismissSheetToast?.call();
  final duration = Duration(seconds: kind == FiloToastKind.error ? 4 : 3);
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final content = Row(
    children: [
      FiloIcon(
        switch (kind) {
          FiloToastKind.success => FiloIcons.checkCircle,
          FiloToastKind.error => FiloIcons.error,
          FiloToastKind.info => FiloIcons.info,
        },
        color: colors.onInverseSurface,
        size: 20,
      ),
      const SizedBox(width: FiloSpacing.s12),
      Expanded(child: Text(message)),
    ],
  );
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  if (ModalRoute.of(context) is ModalBottomSheetRoute) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    var dismissed = false;
    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      entry.remove();
      entry.dispose();
      if (identical(_dismissSheetToast, dismiss)) _dismissSheetToast = null;
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        return Positioned(
          left: media.padding.left + FiloSpacing.s16,
          right: media.padding.right + FiloSpacing.s16,
          bottom:
              media.viewInsets.bottom + media.padding.bottom + FiloSpacing.s16,
          child: IgnorePointer(
            child: Theme(
              data: theme,
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: colors.inverseSurface,
                  borderRadius: BorderRadius.circular(FiloRadii.medium),
                  child: Padding(
                    padding: const EdgeInsets.all(FiloSpacing.s16),
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: colors.onInverseSurface,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    _dismissSheetToast = dismiss;
    Future<void>.delayed(duration, dismiss);
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      margin: const EdgeInsets.all(FiloSpacing.s16),
      content: content,
    ),
    snackBarAnimationStyle: FiloMotion.enabled(context)
        ? null
        : AnimationStyle.noAnimation,
  );
}

class FiloProgressBar extends StatelessWidget {
  const FiloProgressBar({super.key, required this.value, required this.label});
  final double value;
  final String label;
  @override
  Widget build(BuildContext context) => FiloLinearProgressIndicator(
    value: value.clamp(0.0, 1.0).toDouble(),
    minHeight: 10,
    borderRadius: BorderRadius.circular(FiloRadii.small),
    backgroundColor: FiloThemeTokens.of(context).mint,
    color: Theme.of(context).colorScheme.primary,
    semanticsLabel: label,
    semanticsValue: '${(value.clamp(0.0, 1.0) * 100).round()}%',
  );
}

class FiloPageIndicator extends StatelessWidget {
  const FiloPageIndicator({super.key, required this.count, required this.index})
    : assert(count > 0),
      assert(index >= 0 && index < count);
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Page ${index + 1} of $count',
    child: ExcludeSemantics(
      child: Wrap(
        spacing: 8,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: i == index ? 36 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FiloRadii.small),
                color: i == index
                    ? Theme.of(context).colorScheme.primary
                    : FiloThemeTokens.of(context).mint,
              ),
            ),
        ],
      ),
    ),
  );
}

class FiloBanner extends StatelessWidget {
  const FiloBanner({
    super.key,
    this.message = "You're offline. Showing saved content.",
    this.icon = FiloIcons.offline,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FiloSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(FiloRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FiloIcon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: FiloSpacing.s12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: FiloSpacing.s8),
            action!,
          ],
        ],
      ),
    ),
  );
}

class FiloSkeleton extends StatefulWidget {
  const FiloSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20,
  });
  final double width;
  final double height;
  @override
  State<FiloSkeleton> createState() => _FiloSkeletonState();
}

class _FiloSkeletonState extends State<FiloSkeleton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_fade.isAnimating) _fade.repeat(reverse: true);
    } else {
      _fade.stop();
      _fade.value = 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: _fade.drive(Tween(begin: .5, end: 1.0)),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: FiloThemeTokens.of(context).mint,
              borderRadius: BorderRadius.circular(FiloRadii.small),
            ),
          ),
        ),
      ),
    ),
  );
}
