import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';

/// Permission outcome and navigation remain owned by AccountSetupScreen.
class NotificationPromptView extends StatelessWidget {
  const NotificationPromptView({
    super.key,
    required this.busy,
    required this.onEnable,
    required this.onSkip,
  });
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  Widget _benefit(BuildContext context, IconData icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s8),
    child: Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(FiloRadii.small),
            ),
            child: FiloIcon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: FiloSpacing.s16),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: FiloThemeTokens.of(context).mint,
                borderRadius: BorderRadius.circular(FiloRadii.pill),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: FiloIcon(
                FiloIcons.notifications,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: FiloSpacing.screen),
        Semantics(
          header: true,
          child: Text(
            'Stay up to date',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: FiloSpacing.s12),
        Text(
          'Enable notifications for class updates, deadlines, and grades. You can change notification access in Android settings.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge!
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: FiloSpacing.screen),
        FiloPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: FiloSpacing.s20,
            vertical: FiloSpacing.s8,
          ),
          child: Column(
            children: [
              _benefit(context, FiloIcons.announcement, 'Class updates'),
              Divider(height: 1, color: Theme.of(context).colorScheme.outline),
              _benefit(context, FiloIcons.calendar, 'Deadlines'),
              Divider(height: 1, color: Theme.of(context).colorScheme.outline),
              _benefit(context, FiloIcons.grades, 'Grades'),
            ],
          ),
        ),
      ],
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return content
        .animate()
        .fadeIn(
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        )
        .moveY(
          begin: FiloAnimation.textRise,
          end: 0,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: EntryBackground(variation: 2, verification: true),
          ),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Align(alignment: Alignment.centerLeft, child: Brand()),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        FiloSpacing.screen,
                        FiloSpacing.screen,
                        FiloSpacing.screen,
                        FiloSpacing.screen,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (viewport.maxHeight - 48)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _content(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FiloSpacing.screen,
                    FiloSpacing.s12,
                    FiloSpacing.screen,
                    FiloSpacing.screen,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FiloButton(
                            label: 'Not now',
                            text: true,
                            minHeight: 64,
                            onPressed: busy ? null : onSkip,
                          ),
                          const SizedBox(height: FiloSpacing.s8),
                          FiloButton(
                            label: busy
                                ? 'Continuing\u2026'
                                : 'Enable notifications',
                            busy: busy,
                            minHeight: 64,
                            labelVariants: const [
                              'Enable notifications',
                              'Continuing\u2026',
                            ],
                            onPressed: busy ? null : onEnable,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
