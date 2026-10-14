import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _index = 0;
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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Brand()),
                TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Skip intro'),
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
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Mascot(
                              pose: slide.$3,
                              size: constraints.maxHeight < 460 ? 180 : 240,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              slide.$1,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.$2,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: FiloColors.secondary),
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
                  width: _index == index ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _index == index
                        ? FiloColors.primary
                        : FiloColors.mint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: FiloButton(
              label: _index == 2 ? 'Get started' : 'Next',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                if (_index == 2) {
                  context.go('/sign-in');
                } else if (MediaQuery.disableAnimationsOf(context)) {
                  _pages.jumpToPage(_index + 1);
                } else {
                  _pages.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
}
