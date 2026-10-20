import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/class_providers.dart';

// Keep this roster separate from RLS-scoped membership rows and local profiles.
final classClassmatesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, classId) async {
      final online = await ref.watch(connectivityProvider.future);
      if (!online) throw StateError('Connect to view classmates.');
      final repository = await ref.watch(classMemberRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      final result = await repository.classmates(classId);
      return (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((row) => row['id'] != repository.classes.userId)
          .toList();
    });

class ClassClassmatesScreen extends ConsumerWidget {
  const ClassClassmatesScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classmates = ref.watch(classClassmatesProvider(classId));
    final online = ref.watch(connectivityProvider).asData?.value == true;
    Future<void> refresh() async {
      ref.invalidate(classClassmatesProvider(classId));
      try {
        await ref.read(classClassmatesProvider(classId).future);
      } catch (_) {
        // The provider renders the error and retry action below.
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Classmates')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: classmates.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (_, _) => [
              FiloPanel(
                child: Column(
                  children: [
                    Text(
                      online
                          ? 'Could not load classmates. The class may no longer be available.'
                          : 'Connect to the internet to view classmates.',
                    ),
                    TextButton(
                      onPressed: online ? refresh : null,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
            data: (rows) => rows.isEmpty
                ? [
                    const EmptyState(
                      title: 'No classmates yet',
                      message: "Other students will appear here once they're approved to join.",
                    ),
                  ]
                : [
                    for (final row in rows)
                      ListTile(
                        leading: const CircleAvatar(
                          child: FiloIcon(FiloIcons.person),
                        ),
                        title: Text(
                          row['display_name'] as String? ?? 'Student',
                        ),
                      ),
                  ],
          ),
        ),
      ),
    );
  }
}
