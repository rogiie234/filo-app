import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/database_providers.dart';
import '../application/study_providers.dart';
import '../application/study_source_reader.dart';
import 'study_privacy.dart';
import 'study_source_picker.dart';
import 'study_saved_screen.dart';
import 'study_quizzes_screen.dart';
import 'study_chat_screen.dart';
import 'study_summary_screen.dart';
import 'study_decks_screen.dart';
import 'study_widgets.dart';

class StudyNotebookScreen extends ConsumerStatefulWidget {
  const StudyNotebookScreen({super.key, required this.notebookId});
  final String notebookId;
  @override
  ConsumerState<StudyNotebookScreen> createState() =>
      _StudyNotebookScreenState();
}

class _StudyNotebookScreenState extends ConsumerState<StudyNotebookScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      try {
        final repo = await ref.read(notebookRepositoryProvider.future);
        if (mounted) await repo?.markOpened(widget.notebookId);
      } catch (_) {
        if (mounted)
          showMessage(context, 'Could not update the last-opened time.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.notebookId;
    return Scaffold(
      body: SafeArea(
        child: studyAsync(
          ref.watch(studyNotebooksProvider),
          (notebooks) {
            final matches = notebooks.where((n) => n.id == id);
            if (matches.isEmpty)
              return Column(
                children: [
                  AppBar(title: const Text('Notebook')),
                  const Padding(
                    padding: EdgeInsets.all(FiloSpacing.screen),
                    child: EmptyState(
                      title: 'This notebook is no longer available.',
                      pose: 'confused',
                      bob: false,
                    ),
                  ),
                ],
              );
            final notebook = matches.first;
            return Column(
              children: [
                AppBar(
                  title: Text(notebook.name),
                  actions: [
                    PopupMenuButton<String>(
                      tooltip: 'Notebook options',
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                        PopupMenuItem(
                          value: 'privacy',
                          child: Text('AI Study privacy'),
                        ),
                      ],
                      onSelected: (action) async {
                        if (action == 'privacy') {
                          await ensureStudyPrivacy(
                            context,
                            ref,
                            showAgain: true,
                          );
                          return;
                        }
                        final deleted = await editNotebook(
                          context,
                          ref,
                          notebook,
                          action,
                        );
                        if (deleted && context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(FiloSpacing.screen),
                    children: [
                      const StudyOfflineBanner(),
                      studyAsync(ref.watch(studySourcesProvider(id)), (
                        sources,
                      ) {
                        final missing = ref.watch(
                          studyMissingSourcesProvider(id),
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (sources.isEmpty)
                              const EmptyState(
                                title: 'General knowledge',
                                pose: 'reading',
                              )
                            else
                              Text(
                                'Answers use your files',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            const SizedBox(height: FiloSpacing.s12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final source in sources)
                                  Tooltip(
                                    message: 'Remove source ${source.name}',
                                    child: ActionChip(
                                      label: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(context).width -
                                              160,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FiloFileTypeTile(
                                              details: FiloFileDetails.fromName(
                                                source.name,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: FiloSpacing.s8,
                                            ),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    source.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  FiloFileTypeLabel(
                                                    details:
                                                        FiloFileDetails.fromName(
                                                          source.name,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.padded,
                                      onPressed: () => _remove(source.id),
                                    ),
                                  ),
                              ],
                            ),
                            if (sources.isNotEmpty)
                              const Text('Tap a source to remove it.'),
                            if (missing.asData?.value.isNotEmpty == true)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: FiloSpacing.s12,
                                ),
                                child: Text(
                                  'An original file is no longer on this phone. Its saved text is still available.',
                                ),
                              ),
                            if (missing.hasError)
                              const Text(
                                'Could not check original files. Saved text is still available.',
                              ),
                            const SizedBox(height: FiloSpacing.s12),
                            FiloButton(
                              label: 'Add files',
                              icon: FiloIcons.add,
                              onPressed: () {
                                if (sources.length >= 3) {
                                  showMessage(context, studySourceLimitMessage);
                                  return;
                                }
                                showStudySourcePicker(context, id).then((_) {
                                  if (mounted)
                                    ref.invalidate(
                                      studyMissingSourcesProvider(id),
                                    );
                                });
                              },
                            ),
                          ],
                        );
                      }, retry: () => ref.invalidate(studySourcesProvider(id))),
                      const SizedBox(height: FiloSpacing.screen),
                      for (final tool in StudyTool.values)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: FiloSpacing.s12,
                          ),
                          child: FiloPanel(
                            padding: const EdgeInsets.symmetric(
                              vertical: FiloSpacing.s12,
                              horizontal: FiloSpacing.s4,
                            ),
                            child: ListTile(
                              leading: const FiloIcon(FiloIcons.sparkle),
                              title: Text(tool.label),
                              subtitle: Text(savedCount(ref, tool, id)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => tool == StudyTool.chat
                                      ? StudyChatScreen(notebookId: id)
                                      : tool == StudyTool.summary
                                      ? StudySummaryScreen(notebookId: id)
                                      : tool == StudyTool.decks
                                      ? StudyDecksScreen(notebookId: id)
                                      : StudyQuizzesScreen(notebookId: id),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Text(
                        'AI can make mistakes. Check important answers.',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          retry: () => ref.invalidate(studyNotebooksProvider),
          showMascot: true,
        ),
      ),
    );
  }

  Future<void> _remove(String sourceId) async {
    try {
      final repo = await ref.read(notebookSourceRepositoryProvider.future);
      if (!mounted ||
          repo == null ||
          ref.read(accountDatabaseProvider).asData?.value != repo.db)
        return;
      await repo.remove(sourceId);
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not remove this source. Try again.');
    }
  }
}
