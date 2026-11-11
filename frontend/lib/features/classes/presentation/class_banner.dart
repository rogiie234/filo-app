import '../../../core/theme/filo_banner_palette.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_icon.dart';
import '../domain/class_banner.dart';

/// Presentation only. Private Storage resolution remains with the caller.
class ClassBanner extends StatelessWidget {
  const ClassBanner({
    super.key,
    required this.section,
    this.course,
    required this.instructor,
    this.color = filoDefaultBanner,
    this.image,
    this.avatar,
    this.compact = false,
  });

  final String section, instructor;
  final String? course;
  final int color;
  final ImageProvider? image;
  final Widget? avatar;
  final bool compact;

  static const imageScrim = FiloPaint.bannerScrim;

  static Color foreground(
    int color, {
    Brightness brightness = Brightness.light,
  }) =>
      brightness == Brightness.light &&
          (color == classBannerColors['sage'] ||
              color == classBannerColors['olive'])
      ? FiloPaint.bannerInk
      : FiloPaint.white;

  static Color presetBackground(int color, Brightness brightness) => Color.lerp(
    Color(color),
    Colors.black,
    brightness == Brightness.dark ? .65 : 0,
  )!;

  static Color landscapeTint(
    int color, {
    Brightness brightness = Brightness.light,
  }) => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: .22)
      : foreground(color) == FiloPaint.white
      ? Colors.black.withValues(alpha: .3)
      : FiloPaint.bannerInk.withValues(alpha: .24);

  @override
  Widget build(BuildContext context) {
    final preset = classBannerColors.containsValue(color)
        ? color
        : classBannerColor(null);
    final brightness = Theme.of(context).brightness;
    final background = image == null ? preset : classBannerColor(null);
    final ink = image == null
        ? foreground(preset, brightness: brightness)
        : FiloPaint.white;
    final fallback = ColoredBox(
      color: presetBackground(background, brightness),
      child: Image.asset(
        'assets/illustrations/class-banner-landscape.png',
        fit: BoxFit.cover,
        alignment: Alignment.bottomRight,
        color: landscapeTint(background, brightness: brightness),
        colorBlendMode: BlendMode.srcIn,
        cacheWidth: (520 * MediaQuery.devicePixelRatioOf(context)).ceil(),
        excludeFromSemantics: true,
        errorBuilder: (_, error, stack) => const SizedBox.expand(),
      ),
    );
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: image == null
                  ? fallback
                  : Image(
                      image: image!,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      frameBuilder: (_, child, frame, synchronous) =>
                          synchronous || frame != null ? child : fallback,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null) ...[
                SizedBox(height: compact ? 16 : 48),
                const SizedBox(
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [FiloPaint.transparent, imageScrim],
                      ),
                    ),
                  ),
                ),
              ],
              DecoratedBox(
                decoration: BoxDecoration(
                  // The protected region grows with text, including at 130%.
                  gradient: image == null
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [imageScrim, FiloPaint.bannerScrimEnd],
                        ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    compact ? FiloSpacing.s16 : FiloSpacing.screen,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              course ?? section,
                              style: Theme.of(context).textTheme.headlineMedium!
                                  .copyWith(color: ink),
                            ),
                          ),
                          const SizedBox(width: FiloSpacing.s16),
                          ExcludeSemantics(
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: FiloIcon(
                                Icons.eco_outlined,
                                size: 25,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (course != null) ...[
                        const SizedBox(height: FiloSpacing.s8),
                        Text(
                          section,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: ink),
                        ),
                      ],
                      SizedBox(
                        height: compact ? FiloSpacing.s8 : FiloSpacing.s20,
                      ),
                      Row(
                        children: [
                          if (avatar != null) ...[
                            ClipOval(child: avatar!),
                            const SizedBox(width: FiloSpacing.s12),
                          ],
                          Expanded(
                            child: Text(
                              instructor,
                              style: Theme.of(context).textTheme.labelMedium!
                                  .copyWith(color: ink),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
