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

/// Successful illustrated empty lists, separate from loading/error recovery.
class FiloIllustratedEmptyState extends StatelessWidget {
  const FiloIllustratedEmptyState({
    super.key,
    required this.asset,
    required this.title,
    this.message = '',
  });
  final String asset, title, message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FiloSpacing.screen),
    child: Column(
      children: [
        ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: ColorFiltered(
                // Remove low-opacity haze from the existing generated illustrations.
                colorFilter: const ColorFilter.matrix([
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                  0,
                  0,
                  0,
                  0,
                  12,
                  -2700,
                ]),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  cacheWidth: (360 * MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: FiloSpacing.s16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: FiloSpacing.s8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message = '',
    this.pose = 'curious',
    this.bob = true,
    this.showMascot = true,
    this.action,
  });
  final String title;
  final String message;
  final String pose;
  final bool bob;
  final bool showMascot;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final panel = FiloPanel(
        color: FiloThemeTokens.of(context).mint,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMascot) ...[
              Mascot(pose: pose, size: 120, bob: bob),
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
            if (message.isNotEmpty) ...[
              const SizedBox(height: FiloSpacing.s8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: FiloSpacing.s20),
              action!,
            ],
          ],
        ),
      );
      return constraints.hasBoundedHeight
          ? SingleChildScrollView(child: panel)
          : panel;
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
