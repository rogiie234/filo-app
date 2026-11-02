import 'package:flutter/material.dart';

import 'filo_icon.dart';
import 'filo_button.dart';

/// Returns false for cancellation, the system back action, or barrier dismissal.
Future<bool> showFiloConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Go back',
  bool cancelIsPrimary = false,
  IconData icon = FiloIcons.checkCircle,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => FiloConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        cancelIsPrimary: cancelIsPrimary,
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
    this.icon = FiloIcons.checkCircle,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool cancelIsPrimary;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FiloIcon(
                    icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              namesRoute: true,
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FiloButton(
              label: cancelIsPrimary ? cancelLabel : confirmLabel,
              onPressed: () => Navigator.of(context).pop(!cancelIsPrimary),
            ),
            const SizedBox(height: 12),
            FiloButton(
              label: cancelIsPrimary ? confirmLabel : cancelLabel,
              secondary: true,
              onPressed: () => Navigator.of(context).pop(cancelIsPrimary),
            ),
          ],
        ),
      ),
    ),
  );
}
