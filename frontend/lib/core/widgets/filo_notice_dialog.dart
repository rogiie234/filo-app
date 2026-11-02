import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_button.dart';
import 'filo_icon.dart';

/// A readable section of a notice; text is supplied by the owning feature.
class FiloNoticeSection {
  const FiloNoticeSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

/// Informational only: closing a notice never records agreement or acceptance.
class FiloNoticeDialog extends StatelessWidget {
  const FiloNoticeDialog({
    super.key,
    required this.title,
    required this.sections,
    this.icon = FiloIcons.shield,
  });
  final String title;
  final List<FiloNoticeSection> sections;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 440),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    scrollable: true,
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    actionsPadding: const EdgeInsets.all(24),
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FiloThemeTokens.of(context).mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FiloIcon(
              icon,
              size: 26,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 28 / 22,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    ),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          Semantics(
            header: true,
            child: Text(
              sections[index].heading,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sections[index].body,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    ),
    actions: [
      SizedBox(
        width: double.infinity,
        child: FiloButton(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    ],
  );
}
