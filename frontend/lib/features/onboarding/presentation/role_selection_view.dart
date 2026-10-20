import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_theme.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const Mascot(pose: 'thinking', size: 140),
                        const SizedBox(height: 16),
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
                              const SizedBox(height: 10),
                              const Text(
                                'A place for curious minds and inspiring teachers.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FiloColors.secondary,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                          Duration.zero,
                        ),
                        const SizedBox(height: 24),
                        for (final role in AccountRole.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: entrance(
                              context,
                              RoleOptionCard(
                                role: role,
                                selected: selectedRole == role,
                                onPressed: () => onSelected(role),
                              ),
                              FiloAnimation.roleCardStagger * (role.index + 1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: FiloButton(
                    label: 'Continue',
                    onPressed: selectedRole == null ? null : onContinue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
