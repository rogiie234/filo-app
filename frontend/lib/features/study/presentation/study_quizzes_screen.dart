import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
import '../../../data/local/database_providers.dart';
import '../application/student_ai_providers.dart';
import '../application/study_quiz_sessions.dart';
import '../application/study_providers.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import '../domain/study_inputs.dart';
import 'study_quiz_scope.dart';
import 'study_quiz_play_screen.dart';
import 'study_privacy.dart';
import 'study_widgets.dart';

String quizTypeLabel(String type) => switch (type) {
  'multiple_choice' => 'Multiple choice',
  'true_false' => 'True or false',
  _ => 'Identification',
};

class StudyQuizzesScreen extends StatelessWidget {
  const StudyQuizzesScreen({super.key, required this.notebookId});
  final String notebookId;
  void _generate(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => StudyQuizGenerateScreen(notebookId: notebookId),
    ),
  );
  @override
  Widget build(BuildContext context) => StudyQuizScope(
    notebookId: notebookId,
    builder: (repo) => Consumer(
      builder: (context, ref, _) {
        final quizzes = ref.watch(studyQuizzesProvider(notebookId));
        final showAdd =
            quizzes.hasValue &&
            !quizzes.isLoading &&
            !quizzes.hasError &&
            quizzes.requireValue.isNotEmpty;
        return EntryBackground(
          variation: 4,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: showAdd
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 72,
                      child: FiloButton(
                        label: 'Generate practice quiz',
                        icon: FiloIcons.add,
                        iconOnly: true,
                        minHeight: 72,
                        onPressed: () => _generate(context),
                      ),
                    ),
                  )
                : null,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Practice quiz'),
            ),
            body: SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  FiloSpacing.screen,
                  FiloSpacing.screen,
                  FiloSpacing.screen,
                  showAdd ? 120 : FiloSpacing.screen,
                ),
                children: [
                  const StudyOfflineBanner(),
                  studyAsync(
                    quizzes,
                    (quizzes) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudyCollectionHeader(
                          title: 'Make room for practice.',
                          body: 'Try a question, check your understanding, and revisit it at your own pace.',
                          icon: FiloIcons.assessment,
                          summary:
                              '${studyCount(quizzes.length, 'quiz')} saved on this device',
                        ),
                        if (quizzes.isEmpty)
                          EmptyState(
                            primaryAction: EmptyStateAction(
                              label: 'Generate practice quiz',
                              onPressed: () => _generate(context),
                            ),
                            title: 'No practice quizzes yet',
                            body: 'Generate a quiz from your sources or a topic to start practicing.',
                            pose: 'reading',
                          ),
                        for (final quiz in quizzes)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: FiloSpacing.s12,
                            ),
                            child: FiloPanel(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(
                                  FiloSpacing.s16,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(
                                    FiloSpacing.s12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      FiloRadii.medium,
                                    ),
                                  ),
                                  child: FiloIcon(
                                    FiloIcons.assessment,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                title: Text(
                                  quiz.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                subtitle: studyAsync(
                                  ref.watch(studyQuestionsProvider(quiz.id)),
                                  (questions) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studyCount(
                                          questions.length,
                                          'question',
                                        ),
                                      ),
                                      const SizedBox(height: FiloSpacing.s12),
                                      Text(
                                        'Start practice',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  retry: () => ref.invalidate(
                                    studyQuestionsProvider(quiz.id),
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => StudyQuizPlayScreen(
                                      notebookId: notebookId,
                                      quizId: quiz.id,
                                    ),
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Options for ${quiz.title}',
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'history',
                                      child: Text('History'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete quiz'),
                                    ),
                                  ],
                                  onSelected: (action) async {
                                    if (action == 'history') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              StudyQuizHistoryScreen(
                                                notebookId: notebookId,
                                                quizId: quiz.id,
                                              ),
                                        ),
                                      );
                                      return;
                                    }
                                    final confirmed =
                                        await showFiloConfirmation(
                                          context,
                                          title: 'Delete this quiz?',
                                          message: 'This quiz, its questions and all its attempts will be deleted from this device.',
                                          confirmLabel: 'Delete quiz',
                                          cancelLabel: 'Cancel',
                                          confirmDestructive: true,
                                          icon: FiloIcons.delete,
                                        );
                                    if (!confirmed ||
                                        !context.mounted ||
                                        ref
                                                .read(accountDatabaseProvider)
                                                .asData
                                                ?.value !=
                                            repo.db) {
                                      return;
                                    }
                                    try {
                                      await repo.delete(quiz.id);
                                    } catch (_) {
                                      if (context.mounted) {
                                        showMessage(
                                          context,
                                          'Could not delete this quiz. Try again.',
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    retry: () =>
                        ref.invalidate(studyQuizzesProvider(notebookId)),
                    showMascot: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class StudyQuizGenerateScreen extends StatelessWidget {
  const StudyQuizGenerateScreen({super.key, required this.notebookId});
  final String notebookId;
  @override
  Widget build(BuildContext context) => StudyQuizScope(
    notebookId: notebookId,
    builder: (repo) => _QuizGenerateBody(
      key: ObjectKey(repo.db),
      notebookId: notebookId,
      repository: repo,
    ),
  );
}

class _QuizGenerateBody extends ConsumerStatefulWidget {
  const _QuizGenerateBody({
    super.key,
    required this.notebookId,
    required this.repository,
  });
  final String notebookId;
  final StudyQuizRepository repository;
  @override
  ConsumerState<_QuizGenerateBody> createState() => _QuizGenerateBodyState();
}

class _QuizGenerateBodyState extends ConsumerState<_QuizGenerateBody> {
  final _errorToast = StudyErrorToast();
  late final StudyQuizGeneration _session;
  final _topic = TextEditingController();
  final _types = studyQuestionTypes.toSet();
  int _count = 10;
  bool _authorizing = false, _allowPop = false;
  @override
  void initState() {
    super.initState();
    _session = StudyQuizGeneration(
      notebookId: widget.notebookId,
      repository: widget.repository,
      client: ref.read(studentAiClientProvider),
      isCurrent: () =>
          mounted &&
          ref.read(accountDatabaseProvider).asData?.value ==
              widget.repository.db,
      isOnline: () => ref.read(connectivityProvider).asData?.value == true,
    )..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    _errorToast.update(
      context,
      _session.error,
      isCurrent: () =>
          ref.read(accountDatabaseProvider).asData?.value ==
          widget.repository.db,
    );
    setState(() {});
    if (_session.savedId == null || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ref.read(accountDatabaseProvider).asData?.value !=
              widget.repository.db) {
        return;
      }
      final result = _session.result!;
      final message = [
        'Practice quiz created.',
        if (result.value.dropped > 0)
          '${result.value.dropped} invalid ${result.value.dropped == 1 ? 'question was' : 'questions were'} dropped.',
        if (result.value.missing > 0)
          '${result.value.missing} requested ${result.value.missing == 1 ? 'question was' : 'questions were'} not returned.',
        if (result.truncated) 'Some source text was shortened.',
      ].join('\n');
      showFiloToast(context, message, kind: FiloToastKind.success);
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => StudyQuizzesScreen(notebookId: widget.notebookId),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_session.working && ref.read(aiRequestGuardProvider).isBusy) {
      showFiloToast(
        context,
        studyAiMessages['AI_IN_PROGRESS']!,
        kind: FiloToastKind.error,
      );
      return;
    }
    if (_session.working || _authorizing) return;
    setState(() => _authorizing = true);
    try {
      if (await ensureStudyPrivacy(context, ref) && mounted) {
        await _session.generate(
          StudyQuizSettings(
            count: _count,
            types: _types.toList(),
            topicFocus: _topic.text.trim(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(studySourcesProvider(widget.notebookId));
    final quizzes = ref.watch(studyQuizzesProvider(widget.notebookId));
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final guard = ref.watch(aiRequestGuardProvider);
    ref.watch(aiRequestBusyProvider);
    final result = _session.result;
    final reason = _types.isEmpty
        ? 'Choose at least one question type.'
        : !online
        ? studyAiMessages['OFFLINE']
        : guard.isBusy && !_session.working
        ? studyAiMessages['AI_IN_PROGRESS']
        : sources.isLoading || quizzes.isLoading
        ? 'Loading notebook...'
        : sources.hasError || quizzes.hasError
        ? studyAiMessages['LOAD_FAILED']
        : quizzes.requireValue.length >= 10
        ? studyQuizLimitMessage
        : sources.requireValue.isEmpty && _topic.text.trim().isEmpty
        ? 'Enter a topic when your notebook has no sources.'
        : sources.requireValue.any((s) => s.extractedText.trim().isEmpty)
        ? studyAiMessages['NO_TEXT']
        : null;
    return PopScope(
      canPop: _allowPop || (!_session.hasUnsaved && !_session.saving),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _session.saving) return;
        if (await showFiloConfirmation(
              context,
              title: 'Leave without saving this quiz?',
              message: 'These questions have not been confirmed saved. Leaving may lose them.',
              confirmLabel: 'Leave',
              cancelLabel: 'Keep open',
            ) &&
            mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: EntryBackground(
        variation: 4,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Generate practice quiz'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(FiloSpacing.screen),
              children: [
                const StudyOfflineBanner(),
                if (result == null) ...[
                  FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'How many questions?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: FiloSpacing.s16),
                        Wrap(
                          spacing: FiloSpacing.s8,
                          runSpacing: FiloSpacing.s8,
                          children: [
                            for (final count in [5, 10, 15, 20])
                              FiloFilterChip(
                                label: '$count questions',
                                selected: _count == count,
                                onSelected: _session.working || _authorizing
                                    ? null
                                    : (_) => setState(() => _count = count),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.s16),
                  FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Question types',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: FiloSpacing.s8),
                        for (final type in studyQuestionTypes)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(quizTypeLabel(type)),
                            value: _types.contains(type),
                            onChanged: _session.working || _authorizing
                                ? null
                                : (selected) => setState(() {
                                    if (selected == true) {
                                      _types.add(type);
                                    } else {
                                      _types.remove(type);
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.s16),
                  FiloPanel(
                    child: TextField(
                      controller: _topic,
                      enabled: !_session.working && !_authorizing,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Topic (optional with sources)',
                        alignLabelWithHint: true,
                        counterText:
                            '${_topic.text.runes.length}/200 characters',
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (old, next) =>
                              next.text.runes.length <= 200 ? next : old,
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
                const SizedBox(height: FiloSpacing.s16),
                if (_session.working) ...[
                  StudyGenerationStatus(
                    label: _session.saving
                        ? 'Saving quiz...'
                        : 'Preparing your practice quiz...',
                    saving: _session.saving,
                    onCancel: _session.cancel,
                  ),
                ] else if (result == null)
                  FiloButton(
                    label: 'Generate',
                    icon: FiloIcons.sparkle,
                    onPressed:
                        !_authorizing &&
                            (reason == null ||
                                reason == studyAiMessages['AI_IN_PROGRESS'])
                        ? _generate
                        : null,
                  ),
                if (reason != null &&
                    reason != studyAiMessages['AI_IN_PROGRESS'] &&
                    reason != studyAiMessages['OFFLINE'] &&
                    result == null)
                  Padding(
                    padding: const EdgeInsets.only(top: FiloSpacing.s12),
                    child: Text(reason),
                  ),
                if (sources.hasError || quizzes.hasError)
                  TextButton(
                    onPressed: () {
                      ref.invalidate(studySourcesProvider(widget.notebookId));
                      ref.invalidate(studyQuizzesProvider(widget.notebookId));
                    },
                    child: const Text('Retry loading notebook'),
                  ),
                if (result != null) ...[
                  const SizedBox(height: FiloSpacing.s16),
                  Text(
                    _session.savedId == null
                        ? 'Quiz not confirmed saved'
                        : 'Quiz saved.',
                  ),
                  Text(
                    '${studyCount(result.value.items.length, 'question')} prepared.',
                  ),
                  if (result.value.dropped > 0)
                    Text(
                      '${result.value.dropped} invalid ${result.value.dropped == 1 ? 'question was' : 'questions were'} dropped.',
                    ),
                  if (result.value.missing > 0)
                    Text(
                      '${result.value.missing} requested ${result.value.missing == 1 ? 'question was' : 'questions were'} not returned.',
                    ),
                  for (final usage in result.sources.usage)
                    if (usage.truncated)
                      Text(
                        'Only the first ${usage.retainedCharacters} characters of ${usage.name} were used.',
                      ),
                  const SizedBox(height: FiloSpacing.s16),
                  if (_session.hasUnsaved)
                    ExpansionTile(
                      title: const Text('Prepared questions'),
                      children: [
                        for (final question in result.value.items)
                          ListTile(
                            title: Text(question.prompt),
                            subtitle: Text(question.explanation),
                          ),
                      ],
                    ),
                  if (_session.hasUnsaved && !_session.working)
                    FiloButton(
                      label: 'Try saving again',
                      onPressed: _session.retrySave,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
