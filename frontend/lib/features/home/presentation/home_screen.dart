import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../onboarding/data/profile_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.profile, super.key});
  final AccountProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome, ${profile.name}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text('${profile.role.label} account'),
          if (profile.school != null) Text(profile.school!),
          const SizedBox(height: 32),
          const Icon(Icons.school_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Your classes will appear here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
