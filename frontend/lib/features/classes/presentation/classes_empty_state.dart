import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

/// Classes-specific empty/search/offline presentation; actions stay in the footer.
class ClassesEmptyState extends StatelessWidget {
  const ClassesEmptyState({
    super.key,
    required this.title,
    required this.message,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => FiloPanel(
    color: FiloColors.tint,
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
    child: Column(
      children: [
        const Mascot(pose: 'confused', size: 144),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: FiloColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: FiloColors.secondary,
          ),
        ),
      ],
    ),
  );
}
