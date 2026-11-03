import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../application/study_providers.dart';
import '../domain/study_inputs.dart';
import 'study_notebook_screen.dart';
import 'study_widgets.dart';
import '../../notifications/presentation/study_alarms_screen.dart';

class StudyHomeScreen extends ConsumerStatefulWidget {
  const StudyHomeScreen({super.key});
  @override
  ConsumerState<StudyHomeScreen> createState() => _StudyHomeScreenState();
}

class _StudyHomeScreenState extends ConsumerState<StudyHomeScreen> {
  bool _creating = false;
  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final repo = await ref.read(notebookRepositoryProvider.future);
      if (!mounted || repo == null) return;
      if ((ref.read(studyNotebooksProvider).asData?.value.length ?? 0) >= 20) {
        showMessage(
          context,
          'You can have up to 20 notebooks. Delete one to add another.',
        );
        return;
      }
      final name = await notebookName(context);
      if (!mounted ||
          name == null ||
          ref.read(accountDatabaseProvider).asData?.value != repo.db)
        return;
      final id = await repo.create(name);
      if (!mounted ||
          ref.read(accountDatabaseProvider).asData?.value != repo.db)
        return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudyNotebookScreen(notebookId: id),
        ),
      );
    } on StudyLimitExceeded {
      if (mounted)
        showMessage(
          context,
          'You can have up to 20 notebooks. Delete one to add another.',
        );
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not create this notebook. Try again.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notebooks = ref.watch(studyNotebooksProvider);
    return FiloFirstListLoad(
      id: 'study',
      hasItems: notebooks.asData?.value.isNotEmpty ?? false,
      ready: notebooks.hasValue && !notebooks.isLoading && !notebooks.hasError,
      child: ListView(
        padding: const EdgeInsets.all(FiloSpacing.screen),
        children: [
          const StudyOfflineBanner(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI Study',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Study alarms',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const StudyAlarmsScreen(),
                  ),
                ),
                icon: const Icon(Icons.alarm),
              ),
            ],
          ),
          const SizedBox(height: FiloSpacing.s16),
          FiloButton(
            label: 'New notebook',
            icon: FiloIcons.add,
            onPressed:
                _creating ||
                    notebooks.isLoading ||
                    !notebooks.hasValue ||
                    notebooks.hasError
                ? null
                : _create,
          ),
          const SizedBox(height: FiloSpacing.screen),
          studyAsync(
            notebooks,
            (items) => Column(
              children: [
                if (items.isEmpty)
                  const EmptyState(
                    pose: 'reading',
                    title: 'Start your first notebook.',
                    message: 'Keep your files and study tools together.',
                  ),
                for (final notebook in items)
                  FiloListItem(
                    index: items.indexOf(notebook),
                    child: _NotebookTile(notebook: notebook),
                  ),
              ],
            ),
            retry: () => ref.invalidate(studyNotebooksProvider),
            showMascot: true,
          ),
        ],
      ),
    );
  }
}

class _NotebookTile extends ConsumerWidget {
  const _NotebookTile({required this.notebook});
  final StudyNotebook notebook;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(studySourcesProvider(notebook.id));
    return FiloCardTap(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
        child: FiloPanel(
          padding: const EdgeInsets.symmetric(
            vertical: FiloSpacing.s8,
            horizontal: FiloSpacing.s4,
          ),
          child: ListTile(
            leading: const FiloIcon(FiloIcons.folder),
            title: Text(notebook.name),
            subtitle: Text(
              '${sources.isLoading
                  ? 'Loading sources...'
                  : sources.hasError
                  ? 'Sources unavailable'
                  : studyCount(sources.requireValue.length, 'source')}\nLast opened ${MaterialLocalizations.of(context).formatMediumDate(notebook.lastOpenedAt.toLocal())}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Notebook options',
              onSelected: (action) =>
                  editNotebook(context, ref, notebook, action),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StudyNotebookScreen(notebookId: notebook.id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
