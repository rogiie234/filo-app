export 'filo_validation.dart';
export '../theme/filo_design_tokens.dart';
export '../theme/filo_motion.dart';
export '../feedback/filo_haptics.dart';
export 'filo_motion_widgets.dart';
export 'filo_navigation_bar.dart';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_confirmation_dialog.dart';
import 'filo_components.dart';
import 'filo_button.dart';
import 'mascot_idle.dart';
export 'mascot_idle.dart';
export 'filo_components.dart';
export 'filo_file_type.dart';

export 'filo_button.dart';
export 'filo_bottom_sheet.dart';
export 'filo_confirmation_dialog.dart';
export 'filo_icon.dart';
export 'filo_notice_dialog.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/brand/logo-mark-dark.png'
              : 'assets/brand/logo-mark-light.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          cacheWidth: (36 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          excludeFromSemantics: true,
        ),
        const SizedBox(width: FiloSpacing.s8),
        Text('filo', style: FiloTypography.wordmark(context)),
      ],
    ),
  );
}

class Mascot extends StatelessWidget {
  const Mascot({
    super.key,
    this.pose = 'waving',
    this.size = 220,
    this.bob = false,
  });
  final String pose;
  final double size;
  final bool bob;
  static const poses = [
    'waving',
    'curious',
    'cheerful',
    'sleepy',
    'thinking',
    'confused',
    'confused_notepad',
    'cheerful_note',
    'waiting',
    'clock',
    'folder',
    'reading',
  ];
  @override
  Widget build(BuildContext context) {
    final image = ExcludeSemantics(
      child: ClipOval(
        child: ColoredBox(
          color: FiloThemeTokens.of(context).mint,
          child: Image.asset(
            'assets/mascots/${size <= 120 ? 'empty/' : ''}$pose.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
        ),
      ),
    );
    return bob ? MascotIdle(child: image) : image;
  }
}

class FiloPanel extends StatelessWidget {
  const FiloPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(FiloSpacing.s20),
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FiloRadii.large),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    child: Padding(padding: padding, child: child),
  );
}

enum EmptyStateVariant { fullScreen, inline }

class EmptyStateAction {
  const EmptyStateAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
}

/// Shared empty and recovery panel; callers decide whether data is truly empty.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.message = '',
    this.illustration,
    this.pose = 'curious',
    this.bob = false,
    this.showMascot = true,
    this.primaryAction,
    this.secondaryAction,
    this.children = const [],
    this.variant = EmptyStateVariant.inline,
    this.action,
  });
  final String title;
  final String? body;
  final String message;
  final Widget? illustration;
  final String pose;
  final bool bob;
  final bool showMascot;
  final EmptyStateAction? primaryAction, secondaryAction;
  final List<Widget> children;
  final EmptyStateVariant variant;
  // Existing specialized recovery controls retain their guarded callbacks.
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final description = body ?? message;
      final panel = FiloPanel(
        color: FiloThemeTokens.of(context).mint,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (illustration != null || showMascot) ...[
              ExcludeSemantics(
                child: Center(
                  child:
                      illustration ?? Mascot(pose: pose, size: 120, bob: bob),
                ),
              ),
              const SizedBox(height: FiloSpacing.s20),
            ],
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: FiloSpacing.s8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (children.isNotEmpty) ...[
              const SizedBox(height: FiloSpacing.s16),
              ...children,
            ],
            if (primaryAction case final primary?) ...[
              const SizedBox(height: FiloSpacing.s20),
              FiloButton(label: primary.label, onPressed: primary.onPressed),
            ],
            if (action != null) ...[
              const SizedBox(height: FiloSpacing.s20),
              action!,
            ],
            if (secondaryAction case final secondary?) ...[
              const SizedBox(height: FiloSpacing.s8),
              FiloButton(
                text: true,
                label: secondary.label,
                onPressed: secondary.onPressed,
              ),
            ],
          ],
        ),
      );
      if (!constraints.hasBoundedHeight) return panel;
      return SingleChildScrollView(
        child: variant == EmptyStateVariant.fullScreen
            ? ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(child: panel),
              )
            : panel,
      );
    },
  );
}

void showMessage(BuildContext context, String message) =>
    showFiloToast(context, message);

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) => showFiloConfirmation(
  context,
  title: title,
  message: message,
  confirmLabel: action,
  cancelLabel: 'Cancel',
  cancelIsPrimary: true,
);
