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

class FiloStatusChip extends StatelessWidget {
  const FiloStatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.status = FiloStatus.neutral,
  });
  final String label;
  final IconData icon;
  final FiloStatus status;
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
    return Chip(
      label: Text(label),
      avatar: FiloIcon(icon, size: 18, color: ink),
      backgroundColor: fill,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: ink),
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
    showCheckmark: true,
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
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 1,
    shadowColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
    color: tinted
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );
}

enum FiloToastKind { info, success, error }

void showFiloToast(
  BuildContext context,
  String message, {
  FiloToastKind kind = FiloToastKind.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: Duration(seconds: kind == FiloToastKind.error ? 4 : 3),
      margin: const EdgeInsets.all(16),
      content: Row(
        children: [
          FiloIcon(
            switch (kind) {
              FiloToastKind.success => FiloIcons.checkCircle,
              FiloToastKind.error => FiloIcons.error,
              FiloToastKind.info => FiloIcons.info,
            },
            color: Theme.of(context).colorScheme.onInverseSurface,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class FiloProgressBar extends StatelessWidget {
  const FiloProgressBar({super.key, required this.value, required this.label});
  final double value;
  final String label;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    builder: (context, progress, _) => LinearProgressIndicator(
      value: progress,
      minHeight: 10,
      borderRadius: BorderRadius.circular(5),
      backgroundColor: FiloThemeTokens.of(context).mint,
      color: Theme.of(context).colorScheme.primary,
      semanticsLabel: label,
      semanticsValue: '${(progress * 100).round()}%',
    ),
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
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: i == index ? 36 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 12),
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
          if (action != null) ...[const SizedBox(height: 8), action!],
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
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ),
  );
}
