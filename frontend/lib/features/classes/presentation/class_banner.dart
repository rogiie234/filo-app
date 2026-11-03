import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_icon.dart';
import '../domain/class_banner.dart';

/// Presentation only. Private Storage resolution remains with the caller.
class ClassBanner extends StatelessWidget {
  const ClassBanner({
    super.key,
    required this.section,
    required this.instructor,
    this.color = 0xFF236B57,
    this.image,
    this.avatar,
  });

  final String section, instructor;
  final int color;
  final ImageProvider? image;
  final Widget? avatar;

  static const patternOpacity = .06;
  static const imageScrim = Color(0xB3000000);

  static Color foreground(int color) =>
      color == classBannerColors['sage'] || color == classBannerColors['olive']
      ? FiloColors.ink
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    final preset = classBannerColors.containsValue(color)
        ? color
        : classBannerColor(null);
    final background = image == null ? preset : classBannerColor(null);
    final ink = image == null ? foreground(preset) : Colors.white;
    final fallback = ColoredBox(
      color: Color(background),
      child: CustomPaint(
        painter: ClassBannerPattern(foreground(background)),
        child: const SizedBox.expand(),
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
                const SizedBox(height: 48),
                const SizedBox(
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, imageScrim],
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
                          colors: [imageScrim, Color(0xD9000000)],
                        ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              section,
                              style: TextStyle(
                                color: ink,
                                fontSize: 26,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ExcludeSemantics(
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: FiloIcon(
                                FiloIcons.book,
                                size: 25,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (avatar != null) ...[
                            avatar!,
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              instructor,
                              style: TextStyle(
                                color: ink,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
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

class ClassBannerPattern extends CustomPainter {
  const ClassBannerPattern(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink.withValues(alpha: ClassBanner.patternOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var y = -24.0; y < size.height; y += 64) {
      for (var x = -24.0; x < size.width; x += 80) {
        final book = Path()
          ..moveTo(x, y + 4)
          ..quadraticBezierTo(x + 10, y, x + 20, y + 6)
          ..quadraticBezierTo(x + 30, y, x + 40, y + 4)
          ..lineTo(x + 40, y + 30)
          ..quadraticBezierTo(x + 30, y + 26, x + 20, y + 32)
          ..quadraticBezierTo(x + 10, y + 26, x, y + 30)
          ..close()
          ..moveTo(x + 20, y + 6)
          ..lineTo(x + 20, y + 32);
        canvas.drawPath(book, paint);
      }
    }
  }

  @override
  bool shouldRepaint(ClassBannerPattern oldDelegate) => oldDelegate.ink != ink;
}
