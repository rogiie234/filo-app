import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_confirmation_dialog.dart';
import 'filo_components.dart';
export 'filo_components.dart';

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
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/brand/icon.png',
            width: 36,
            height: 36,
            cacheWidth: 108,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'filo',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class Mascot extends StatelessWidget {
  const Mascot({super.key, this.pose = 'waving', this.size = 220});
  final String pose;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipOval(
      child: Image.asset(
        'assets/mascots/$pose.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
    ),
  );
}

class FiloPanel extends StatelessWidget {
  const FiloPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.showMascot = true,
    this.action,
  });
  final String title;
  final String message;
  final bool showMascot;
  final Widget? action;
  @override
  Widget build(BuildContext context) => FiloPanel(
    color: FiloThemeTokens.of(context).mint,
    child: Column(
      children: [
        if (showMascot) ...[
          const Mascot(pose: 'curious', size: 120),
          const SizedBox(height: 20),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
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
