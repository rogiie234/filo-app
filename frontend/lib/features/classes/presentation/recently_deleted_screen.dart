import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
import '../../../data/local/app_database.dart';
import '../application/class_providers.dart';

class RecentlyDeletedScreen extends ConsumerStatefulWidget {
  const RecentlyDeletedScreen({super.key});
  @override
  ConsumerState<RecentlyDeletedScreen> createState() => _RecentlyDeletedState();
}

class _RecentlyDeletedState extends ConsumerState<RecentlyDeletedScreen> {
  String? _busy;
  final _purging = <String>{};
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

  Future<void> _deletePermanently(CacheClassesData room) async {
    if (_busy != null || ref.read(connectivityProvider).asData?.value != true)
      return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Permanently delete ${room.section}?',
      message: 'This permanently deletes this class, posts, submissions, quizzes, grades, and server files. It cannot be undone. Once deletion starts, this class cannot be restored, even if cleanup needs a retry. Downloaded files stay on devices.',
      confirmLabel: 'Confirm',
      confirmDestructive: true,
      confirmOutlined: true,
      cancelLabel: 'Cancel',
      cancelIsPrimary: true,
      icon: FiloIcons.delete,
    );
    if (!confirmed ||
        !mounted ||
        _busy != null ||
        ref.read(connectivityProvider).asData?.value != true)
      return;
    setState(() {
      _busy = room.id;
      _purging.add(room.id);
    });
    try {
      final response = await ref
          .read(supabaseClientProvider)
          .functions
          .invoke(
            'permanently-delete-class',
            body: {'class_id': room.id, 'section': room.section},
          );
      if (response.status != 200 ||
          response.data is! Map ||
          response.data['deleted'] != true) {
        throw StateError('Deletion not confirmed');
      }
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      await repository.sync();
      if (mounted) showMessage(context, 'Class permanently deleted.');
    } catch (_) {
      if (mounted)
        showMessage(
          context,
          'Permanent deletion could not be confirmed. Pull down to refresh, then retry Delete permanently. If deletion started, this class can no longer be restored.',
        );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: EntryBackground(verification: true, breeze: true),
          ),
          RefreshIndicator(
            onRefresh: () async {
              if (online && _busy == null) {
                if (rooms.hasError) ref.invalidate(deletedClassesProvider);
                await ref.read(classSyncProvider.notifier).refresh();
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(FiloSpacing.screen),
              children: [
                Text(
                  'Restore a class',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: FiloSpacing.s16),
                FiloPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FiloIcon(
                        FiloIcons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: FiloSpacing.s12),
                      const Expanded(
                        child: Text(
                          'Deleted classes can be restored within 14 days. After that they are permanently deleted, including server files. Downloaded files stay on devices.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FiloSpacing.s16),
                if (!online)
                  const Text('Connect to the internet to restore a class.'),
                if (sync.hasError)
                  const Text('Could not refresh. Showing saved classes.'),
                if (sync.isLoading)
                  const FiloLinearProgressIndicator(
                    semanticsLabel: 'Refreshing deleted classes',
                  ),
                ...rooms.when(
                  loading: () => [
                    const Center(child: FiloCircularProgressIndicator()),
                  ],
                  error: (_, _) => [
                    const Text(
                      'Could not load deleted classes. Pull down to retry.',
                    ),
                  ],
                  data: (items) => [
                    if (items.isEmpty && !sync.hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: FiloSpacing.screen,
                          ),
                          child: Column(
                            children: [
                              ExcludeSemantics(
                                child: Image.asset(
                                  'assets/illustrations/restore-empty.png',
                                  width: 360,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.restore_rounded,
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: FiloSpacing.s12),
                              const Text(
                                'No recently deleted classes.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final room in items)
                      Builder(
                        builder: (_) {
                          final deadline = room.deletedAt!.toUtc().add(
                            const Duration(days: 14),
                          );
                          final eligible = DateTime.now().toUtc().isBefore(
                            deadline,
                          );
                          final localDeadline = deadline.toLocal();
                          final locale = MaterialLocalizations.of(context);
                          final deadlineLabel =
                              '${locale.formatMediumDate(localDeadline)} \u00b7 ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(localDeadline), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: FiloSpacing.s16,
                            ),
                            child: FiloPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    room.section,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: FiloSpacing.s4),
                                  Text(
                                    room.course,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  const SizedBox(height: FiloSpacing.s12),
                                  Row(
                                    children: [
                                      ExcludeSemantics(
                                        child: FiloIcon(
                                          FiloIcons.calendar,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: FiloSpacing.s8),
                                      Expanded(
                                        child: Text(
                                          eligible
                                              ? 'Restore before $deadlineLabel'
                                              : 'Recovery expired',
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
                                  const SizedBox(height: FiloSpacing.s16),
                                  FiloButton(
                                    label:
                                        _busy == room.id &&
                                            !_purging.contains(room.id)
                                        ? 'Restoring...'
                                        : 'Restore',
                                    labelVariants: const [
                                      'Restore',
                                      'Restoring...',
                                    ],
                                    minHeight: 64,
                                    busy:
                                        _busy == room.id &&
                                        !_purging.contains(room.id),
                                    onPressed:
                                        online &&
                                            eligible &&
                                            _busy == null &&
                                            !_purging.contains(room.id)
                                        ? () => _restore(room)
                                        : null,
                                  ),
                                  const SizedBox(height: FiloSpacing.s8),
                                  FiloButton(
                                    label:
                                        _busy == room.id &&
                                            _purging.contains(room.id)
                                        ? 'Deleting...'
                                        : 'Delete permanently',
                                    busy:
                                        _busy == room.id &&
                                        _purging.contains(room.id),
                                    minHeight: 64,
                                    destructive: true,
                                    outlined: true,
                                    onPressed: online && _busy == null
                                        ? () => _deletePermanently(room)
                                        : null,
                                  ),
                                ],
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
        ],
      ),
    );
  }
}
