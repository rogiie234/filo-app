import 'package:flutter/material.dart';

import '../../../core/widgets/filo_widgets.dart';

/// Classes-specific empty/search/offline presentation; actions stay in the footer.
class ClassesEmptyState extends StatelessWidget {
  const ClassesEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.pose = 'waving',
    this.bob = true,
  });
  final String title;
  final String message;

  final String pose;
  final bool bob;
  @override
  Widget build(BuildContext context) =>
      EmptyState(title: title, message: message, pose: pose, bob: bob);
}
