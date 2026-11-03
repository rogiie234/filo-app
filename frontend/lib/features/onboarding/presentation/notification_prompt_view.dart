import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

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
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: FiloIcon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
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
                borderRadius: BorderRadius.circular(36),
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
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            'Stay up to date',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enable notifications for class updates, deadlines, and grades. You can change notification access in Android settings.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FiloPanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FiloButton(
                        label: busy
                            ? 'Continuing\u2026'
                            : 'Enable notifications',
                        busy: busy,
                        onPressed: busy ? null : onEnable,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: TextButton(
                          onPressed: busy ? null : onSkip,
                          child: const Text('Not now'),
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
    ),
  );
}
