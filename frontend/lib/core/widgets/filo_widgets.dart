import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

class FiloButton extends StatelessWidget {
  const FiloButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: secondary ? FiloColors.mint : FiloColors.edge,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? Colors.white : FiloColors.primary,
          foregroundColor: secondary ? FiloColors.ink : Colors.white,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          side: secondary ? const BorderSide(color: FiloColors.border) : null,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            if (icon != null) ...[
              const SizedBox(width: 12),
              Icon(icon, size: 20),
            ],
          ],
        ),
      ),
    ),
  );
}

class FiloPanel extends StatelessWidget {
  const FiloPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: FiloColors.border),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        const Mascot(pose: 'curious', size: 120),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: FiloColors.secondary),
        ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
