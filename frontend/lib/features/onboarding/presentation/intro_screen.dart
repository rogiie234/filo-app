import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_artwork.dart';
import 'animation_constants.dart';
import 'intro_background.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _advancing = false;
  static const _slides = [
    (
      'Learning,\ntogether.',
      'Your classes, notes, and new ideas.\nAll in one happy place.',
      'waving',
    ),
    (
      'Small steps.\nBig wins.',
      'Keep your learning close.\nPick up right where you left off.',
      'cheerful',
    ),
    (
      'Stay curious.',
      'Ask questions. Explore your notes.\nMake room for your next discovery.',
      'curious',
    ),
  ];

  Future<void> _next() async {
    if (_advancing) return;
    if (_index == _slides.length - 1) {
      context.go('/sign-in');
      return;
    }
    setState(() => _advancing = true);
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pages.jumpToPage(_index + 1);
      } else {
        await _pages.nextPage(
          duration: FiloAnimation.uiDuration,
          curve: FiloAnimation.uiCurve,
        );
      }
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  Widget _textEntrance(Widget child, int page, {bool subtitle = false}) {
    if (MediaQuery.disableAnimationsOf(context) || page != _index) return child;
    final delay = subtitle ? FiloAnimation.subtitleDelay : Duration.zero;
    return child
        .animate(key: ValueKey('$page-$_index-$subtitle'))
        .fadeIn(
          delay: delay,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        )
        .moveY(
          begin: FiloAnimation.textRise,
          end: 0,
          delay: delay,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        );
  }

  Widget _skipEntrance(Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child.animate().fadeIn(
      duration: FiloAnimation.skipDuration,
      curve: FiloAnimation.uiCurve,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: IntroBackground()),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FiloSpacing.screen,
                  FiloSpacing.s12,
                  FiloSpacing.s16,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Brand()),
                    _skipEntrance(
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Skip intro'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: FiloSpacing.screen,
                              vertical: FiloSpacing.screen,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: constraints.maxHeight > 580 ? 24 : 0,
                                ),
                                Mascot(
                                  pose: slide.$3,
                                  bob: index == _index,
                                  size: entryMascotSize(context),
                                ),
                                const SizedBox(height: FiloSpacing.s20),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight:
                                        88 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(1),
                                  ),
                                  child: _textEntrance(
                                    Text(
                                      slide.$1,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                    ),
                                    index,
                                  ),
                                ),
                                const SizedBox(height: FiloSpacing.s16),
                                _textEntrance(
                                  Text(
                                    slide.$2,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  index,
                                  subtitle: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Semantics(
                    label: 'Page ${index + 1} of 3',
                    selected: _index == index,
                    child: Container(
                      width: _index == index ? 36 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(
                        horizontal: FiloSpacing.s4,
                      ),
                      decoration: BoxDecoration(
                        color: _index == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(FiloRadii.small),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FiloSpacing.screen,
                  FiloSpacing.s32,
                  FiloSpacing.screen,
                  FiloSpacing.s40,
                ),
                child: FiloButton(
                  label: _index == 2 ? 'Get started' : 'Next',
                  labelVariants: const ['Next', 'Get started'],
                  idlePulse: false,
                  icon: FiloIcons.forward,
                  animateArrow: true,
                  busy: _advancing,
                  onPressed: _advancing ? null : _next,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
