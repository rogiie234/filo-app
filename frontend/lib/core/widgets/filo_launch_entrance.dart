import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/filo_motion.dart';

/// One entrance per app mount; routing and account initialization stay mounted.
class FiloLaunchEntrance extends StatefulWidget {
  const FiloLaunchEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<FiloLaunchEntrance> createState() => _FiloLaunchEntranceState();
}

class _FiloLaunchEntranceState extends State<FiloLaunchEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  Timer? _fallback;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!FiloMotion.enabled(context)) {
      _controller.value = 1;
      _fallback?.cancel();
    } else if (!_started && !_controller.isCompleted) {
      _started = true;
      _controller.forward();
      _fallback = Timer(const Duration(seconds: 3), () {
        _controller.value = 1;
      });
    }
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      final playing = t < 1;
      double phase(double start, double end) => Curves.easeOutCubic.transform(
        ((t - start) / (end - start)).clamp(0.0, 1.0),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: playing,
            child: ExcludeSemantics(
              excluding: playing,
              child: TickerMode(enabled: !playing, child: widget.child),
            ),
          ),
          if (playing)
            Positioned.fill(
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -MediaQuery.sizeOf(context).height * phase(.76, 1),
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SizedBox.expand(
                      child: Semantics(
                        label: 'Starting Filo',
                        child: ExcludeSemantics(
                          child: SafeArea(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ClipRect(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: List.generate(
                                                4,
                                                (index) => Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    110 *
                                                        (1 -
                                                            phase(
                                                              index * .035,
                                                              .32 +
                                                                  index * .035,
                                                            )),
                                                  ),
                                                  child: Text(
                                                    'filo'[index],
                                                    style:
                                                        FiloTypography.wordmark(
                                                          context,
                                                        ).copyWith(
                                                          fontSize: 88,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width:
                                                110 *
                                                phase(.12, .3) *
                                                (1 - phase(.67, .8)),
                                            height: 110,
                                            child: ClipRect(
                                              child: OverflowBox(
                                                minWidth: 110,
                                                maxWidth: 110,
                                                child: Stack(
                                                  children: [
                                                    for (final (index, pose)
                                                        in [
                                                          'waving',
                                                          'cheerful',
                                                          'curious',
                                                        ].indexed)
                                                      Opacity(
                                                        opacity:
                                                            phase(
                                                              .18 + index * .16,
                                                              .24 + index * .16,
                                                            ) *
                                                            (1 -
                                                                phase(
                                                                  .35 +
                                                                      index *
                                                                          .16,
                                                                  .41 +
                                                                      index *
                                                                          .16,
                                                                )),
                                                        child: Image.asset(
                                                          'assets/mascots/entry/$pose.png',
                                                          width: 110,
                                                          height: 110,
                                                          cacheWidth:
                                                              (110 *
                                                                      MediaQuery.devicePixelRatioOf(
                                                                        context,
                                                                      ))
                                                                  .ceil(),
                                                          errorBuilder:
                                                              (_, _, _) =>
                                                                  const SizedBox(
                                                                    width: 110,
                                                                    height: 110,
                                                                  ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Opacity(
                                      opacity: phase(.2, .4),
                                      child: Text(
                                        'Learning, together.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
