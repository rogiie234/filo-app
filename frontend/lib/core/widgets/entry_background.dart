import 'package:flutter/material.dart';

import '../theme/filo_theme_tokens.dart';

/// Static decoration never intercepts input or enters the reading order.
class EntryBackground extends StatelessWidget {
  const EntryBackground({
    super.key,
    this.verification = false,
    this.variation = 0,
    this.child,
    this.enabled = true,
    bool this._breeze = false,
  });
  final bool verification;
  final Widget? child;
  final bool enabled;

  /// Stable page composition; never randomized during rebuilds.
  final int variation;
  // Existing hot-reloaded instances may predate this optional decoration.
  final bool? _breeze;
  bool get breeze => _breeze ?? false;

  @override
  Widget build(BuildContext context) {
    if (!enabled && child != null) return child!;
    final background = ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _EntryPainter(
              mint: FiloThemeTokens.of(context).mint,
              primary: Theme.of(context).colorScheme.primary,
              verification: verification,
              breeze: breeze,
              variation: variation,
            ),
          ),
        ),
      ),
    );
    if (child == null) return background;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: background),
          child!,
        ],
      ),
    );
  }
}

class _EntryPainter extends CustomPainter {
  const _EntryPainter({
    required this.mint,
    required this.primary,
    required this.verification,
    required this.variation,
    required bool this._breeze,
  });
  final Color mint;
  final Color primary;
  final bool verification;
  final int variation;
  final bool? _breeze;
  bool get breeze => _breeze ?? false;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    void glow(Offset center) {
      final radius = size.width * .28;
      paint.shader = RadialGradient(
        colors: [mint.withValues(alpha: .6), mint.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    glow(Offset(-size.width * .08, size.height * .26));
    glow(Offset(size.width * 1.08, size.height * .54));
    paint.shader = null;
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.save();
    if (variation % 3 == 1) {
      canvas.translate(1, 0);
      canvas.scale(-1, 1);
    }
    paint.color = mint.withValues(alpha: .48);
    canvas.drawPath(
      Path()
        ..moveTo(.35 + (variation % 7) * .035, 0)
        ..cubicTo(
          .6,
          .10 + (variation % 4) * .02,
          .8,
          .02,
          1,
          .16 + (variation % 5) * .02,
        )
        ..lineTo(1, 0)
        ..close(),
      paint,
    );
    canvas.restore();
    paint.color = mint.withValues(alpha: .65);
    final backWave = verification
        ? (Path()
            ..moveTo(0, .85)
            ..cubicTo(.22, .8, .42, .94, .65, .9)
            ..cubicTo(.85, .86, .95, .86, 1, .87)
            ..lineTo(1, 1)
            ..lineTo(0, 1)
            ..close())
        : (Path()
            ..moveTo(0, .82)
            ..cubicTo(.22, .77, .32, .92, .57, .86)
            ..cubicTo(.8, .8, .84, .76, 1, .8)
            ..lineTo(1, 1)
            ..lineTo(0, 1)
            ..close());
    canvas.drawPath(backWave, paint);
    paint.color = mint.withValues(alpha: .7);
    final frontWave = verification
        ? (Path()
            ..moveTo(0, .91)
            ..cubicTo(.3, .85, .55, .99, .77, .93)
            ..cubicTo(.9, .91, .96, .9, 1, .9)
            ..lineTo(1, 1)
            ..lineTo(0, 1)
            ..close())
        : (Path()
            ..moveTo(0, .86)
            ..cubicTo(.24, .8, .4, .83, .62, .89)
            ..cubicTo(.82, .94, .94, .88, 1, .88)
            ..lineTo(1, 1)
            ..lineTo(0, 1)
            ..close());
    canvas.drawPath(frontWave, paint);
    canvas.restore();

    void sprig(Offset origin, double scale) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(scale, scale.abs());
      paint.color = primary.withValues(alpha: .24);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..cubicTo(-30, -12, -30, -37, -24, -38)
          ..cubicTo(-7, -35, -4, -15, 0, 0)
          ..moveTo(2, -20)
          ..cubicTo(-6, -41, 5, -65, 16, -67)
          ..cubicTo(23, -48, 14, -29, 2, -20)
          ..moveTo(2, -4)
          ..cubicTo(8, -25, 25, -32, 37, -27)
          ..cubicTo(31, -9, 15, -3, 2, -4),
        paint,
      );
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(
        Path()
          ..moveTo(0, 2)
          ..quadraticBezierTo(-1, -12, 5, -32),
        paint,
      );
      paint.style = PaintingStyle.fill;
      canvas.restore();
    }

    if (breeze) {
      void windLeaf(Offset origin) {
        canvas.save();
        canvas.translate(origin.dx, origin.dy);
        final scale = (size.width / 420).clamp(.65, 1.1).toDouble();
        canvas.scale(scale, scale);
        paint
          ..color = primary.withValues(alpha: .13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(0, 45)
            ..cubicTo(40, 58, 72, 23, 47, 22)
            ..cubicTo(33, 20, 37, 39, 65, 16),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 57)
            ..quadraticBezierTo(43, 63, 68, 39),
          paint,
        );
        paint
          ..style = PaintingStyle.fill
          ..color = primary.withValues(alpha: .18);
        canvas.drawPath(
          Path()
            ..moveTo(62, 17)
            ..cubicTo(59, -1, 75, -8, 92, -3)
            ..cubicTo(85, 16, 75, 22, 62, 17)
            ..close(),
          paint,
        );
        canvas.restore();
      }

      windLeaf(Offset(size.width - 108, 20));

      canvas.save();
      canvas.translate(8, size.height * .5);
      final gustScale = (size.width / 420).clamp(.65, 1.1).toDouble();
      canvas.scale(gustScale, gustScale);
      paint
        ..style = PaintingStyle.stroke
        ..color = primary.withValues(alpha: .12)
        ..strokeWidth = 1.3;
      canvas.drawPath(
        Path()
          ..moveTo(-12, 45)
          ..cubicTo(23, 14, 58, 68, 111, 26),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-4, 56)
          ..cubicTo(26, 35, 53, 77, 88, 51),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(103, 42)
          ..quadraticBezierTo(117, 36, 124, 27),
        paint,
      );
      paint
        ..style = PaintingStyle.fill
        ..color = primary.withValues(alpha: .18);
      canvas.drawPath(
        Path()
          ..moveTo(37, 15)
          ..cubicTo(29, 4, 34, -9, 47, -18)
          ..cubicTo(51, -2, 47, 9, 37, 15)
          ..close()
          ..moveTo(79, 69)
          ..cubicTo(76, 57, 83, 51, 98, 49)
          ..cubicTo(94, 62, 88, 68, 79, 69)
          ..close(),
        paint,
      );
      paint
        ..style = PaintingStyle.stroke
        ..color = primary.withValues(alpha: .24);
      canvas.drawPath(
        Path()
          ..moveTo(35, 20)
          ..lineTo(44, -8)
          ..moveTo(76, 72)
          ..lineTo(92, 56),
        paint,
      );
      paint.style = PaintingStyle.fill;
      canvas.restore();
    }

    final leafScale = (size.width / 480).clamp(.55, 1.0).toDouble();
    sprig(
      Offset(size.width * .09, size.height * (verification ? .86 : .835)),
      leafScale,
    );
    sprig(
      Offset(size.width * .94, size.height * (verification ? .93 : .875)),
      -leafScale * .75,
    );
  }

  @override
  bool shouldRepaint(covariant _EntryPainter oldDelegate) =>
      mint != oldDelegate.mint ||
      primary != oldDelegate.primary ||
      verification != oldDelegate.verification ||
      breeze != oldDelegate.breeze ||
      variation != oldDelegate.variation;
}
