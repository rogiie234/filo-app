import 'package:flutter/material.dart';

import 'filo_icon.dart';
import '../theme/app_theme.dart';
import 'filo_button.dart';

/// Returns false for cancellation, the system back action, or barrier dismissal.
Future<bool> showFiloConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Go back',
  IconData icon = FiloIcons.checkCircle,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => FiloConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
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
    this.icon = FiloIcons.checkCircle,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: FiloColors.background,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: FiloColors.border),
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
                    color: FiloColors.selected,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FiloIcon(icon, size: 32, color: FiloColors.primary),
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: FiloColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: FiloColors.secondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            FiloButton(
              label: confirmLabel,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 12),
            FiloButton(
              label: cancelLabel,
              secondary: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}
