import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
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
  @override
  Widget build(BuildContext context) => StudyQuizScope(
    notebookId: notebookId,
    builder: (repo) => Consumer(
      builder: (context, ref, _) => Scaffold(
        appBar: AppBar(title: const Text('Practice quiz')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FiloSpacing.screen),
            children: [
              const StudyOfflineBanner(),
              studyAsync(
                ref.watch(studyQuizzesProvider(notebookId)),
                (quizzes) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FiloButton(
                      label: 'Generate practice quiz',
                      icon: FiloIcons.sparkle,
                      onPressed: quizzes.length >= 10
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StudyQuizGenerateScreen(
                                  notebookId: notebookId,
                                ),
                              ),
                            ),
                    ),
                    if (quizzes.length >= 10) const Text(studyQuizLimitMessage),
                    const SizedBox(height: FiloSpacing.screen),
                    if (quizzes.isEmpty)
                      const EmptyState(
                        title: 'No practice quizzes saved yet.',
                        pose: 'reading',
                      ),
                    for (final quiz in quizzes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
                        child: FiloPanel(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(
                              FiloSpacing.s16,
                            ),
                            title: Text(quiz.title),
                            subtitle: studyAsync(
                              ref.watch(studyQuestionsProvider(quiz.id)),
                              (questions) => Text(
                                studyCount(questions.length, 'question'),
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
                                      builder: (_) => StudyQuizHistoryScreen(
                                        notebookId: notebookId,
                                        quizId: quiz.id,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final confirmed = await showFiloConfirmation(
                                  context,
                                  title: 'Delete this quiz?',
                                  message: 'This quiz, its questions and all its attempts will be deleted from this device.',
                                  confirmLabel: 'Delete quiz',
                                  cancelLabel: 'Cancel',
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
                retry: () => ref.invalidate(studyQuizzesProvider(notebookId)),
                showMascot: true,
              ),
              const SizedBox(height: FiloSpacing.s16),
              const Text('AI can make mistakes. Check important answers.'),
            ],
          ),
        ),
      ),
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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
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
      child: Scaffold(
        appBar: AppBar(title: const Text('Generate practice quiz')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FiloSpacing.screen),
            children: [
              const StudyOfflineBanner(),
              if (result == null) ...[
                const Text('How many questions?'),
                const SizedBox(height: FiloSpacing.s8),
                DropdownButtonFormField<int>(
                  initialValue: _count,
                  decoration: const InputDecoration(
                    labelText: 'Number of questions',
                  ),
                  items: [
                    for (final i in [5, 10, 15, 20])
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: _session.working || _authorizing
                      ? null
                      : (value) => setState(() => _count = value!),
                ),
                for (final type in studyQuestionTypes)
                  CheckboxListTile(
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
                const SizedBox(height: FiloSpacing.s16),
                TextField(
                  controller: _topic,
                  enabled: !_session.working && !_authorizing,
                  decoration: const InputDecoration(
                    labelText: 'Topic (optional with sources)',
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (old, next) => next.text.runes.length <= 200 ? next : old,
                    ),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                Text('${_topic.text.runes.length}/200 characters'),
                const SizedBox(height: FiloSpacing.screen),
              ],
              if (_session.working) ...[
                if (!_session.saving) const Mascot(pose: 'thinking', size: 120),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _session.saving
                        ? 'Saving quiz...'
                        : 'Preparing your practice quiz...',
                  ),
                ),
                if (!MediaQuery.disableAnimationsOf(context))
                  const Padding(
                    padding: EdgeInsets.all(FiloSpacing.s16),
                    child: Center(
                      child: FiloCircularProgressIndicator(
                        semanticsLabel: 'Preparing practice quiz',
                      ),
                    ),
                  ),
                if (!_session.saving)
                  FiloButton(label: 'Cancel', onPressed: _session.cancel),
                const Text(
                  'Cancel stops waiting on this phone. The server may still finish.',
                ),
              ] else if (result == null)
                FiloButton(
                  label: 'Generate',
                  icon: FiloIcons.sparkle,
                  onPressed: reason == null && !_authorizing ? _generate : null,
                ),
              if (reason != null && result == null)
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
                if (_session.savedId != null)
                  FiloButton(
                    label: 'Take quiz',
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => StudyQuizPlayScreen(
                          notebookId: widget.notebookId,
                          quizId: _session.savedId!,
                        ),
                      ),
                    ),
                  ),
              ],
              if (_session.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: FiloSpacing.s16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_session.error!),
                  ),
                ),
              const SizedBox(height: FiloSpacing.s16),
              const Text('AI can make mistakes. Check important answers.'),
            ],
          ),
        ),
      ),
    );
  }
}
