import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../application/class_providers.dart';

class RecentlyDeletedScreen extends ConsumerStatefulWidget {
  const RecentlyDeletedScreen({super.key});
  @override
  ConsumerState<RecentlyDeletedScreen> createState() => _RecentlyDeletedState();
}

class _RecentlyDeletedState extends ConsumerState<RecentlyDeletedScreen> {
  String? _busy;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    Future.microtask(() {
      if (mounted) ref.read(classSyncProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _restore(CacheClassesData room) async {
    if (_busy != null ||
        ref.read(connectivityProvider).asData?.value != true ||
        !DateTime.now().toUtc().isBefore(
          room.deletedAt!.toUtc().add(const Duration(days: 14)),
        )) {
      return;
    }
    setState(() => _busy = room.id);
    try {
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      await repository.restoreDeleted(room.id);
      if (mounted) showMessage(context, 'Class restored.');
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          "We couldn't confirm the restore. Refresh before retrying. Classes can only be restored within 14 days.",
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(deletedClassesProvider);
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final sync = ref.watch(classSyncProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recently deleted')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(classSyncProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Deleted classes can be restored within 14 days. After that they are permanently deleted, including server files. Downloaded files stay on devices.',
            ),
            if (!online)
              const Text('Connect to the internet to restore a class.'),
            if (sync.hasError)
              const Text('Could not refresh. Showing saved classes.'),
            TextButton(
              onPressed: online && _busy == null && !sync.isLoading
                  ? () => ref.read(classSyncProvider.notifier).refresh()
                  : null,
              child: const Text('Refresh'),
            ),
            ...rooms.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, _) => [
                const Text(
                  'Could not load deleted classes. Reopen this page to retry.',
                ),
              ],
              data: (items) => [
                if (items.isEmpty && !sync.isLoading && !sync.hasError)
                  const Text('No recently deleted classes.'),
                for (final room in items)
                  Builder(
                    builder: (_) {
                      final deadline = room.deletedAt!.toUtc().add(
                        const Duration(days: 14),
                      );
                      final eligible = DateTime.now().toUtc().isBefore(
                        deadline,
                      );
                      return ListTile(
                        title: Text(room.section),
                        subtitle: Text(
                          eligible
                              ? '${room.course}\nRestore before ${deadline.toLocal()}'
                              : '${room.course}\nRecovery expired',
                        ),
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: online && eligible && _busy == null
                              ? () => _restore(room)
                              : null,
                          child: Text(
                            _busy == room.id ? 'Restoring...' : 'Restore',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
