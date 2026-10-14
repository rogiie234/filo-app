import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/preview_controller.dart';
import '../../classes/domain/prototype_models.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Brand()),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('About Filo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  const Mascot(size: 240),
                  const SizedBox(height: 32),
                  Text(
                    'Hello,\ncurious mind.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A little curiosity goes a long way.\nLet’s see where yours takes you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FiloColors.secondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                FiloButton(
                  label: 'Continue with Google',
                  secondary: true,
                  icon: Icons.login_rounded,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Explore Filo first.'),
                      content: const Text(
                        'Sign-in is not connected in this preview. You can explore the sample classrooms without an account.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _explore(context, ref),
                  child: const Text(
                    'Explore the preview',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _explore(BuildContext context, WidgetRef ref) async {
    final role = await showModalBottomSheet<PreviewRole>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Take a look around.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a view. Sample changes stay in this session only.',
                style: TextStyle(color: FiloColors.secondary),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.school_rounded),
                title: const Text('Student'),
                subtitle: const Text(
                  'Browse classes, materials, and classwork',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.pop(context, PreviewRole.student),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded),
                title: const Text('Instructor'),
                subtitle: const Text('Try creating a post and an assessment'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.pop(context, PreviewRole.instructor),
              ),
            ],
          ),
        ),
      ),
    );
    if (role != null && context.mounted) {
      ref.read(previewProvider.notifier).chooseRole(role);
      context.go('/classes');
    }
  }
}
