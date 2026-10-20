import 'package:flutter/material.dart';

import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

/// Presentation only: SessionScreen owns verification and its next destination.
class SessionLoadingView extends StatelessWidget {
  const SessionLoadingView({
    super.key,
    this.message,
    this.error = false,
    this.statusText = 'We\u2019re checking this device before you continue.',
  });
  final String? message;
  final bool error;
  final String statusText;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (viewport.maxHeight - 56)
                .clamp(0.0, double.infinity)
                .toDouble(),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Mascot(
                    pose: 'sleepy',
                    size: (viewport.maxWidth - 80)
                        .clamp(156.0, 240.0)
                        .toDouble(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'One moment\u2026',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FiloColors.secondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _LoadingDots(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: error ? FiloColors.error : FiloColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: FiloAnimation.loadingCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: 24,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final phase = (_controller.value * 3 - index)
                      .clamp(0.0, 1.0)
                      .toDouble();
                  final triangle = phase <= .5 ? phase * 2 : (1 - phase) * 2;
                  final lift = reduced
                      ? 0.0
                      : FiloAnimation.ambientCurve.transform(triangle);
                  return Transform.translate(
                    offset: Offset(0, -FiloAnimation.loadingDotTravel * lift),
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FiloAnimation.loadingDotColor.withValues(
                          alpha:
                              FiloAnimation.loadingDotOpacity +
                              (1 - FiloAnimation.loadingDotOpacity) * lift,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
