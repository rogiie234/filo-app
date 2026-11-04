import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/animation_constants.dart';
import '../../../core/widgets/entry_background.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../data/profile_repository.dart';
import 'role_option_card.dart';

/// Scrollable choices and a separate, consistently anchored primary action.
class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({
    super.key,
    required this.selectedRole,
    required this.onSelected,
    required this.onContinue,
  });
  final AccountRole? selectedRole;
  final ValueChanged<AccountRole> onSelected;
  final VoidCallback onContinue;

  Widget entrance(BuildContext context, Widget child, Duration delay) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate()
        .fadeIn(
          delay: delay,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        )
        .moveY(
          begin: FiloAnimation.roleEntranceOffset,
          end: 0,
          delay: delay,
          duration: FiloAnimation.textDuration,
          curve: FiloAnimation.uiCurve,
        );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: EntryBackground(verification: true)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      FiloSpacing.screen,
                      FiloSpacing.s16,
                      FiloSpacing.screen,
                      FiloSpacing.screen,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Brand(),
                            ),
                            const SizedBox(height: FiloSpacing.s16),
                            const Mascot(pose: 'thinking', size: 140),
                            const SizedBox(height: FiloSpacing.s16),
                            entrance(
                              context,
                              Column(
                                children: [
                                  Text(
                                    'Choose your role',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const SizedBox(height: FiloSpacing.s12),
                                  Text(
                                    'A place for curious minds and inspiring teachers.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              Duration.zero,
                            ),
                            const SizedBox(height: FiloSpacing.screen),
                            for (final role in AccountRole.values)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: FiloSpacing.s12,
                                ),
                                child: entrance(
                                  context,
                                  RoleOptionCard(
                                    role: role,
                                    selected: selectedRole == role,
                                    onPressed: () => onSelected(role),
                                  ),
                                  FiloAnimation.roleCardStagger *
                                      (role.index + 1),
                                ),
                              ),
                            const SizedBox(height: FiloSpacing.s8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 22,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: FiloSpacing.s12),
                                Expanded(
                                  child: Text(
                                    'Choose carefully. You cannot change your role later. If you choose the wrong role, you will need to delete your account and sign in again.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FiloSpacing.screen,
                    FiloSpacing.s12,
                    FiloSpacing.screen,
                    FiloSpacing.screen,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: FiloButton(
                        label: 'Continue',
                        minHeight: 64,
                        onPressed: selectedRole == null ? null : onContinue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
