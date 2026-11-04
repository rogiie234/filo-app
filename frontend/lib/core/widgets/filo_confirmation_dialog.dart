import '../theme/filo_design_tokens.dart';

import 'package:flutter/material.dart';

import 'filo_icon.dart';
import '../theme/filo_motion.dart';
import 'filo_button.dart';

/// Returns false for cancellation, the system back action, or barrier dismissal.
Future<bool> showFiloConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Go back',
  bool cancelIsPrimary = false,
  bool confirmDestructive = false,
  bool confirmOutlined = false,
  bool animate = true,
  IconData icon = FiloIcons.checkCircle,
}) async =>
    await showFiloDialog<bool>(
      context: context,
      animate: animate,
      animationStyle: FiloMotion.enabled(context)
          ? null
          : AnimationStyle.noAnimation,
      builder: (context) => FiloConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        cancelIsPrimary: cancelIsPrimary,
        confirmDestructive: confirmDestructive,
        confirmOutlined: confirmOutlined,
        icon: icon,
      ),
    ) ??
    false;

/// Shared confirmation surface with the app's tactile action buttons.
class FiloConfirmationDialog extends StatelessWidget {
  const FiloConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Go back',
    this.cancelIsPrimary = false,
    this.confirmDestructive = false,
    this.confirmOutlined = false,
    this.icon = FiloIcons.checkCircle,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool cancelIsPrimary;
  final bool confirmDestructive, confirmOutlined;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: FiloPaint.transparent,
    insetPadding: const EdgeInsets.symmetric(
      horizontal: FiloSpacing.screen,
      vertical: FiloSpacing.screen,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FiloRadii.large),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FiloSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ExcludeSemantics(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(FiloRadii.medium),
                  ),
                  child: FiloIcon(
                    icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: FiloSpacing.s20),
            Semantics(
              namesRoute: true,
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: FiloSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: FiloSpacing.s32),
            FiloButton(
              label: cancelIsPrimary ? cancelLabel : confirmLabel,
              destructive: !cancelIsPrimary && confirmDestructive,
              outlined: !cancelIsPrimary && confirmOutlined,
              onPressed: () => Navigator.of(context).pop(!cancelIsPrimary),
            ),
            const SizedBox(height: FiloSpacing.s12),
            FiloButton(
              label: cancelIsPrimary ? confirmLabel : cancelLabel,
              secondary: true,
              destructive: cancelIsPrimary && confirmDestructive,
              outlined: cancelIsPrimary && confirmOutlined,
              onPressed: () => Navigator.of(context).pop(cancelIsPrimary),
            ),
          ],
        ),
      ),
    ),
  );
}
