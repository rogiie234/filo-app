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
  Widget build(BuildContext context) => FiloModalDialog(
    title: title,
    icon: icon,
    destructive: confirmDestructive,
    content: Text(message),
    actions: [
      FiloButton(
        label: cancelIsPrimary ? cancelLabel : confirmLabel,
        destructive: !cancelIsPrimary && confirmDestructive,
        outlined: !cancelIsPrimary && confirmOutlined,
        onPressed: () => Navigator.of(context).pop(!cancelIsPrimary),
      ),
      FiloButton(
        label: cancelIsPrimary ? confirmLabel : cancelLabel,
        secondary: true,
        destructive: cancelIsPrimary && confirmDestructive,
        outlined: cancelIsPrimary && confirmOutlined,
        onPressed: () => Navigator.of(context).pop(cancelIsPrimary),
      ),
    ],
  );
}

/// One surface for confirmations and forms; callers keep validation and results.
class FiloModalDialog extends StatelessWidget {
  const FiloModalDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon = FiloIcons.checkCircle,
    this.destructive = false,
  });
  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: FiloPaint.transparent,
      insetPadding: const EdgeInsets.all(FiloSpacing.screen),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FiloRadii.large),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FiloSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(FiloSpacing.s12),
                    decoration: BoxDecoration(
                      color: destructive
                          ? colors.errorContainer
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(FiloRadii.medium),
                    ),
                    child: FiloIcon(
                      icon,
                      size: 28,
                      color: destructive
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FiloSpacing.s16),
              Semantics(
                namesRoute: true,
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: FiloSpacing.s12),
              DefaultTextStyle(
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                child: content,
              ),
              const SizedBox(height: FiloSpacing.screen),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: FiloSpacing.s12),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
