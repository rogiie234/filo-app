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
    surfaceTintColor: FiloPaint.transparent,
    constraints: const BoxConstraints(maxWidth: 440),
    insetPadding: const EdgeInsets.symmetric(
      horizontal: FiloSpacing.screen,
      vertical: FiloSpacing.screen,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FiloRadii.large),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    scrollable: true,
    titlePadding: const EdgeInsets.fromLTRB(
      FiloSpacing.screen,
      FiloSpacing.screen,
      FiloSpacing.screen,
      0,
    ),
    contentPadding: const EdgeInsets.fromLTRB(
      FiloSpacing.screen,
      FiloSpacing.screen,
      FiloSpacing.screen,
      FiloSpacing.s8,
    ),
    actionsPadding: const EdgeInsets.all(FiloSpacing.screen),
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FiloThemeTokens.of(context).mint,
              borderRadius: BorderRadius.circular(FiloRadii.medium),
            ),
            child: FiloIcon(
              icon,
              size: 26,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: FiloSpacing.s16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: FiloSpacing.s8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge!
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
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
              padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s20),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          Semantics(
            header: true,
            child: Text(
              sections[index].heading,
              style: Theme.of(context).textTheme.labelLarge!
                  .copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: FiloSpacing.s8),
          Text(
            sections[index].body,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
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
