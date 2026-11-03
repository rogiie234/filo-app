import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../application/study_providers.dart';

String studyCount(int count, String noun) =>
    '$count ${count == 1
        ? noun
        : noun == 'quiz'
        ? 'quizzes'
        : '${noun}s'}';

Widget studyAsync<T>(
  AsyncValue<T> value,
  Widget Function(T) builder, {
  VoidCallback? retry,
  bool showMascot = false,
}) {
  // Never render stale account data while its replacement is loading or failing.
  if (value.isLoading)
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: FiloCircularProgressIndicator(
          semanticsLabel: 'Loading saved study content',
        ),
      ),
    );
  if (value.hasError && showMascot)
    return SingleChildScrollView(
      child: EmptyState(
        title: 'Could not read saved study content. Try again.',
        pose: 'confused',
        bob: false,
        action: retry == null
            ? null
            : TextButton(onPressed: retry, child: const Text('Retry')),
      ),
    );
  if (value.hasError)
    return FiloPanel(
      child: Column(
        children: [
          const Text('Could not read saved study content. Try again.'),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  return builder(value.requireValue);
}

class StudyOfflineBanner extends ConsumerWidget {
  const StudyOfflineBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(connectivityProvider).asData?.value == false
      ? const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: OfflineBanner(),
        )
      : const SizedBox.shrink();
}

Future<String?> notebookName(BuildContext context, {String? initial}) =>
    showFiloDialog<String>(
      context: context,
      builder: (_) => _NotebookNameDialog(initial: initial),
    );

class _NotebookNameDialog extends StatefulWidget {
  const _NotebookNameDialog({this.initial});
  final String? initial;
  @override
  State<_NotebookNameDialog> createState() => _NotebookNameDialogState();
}

class _NotebookNameDialogState extends State<_NotebookNameDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'New notebook' : 'Rename'),
    scrollable: true,
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 255,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Notebook name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, __) => FilledButton(
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, value.text.trim()),
          child: Text(widget.initial == null ? 'Create notebook' : 'Save'),
        ),
      ),
    ],
  );
}

Future<bool> editNotebook(
  BuildContext context,
  WidgetRef ref,
  StudyNotebook notebook,
  String action,
) async {
  try {
    final repo = await ref.read(notebookRepositoryProvider.future);
    if (repo == null || !context.mounted) return false;
    if (action == 'rename') {
      final name = await notebookName(context, initial: notebook.name);
      if (name == null ||
          !context.mounted ||
          ref.read(accountDatabaseProvider).asData?.value != repo.db)
        return false;
      await repo.rename(notebook.id, name);
    } else if (action == 'delete') {
      final confirmed = await showFiloConfirmation(
        context,
        title: 'Delete notebook?',
        message: 'Delete this notebook and everything in it? Your original files are not affected.',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
        icon: FiloIcons.delete,
      );
      if (!confirmed ||
          !context.mounted ||
          ref.read(accountDatabaseProvider).asData?.value != repo.db)
        return false;
      await repo.delete(notebook.id);
      return context.mounted &&
          ref.read(accountDatabaseProvider).asData?.value == repo.db;
    }
  } catch (_) {
    if (context.mounted)
      showMessage(context, 'Could not update this notebook. Try again.');
  }
  return false;
}

IconData studyFileIcon(String name) => FiloFileDetails.fromName(name).type.icon;
