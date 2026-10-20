import 'package:flutter/material.dart';

import '../theme/animation_constants.dart';
import '../theme/app_theme.dart';
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
  backgroundColor: FiloColors.background,
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  constraints: const BoxConstraints(maxWidth: 560),
  // Animate the native route once; content has no per-row entrance controllers.
  sheetAnimationStyle: !animate || MediaQuery.disableAnimationsOf(context)
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
          .removeViewInsets(removeBottom: true)
          .removePadding(removeBottom: true),
      child: Theme(
        data: Theme.of(sheetContext).copyWith(
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            minTileHeight: 56,
            iconColor: FiloColors.primary,
            textColor: FiloColors.ink,
            titleTextStyle: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FiloColors.ink,
            ),
            subtitleTextStyle: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              height: 1.4,
              color: FiloColors.secondary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
        child: Builder(builder: builder),
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
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showDragHandle) const _FiloSheetHandle(),
                      Positioned(
                        right: 12,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const FiloIcon(FiloIcons.close),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (showDragHandle)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: _FiloSheetHandle(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              color: FiloColors.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const FiloIcon(FiloIcons.close),
                      ),
                    ],
                  ),
                ),
              ],
              Flexible(
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
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
        color: FiloColors.border,
        borderRadius: BorderRadius.circular(2),
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
        ? FiloColors.secondary
        : destructive
        ? FiloColors.error
        : FiloColors.primary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: FiloColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FiloColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FiloColors.tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FiloIcon(icon, color: ink),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: FiloColors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
