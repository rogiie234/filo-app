import 'package:flutter/material.dart';

import '../theme/animation_constants.dart';
import '../theme/app_theme.dart';
import '../theme/filo_motion.dart';
import 'filo_icon.dart';

/// Shared modal shell. Builders supply shrink-wrapped content and retain their
/// own Navigator results, state, permission checks and confirmation behavior.
/// Set scrollBody=false for a bounded, lazy ListView supplied by the builder.
/// Pass title=null when content supplies its own heading; Close/handle remain.
Future<T?> showFiloBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title = 'Options',
  bool showDragHandle = true,
  bool isScrollControlled = true,
  bool animate = true,
  bool scrollBody = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: Theme.of(context).colorScheme.surface,
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(FiloRadii.large)),
  ),
  constraints: const BoxConstraints(maxWidth: 560),
  // Animate the native route once; content has no per-row entrance controllers.
  sheetAnimationStyle: !animate || !FiloMotion.enabled(context)
      ? AnimationStyle.noAnimation
      : AnimationStyle(
          duration: FiloAnimation.sheetDuration,
          reverseDuration: FiloAnimation.sheetReverseDuration,
        ),
  builder: (sheetContext) {
    final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
    final padding = MediaQuery.viewPaddingOf(sheetContext);
    final available =
        (MediaQuery.sizeOf(sheetContext).height -
                keyboard -
                padding.top -
                padding.bottom)
            .clamp(0.0, double.infinity)
            .toDouble();
    final content = MediaQuery(
      data: MediaQuery.of(sheetContext)
          .copyWith(disableAnimations: !animate || !FiloMotion.enabled(context))
          .removeViewInsets(removeBottom: true)
          .removePadding(removeBottom: true),
      child: Theme(
        data: Theme.of(sheetContext).copyWith(
          listTileTheme: ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(
              horizontal: FiloSpacing.screen,
              vertical: FiloSpacing.s4,
            ),
            minTileHeight: FiloControlSize.primary,
            iconColor: Theme.of(context).colorScheme.primary,
            textColor: Theme.of(context).colorScheme.onSurface,
            titleTextStyle: Theme.of(context).textTheme.labelLarge!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
            subtitleTextStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(FiloRadii.medium)),
            ),
          ),
        ),
        child: FiloMotionScope(
          enabled: animate && FiloMotion.enabled(context),
          child: Builder(builder: builder),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: available * .9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title == null)
                SizedBox(
                  height: FiloControlSize.compact,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showDragHandle) const _FiloSheetHandle(),
                      Positioned(
                        right: 12,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () =>
                              Navigator.of(sheetContext).maybePop(),
                          icon: const FiloIcon(FiloIcons.close),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (showDragHandle)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: FiloSpacing.s12),
                    child: _FiloSheetHandle(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FiloSpacing.screen,
                    0,
                    FiloSpacing.s12,
                    FiloSpacing.s12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: FiloSpacing.s8),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).maybePop(),
                        icon: const FiloIcon(FiloIcons.close),
                      ),
                    ],
                  ),
                ),
              ],
              Flexible(
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: FiloSpacing.screen),
                    // Long lists opt out of the outer scroller to stay lazy.
                    child: scrollBody
                        ? SingleChildScrollView(child: content)
                        : content,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

class _FiloSheetHandle extends StatelessWidget {
  const _FiloSheetHandle();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(FiloRadii.small),
      ),
    ),
  );
}

/// A reusable, accessible action card for selection menus and file actions.
class FiloSheetAction extends StatelessWidget {
  const FiloSheetAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.description,
    this.destructive = false,
  });
  final String label;
  final String? description;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ink = onTap == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FiloRadii.medium),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(FiloSpacing.s16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(FiloRadii.small),
                    ),
                    child: FiloIcon(icon, color: ink),
                  ),
                ),
                const SizedBox(width: FiloSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge!
                            .copyWith(color: ink),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: FiloSpacing.s4),
                        Text(
                          description!,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FiloSpacing.s8),
                ExcludeSemantics(
                  child: FiloIcon(FiloIcons.chevronRight, size: 18, color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
