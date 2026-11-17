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
  if (value.isLoading) {
    return const Padding(
      padding: EdgeInsets.all(FiloSpacing.screen),
      child: Center(
        child: FiloCircularProgressIndicator(
          semanticsLabel: 'Loading saved study content',
        ),
      ),
    );
  }
  if (value.hasError) {
    return EmptyState(
      title: 'Study content unavailable',
      body: 'Retry to read study content saved on this device.',
      pose: 'confused',
      showMascot: showMascot,
      primaryAction: retry == null
          ? null
          : EmptyStateAction(label: 'Retry', onPressed: retry),
    );
  }
  return builder(value.requireValue);
}

class StudyErrorToast {
  String? _lastMessage;

  void update(
    BuildContext context,
    String? message, {
    required bool Function() isCurrent,
  }) {
    if (message == _lastMessage) return;
    _lastMessage = message;
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && isCurrent() && _lastMessage == message) {
        showFiloToast(context, message, kind: FiloToastKind.error);
      }
    });
  }
}

class StudyGenerationStatus extends StatelessWidget {
  const StudyGenerationStatus({
    super.key,
    required this.label,
    required this.saving,
    required this.onCancel,
  });

  final String label;
  final bool saving;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => FiloPanel(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: FiloIcon(
            saving ? FiloIcons.save : FiloIcons.sparkle,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: FiloSpacing.s16),
        Semantics(
          liveRegion: true,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: FiloSpacing.s16),
        FiloLinearProgressIndicator(
          semanticsLabel: label,
          minHeight: 6,
          borderRadius: BorderRadius.circular(FiloRadii.large),
        ),
        if (!saving) ...[
          const SizedBox(height: FiloSpacing.screen),
          FiloButton(label: 'Cancel', secondary: true, onPressed: onCancel),
          const SizedBox(height: FiloSpacing.s12),
          Text(
            'Cancel stops waiting on this phone. The server may still finish.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ],
    ),
  );
}

class StudyOfflineBanner extends ConsumerWidget {
  const StudyOfflineBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(connectivityProvider).asData?.value == false
      ? const Padding(
          padding: EdgeInsets.only(bottom: FiloSpacing.s16),
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
  Widget build(BuildContext context) => FiloModalDialog(
    title: widget.initial == null ? 'New notebook' : 'Rename',
    icon: FiloIcons.book,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.initial == null) ...[
          const Text('Keep your files and study tools together.'),
          const SizedBox(height: FiloSpacing.s16),
        ],
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notebook name'),
        ),
      ],
    ),
    actions: [
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) => FiloButton(
          label: widget.initial == null ? 'Create notebook' : 'Save',
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, value.text.trim()),
        ),
      ),
      FiloButton(
        secondary: true,
        label: 'Cancel',
        onPressed: () => Navigator.pop(context),
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
          ref.read(accountDatabaseProvider).asData?.value != repo.db) {
        return false;
      }
      await repo.rename(notebook.id, name);
    } else if (action == 'delete') {
      final confirmed = await showFiloConfirmation(
        context,
        title: 'Delete notebook?',
        message: 'Delete this notebook and everything in it? Your original files are not affected.',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
        confirmDestructive: true,
        icon: FiloIcons.delete,
      );
      if (!confirmed ||
          !context.mounted ||
          ref.read(accountDatabaseProvider).asData?.value != repo.db) {
        return false;
      }
      await repo.delete(notebook.id);
      return context.mounted &&
          ref.read(accountDatabaseProvider).asData?.value == repo.db;
    }
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not update this notebook. Try again.');
    }
  }
  return false;
}

IconData studyFileIcon(String name) => FiloFileDetails.fromName(name).type.icon;

/// Shared introduction for the on-device study collections and reminders.
class StudyCollectionHeader extends StatelessWidget {
  const StudyCollectionHeader({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.summary,
  });
  final String title, body;
  final IconData icon;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FiloSpacing.screen),
      child: FiloPanel(
        color: theme.colorScheme.primaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(FiloRadii.medium),
                ),
                child: FiloIcon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: FiloSpacing.s16),
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: FiloSpacing.s8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: FiloSpacing.s16),
              Text(
                summary!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
