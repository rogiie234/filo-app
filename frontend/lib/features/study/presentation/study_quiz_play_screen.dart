import '../../../core/widgets/entry_background.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../application/study_quiz_sessions.dart';
import '../application/study_providers.dart';
import '../data/study_repositories.dart';
import 'study_quiz_scope.dart';
import 'study_widgets.dart';

class StudyQuizPlayScreen extends StatelessWidget {
  const StudyQuizPlayScreen({
    super.key,
    required this.notebookId,
    required this.quizId,
  });
  final String notebookId, quizId;
  @override
  Widget build(BuildContext context) => StudyQuizScope(
    notebookId: notebookId,
    builder: (repo) => Consumer(
      builder: (context, ref, _) => studyQuizAvailable(
        ref,
        notebookId,
        quizId,
        () => _QuizPlayer(
          key: ObjectKey(repo.db),
          notebookId: notebookId,
          quizId: quizId,
          repository: StudyAttemptRepository(repo.db),
        ),
      ),
    ),
  );
}

Widget studyQuizAvailable(
  WidgetRef ref,
  String notebookId,
  String quizId,
  Widget Function() child,
) => studyAsync(
  ref.watch(studyQuizzesProvider(notebookId)),
  (quizzes) => quizzes.any((q) => q.id == quizId)
      ? child()
      : EntryBackground(
          verification: true,
          breeze: true,
          variation: 0,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Practice quiz'),
            ),
            body: const Center(
              child: EmptyState(
                title: 'Quiz unavailable',
                body: 'Return to your quizzes to choose another one.',
                pose: 'waiting',
              ),
            ),
          ),
        ),
  retry: () => ref.invalidate(studyQuizzesProvider(notebookId)),
);

class _QuizPlayer extends ConsumerStatefulWidget {
  const _QuizPlayer({
    super.key,
    required this.notebookId,
    required this.quizId,
    required this.repository,
  });
  final String notebookId, quizId;
  final StudyAttemptRepository repository;
  @override
  ConsumerState<_QuizPlayer> createState() => _QuizPlayerState();
}

class _QuizPlayerState extends ConsumerState<_QuizPlayer> {
  final _errorToast = StudyErrorToast();
  late final StudyQuizSession _session;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _allowPop = false, _confirming = false;
  @override
  void initState() {
    super.initState();
    _session = StudyQuizSession(
      notebookId: widget.notebookId,
      quizId: widget.quizId,
      repository: widget.repository,
      isCurrent: () =>
          mounted &&
          ref.read(accountDatabaseProvider).asData?.value ==
              widget.repository.db,
    )..addListener(_changed);
    _session.open();
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
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _leave() async {
    if (_confirming || _session.saving) return;
    _confirming = true;
    final leave = await showFiloConfirmation(
      context,
      title: _session.complete
          ? 'Leave without saving this attempt?'
          : 'Leave this practice quiz?',
      message: _session.complete
          ? 'This attempt has not been confirmed saved. Leaving may lose it.'
          : 'Your unfinished attempt will be discarded. No score will be saved.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep open',
    );
    _confirming = false;
    if (!leave || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _session, q = s.question;
    return PopScope(
      canPop:
          _allowPop ||
          (!s.saving &&
              (s.loading || s.questions.isEmpty || s.savedId != null)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: EntryBackground(
        verification: true,
        breeze: true,
        variation: 0,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Practice quiz'),
            actions: [
              if (s.savedId != null)
                IconButton(
                  tooltip: 'History',
                  icon: const FiloIcon(FiloIcons.history),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => StudyQuizHistoryScreen(
                        notebookId: widget.notebookId,
                        quizId: widget.quizId,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(FiloSpacing.screen),
              children: [
                const StudyOfflineBanner(),
                if (s.loading)
                  const Center(
                    child: FiloCircularProgressIndicator(
                      semanticsLabel: 'Loading practice quiz',
                    ),
                  )
                else if (s.questions.isEmpty) ...[
                  EmptyState(
                    title: s.error == null
                        ? 'No questions in this quiz'
                        : 'Quiz unavailable',
                    body: 'Return to practice quizzes to generate a new quiz.',
                    pose: s.error == null ? 'reading' : 'confused',
                    primaryAction: s.error == null
                        ? null
                        : EmptyStateAction(label: 'Retry', onPressed: s.open),
                  ),
                ] else if (s.complete) ...[
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      '${s.score} of ${s.questions.length} correct',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.s16),
                  Text(
                    s.saving
                        ? 'Saving attempt...'
                        : s.savedId == null
                        ? 'Attempt not confirmed saved'
                        : 'Attempt saved.',
                  ),
                  if (!s.saving && s.savedId == null)
                    FiloButton(label: 'Try saving again', onPressed: s.save),
                  if (s.savedId != null) ...[
                    FiloButton(
                      label: 'Retake',
                      onPressed: () {
                        s.retake();
                        _text.clear();
                        _top();
                      },
                    ),
                    const SizedBox(height: FiloSpacing.s12),
                    FiloButton(
                      label: 'History',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => StudyQuizHistoryScreen(
                            notebookId: widget.notebookId,
                            quizId: widget.quizId,
                          ),
                        ),
                      ),
                    ),
                  ],
                  for (var i = 0; i < s.questions.length; i++)
                    QuizResultPanel(
                      question: s.questions[i],
                      answer: s.results[i].answer,
                      correct: s.results[i].correct,
                    ),
                ] else if (q != null) ...[
                  FiloPanel(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: FiloSpacing.s12,
                          runSpacing: FiloSpacing.s8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'Question ${s.index + 1} of ${s.questions.length}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text(switch (q.type) {
                                'multiple_choice' => 'Multiple choice',
                                'true_false' => 'True or false',
                                _ => 'Identification',
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: FiloSpacing.s12),
                        FiloLinearProgressIndicator(
                          value: s.results.length / s.questions.length,
                          semanticsLabel: 'Quiz progress',
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(FiloRadii.small),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.screen),
                  FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            q.prompt,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: FiloSpacing.s16),
                        if (q.type == 'multiple_choice')
                          for (final originalIndex in s.optionOrder[q.id]!)
                            _choice(
                              quizOptions(q)[originalIndex],
                              originalIndex,
                            ),
                        if (q.type == 'true_false') ...[
                          _choice('True', true),
                          _choice('False', false),
                        ],
                        if (q.type == 'identification')
                          TextField(
                            key: ValueKey(q.id),
                            controller: _text,
                            enabled: !s.checked,
                            decoration: const InputDecoration(
                              labelText: 'Your answer',
                            ),
                            minLines: 1,
                            maxLines: 5,
                            onChanged: s.select,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.screen),
                  if (!s.checked)
                    FiloButton(
                      label: 'Check',
                      onPressed: s.canCheck
                          ? () {
                              FocusScope.of(context).unfocus();
                              s.check();
                            }
                          : null,
                    ),
                  if (s.checked) ...[
                    FiloMotionTween(
                      key: ValueKey('feedback-${q.id}'),
                      initialValue: 0,
                      value: 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      builder: (context, value, child) => Transform.translate(
                        offset: Offset(0, 16 * (1 - value)),
                        child: child,
                      ),
                      child: QuizResultPanel(
                        question: q,
                        answer: s.answer!,
                        correct: s.results.last.correct,
                      ),
                    ),
                    FiloButton(
                      label: 'Continue',
                      onPressed: () async {
                        await s.next();
                        _text.clear();
                        _top();
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(String label, Object value) => Padding(
    padding: const EdgeInsets.only(bottom: FiloSpacing.s8),
    child: Semantics(
      selected: _session.answer == value,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, FiloControlSize.compact),
          alignment: Alignment.centerLeft,
          backgroundColor: _session.answer == value
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        onPressed: _session.checked ? null : () => _session.select(value),
        child: Text(label),
      ),
    ),
  );
}

class QuizResultPanel extends StatelessWidget {
  const QuizResultPanel({
    super.key,
    required this.question,
    required this.answer,
    required this.correct,
  });
  final StudyQuestion question;
  final Object answer;
  final bool correct;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s16),
    child: Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(FiloSpacing.s16),
        decoration: BoxDecoration(
          color: correct
              ? FiloThemeTokens.of(context).mint
              : Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(FiloRadii.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FiloIcon(
                  correct ? FiloIcons.checkCircle : FiloIcons.info,
                  color: correct
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: FiloSpacing.s8),
                Expanded(
                  child: Text(
                    correct ? 'Correct' : 'Not quite',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: FiloSpacing.s8),
            Text(question.prompt),
            Text('Your answer: ${quizAnswerText(question, answer)}'),
            Text('Correct answer: ${quizCorrectAnswer(question)}'),
            const SizedBox(height: FiloSpacing.s8),
            Text(question.explanation),
          ],
        ),
      ),
    ),
  );
}

class StudyQuizHistoryScreen extends StatelessWidget {
  const StudyQuizHistoryScreen({
    super.key,
    required this.notebookId,
    required this.quizId,
  });
  final String notebookId, quizId;
  @override
  Widget build(BuildContext context) => StudyQuizScope(
    notebookId: notebookId,
    builder: (_) => Consumer(
      builder: (context, ref, _) => studyQuizAvailable(
        ref,
        notebookId,
        quizId,
        () => Scaffold(
          appBar: AppBar(title: const Text('History')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(FiloSpacing.screen),
              children: [
                const StudyOfflineBanner(),
                studyAsync(
                  ref.watch(studyQuestionsProvider(quizId)),
                  (questions) => studyAsync(
                    ref.watch(studyAttemptsProvider(quizId)),
                    (attempts) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (attempts.isEmpty)
                          const EmptyState(
                            title: 'No completed attempts',
                            body: 'Complete a practice quiz to see an attempt here.',
                            pose: 'waiting',
                          ),
                        for (final attempt in attempts)
                          FiloPanel(
                            child: ExpansionTile(
                              title: Text(
                                '${attempt.score} of ${attempt.total} correct',
                              ),
                              subtitle: Text(
                                '${MaterialLocalizations.of(context).formatMediumDate(attempt.attemptedAt.toLocal())} - ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(attempt.attemptedAt.toLocal()))}',
                              ),
                              children: [
                                QuizAttemptReview(
                                  questions: questions,
                                  encoded: attempt.results,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    retry: () => ref.invalidate(studyAttemptsProvider(quizId)),
                  ),
                  retry: () => ref.invalidate(studyQuestionsProvider(quizId)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class QuizAttemptReview extends StatelessWidget {
  const QuizAttemptReview({
    super.key,
    required this.questions,
    required this.encoded,
  });
  final List<StudyQuestion> questions;
  final String encoded;
  @override
  Widget build(BuildContext context) {
    try {
      final rows = (jsonDecode(encoded) as List).cast<Map<String, dynamic>>();
      final byId = {for (final q in questions) q.id: q};
      for (final row in rows) {
        final question = byId[row['question_id']];
        if (question == null ||
            row['correct'] is! bool ||
            row['answer'] == null) {
          throw const FormatException();
        }
        quizAnswerText(question, row['answer'] as Object);
      }
      return Column(
        children: [
          for (final row in rows)
            QuizResultPanel(
              question: byId[row['question_id']]!,
              answer: row['answer'] as Object,
              correct: row['correct'] as bool,
            ),
        ],
      );
    } catch (_) {
      return const Text(
        'Your saved study material could not be opened. Try again.',
      );
    }
  }
}
