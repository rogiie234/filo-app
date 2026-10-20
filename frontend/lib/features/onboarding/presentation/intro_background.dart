import 'package:flutter/material.dart';

import 'animation_constants.dart';

/// Painter ticks repaint only this boundary, without rebuilding intro content.
class IntroBackground extends StatefulWidget {
  const IntroBackground({super.key});

  @override
  State<IntroBackground> createState() => _IntroBackgroundState();
}

class _IntroBackgroundState extends State<IntroBackground>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: FiloAnimation.backgroundDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _AmbientPainter(_controller)),
      ),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final drift =
        FiloAnimation.ambientCurve.transform(motion.value) *
        FiloAnimation.backgroundDrift;
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

    blob(
      Offset(-18 + drift, size.height * .23),
      FiloAnimation.backgroundMint,
      radius,
    );
    blob(
      Offset(size.width + 12 - drift, size.height * .48 + drift),
      FiloAnimation.backgroundYellow,
      radius * .85,
    );
    blob(
      Offset(12 - drift, size.height * .82 - drift),
      FiloAnimation.backgroundMint,
      radius * .7,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
