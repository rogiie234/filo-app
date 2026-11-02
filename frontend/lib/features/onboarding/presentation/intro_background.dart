import 'package:flutter/material.dart';

import 'animation_constants.dart';

/// Static atmosphere leaves the single idle loop to the active mascot.
class IntroBackground extends StatelessWidget {
  const IntroBackground({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: const _AmbientPainter()),
      ),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = FiloAnimation.backgroundBlobRadius;
    final paint = Paint();
    // Radial falloff, no blur filter or saveLayer. Centres stay at screen edges.
    void blob(Offset center, Color color, double r) {
      paint.shader = RadialGradient(
        colors: [
          color.withValues(alpha: FiloAnimation.backgroundOpacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, paint);
    }

    blob(Offset(-18, size.height * .23), FiloAnimation.backgroundMint, radius);
    blob(
      Offset(size.width + 12, size.height * .48),
      FiloAnimation.backgroundYellow,
      radius * .85,
    );
    blob(
      Offset(12, size.height * .82),
      FiloAnimation.backgroundMint,
      radius * .7,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => false;
}
