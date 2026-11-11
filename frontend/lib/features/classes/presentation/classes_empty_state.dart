import 'package:flutter/material.dart';

import '../../../core/widgets/filo_widgets.dart';

/// Classes-specific empty/search/offline presentation; optional action stays grouped with its message.
class ClassesEmptyState extends StatelessWidget {
  const ClassesEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.pose = 'waving',
    this.bob = true,
    this.action,
    this.illustrated = false,
  });
  final String title;
  final String message;

  final String pose;
  final bool bob;
  final Widget? action;
  final bool illustrated;
  @override
  Widget build(BuildContext context) => !illustrated && action == null
      ? EmptyState(
          title: title,
          message: message,
          pose: pose,
          bob: bob,
          action: action,
        )
      : Padding(
          padding: const EdgeInsets.all(FiloSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: IgnorePointer(
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: Image.asset(
                      'assets/illustrations/classes-empty.png',
                      fit: BoxFit.contain,
                      cacheWidth: (360 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                      errorBuilder: (_, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FiloSpacing.s16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: FiloSpacing.s8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: FiloSpacing.s20),
                action!,
              ],
            ],
          ),
        );
}
