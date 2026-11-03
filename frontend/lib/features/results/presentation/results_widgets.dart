import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../../exams/domain/student_quiz_status.dart';
import '../domain/results.dart';

const resultsWaiting =
    'Results will be available once everyone has finished or the quiz closes.';
const resultsScoreOnly =
    'Show correct answers is off for this quiz, so only your score is shown.';
const resultsLeaveNote =
    'Leaving the app can happen by accident, for example a phone call or a notification. You decide what it means.';

class ResultStatusChip extends StatelessWidget {
  const ResultStatusChip(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final success = ['Correct', 'Passed', 'Graded'].contains(label);
    final error = ['Incorrect', 'Not passed'].contains(label);
    final color = success
        ? FiloThemeTokens.of(context).success
        : error
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return Chip(
      avatar: Icon(
        success
            ? Icons.check_circle_outline
            : error
            ? Icons.cancel_outlined
            : Icons.info_outline,
        size: 18,
        color: color,
      ),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelMedium!
          .copyWith(color: color),
      backgroundColor: success
          ? FiloThemeTokens.of(context).successTint
          : error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainer,
    );
  }
}

class ResultsListBody extends StatelessWidget {
  const ResultsListBody({
    super.key,
    required this.onRefresh,
    required this.children,
    this.loading = false,
    this.offline = false,
    this.error,
  });
  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final bool loading, offline;
  final String? error;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(FiloSpacing.screen),
      children: [
        if (offline) ...[
          const OfflineBanner(),
          const SizedBox(height: FiloSpacing.s16),
        ],
        if (loading) const ResultsSkeleton(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(liveRegion: true, child: Text(error!)),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ...children,
      ],
    ),
  );
}

class ResultsSkeleton extends StatelessWidget {
  const ResultsSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading results',
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (final width in [1.0, 0.65, 1.0])
            Padding(
              padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
              child: FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(FiloRadii.medium),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ResultSummaryTile extends StatelessWidget {
  const ResultSummaryTile(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: FiloPanel(
      padding: const EdgeInsets.all(FiloSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: FiloSpacing.s4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

String releasedLine(ResultJson quiz) => quiz['results_released_at'] == null
    ? 'Results not released'
    : 'Released on ${philippineQuizDate(DateTime.parse(quiz['results_released_at'] as String))}';

ResultJson instructorReview(ResultJson question) {
  final answer = question['answer'] as Map?;
  final raw = question['answer_keys'];
  final key = raw is List
      ? (raw.isEmpty ? <String, dynamic>{} : resultJson(raw.single))
      : raw == null
      ? <String, dynamic>{}
      : resultJson(raw);
  final options = resultRows(question['question_options']);
  Object? optionText(Object? id) =>
      options.where((o) => o['id'] == id).firstOrNull?['text'];
  return {
    ...question,
    'your_answer': switch (question['type']) {
      'multiple_choice' => optionText(answer?['option_id']),
      'true_false' => answer?['bool_answer'],
      _ => answer?['text_answer'],
    },
    'correct_answer': switch (question['type']) {
      'multiple_choice' => optionText(key['correct_option_id']),
      'true_false' => key['correct_boolean'],
      'identification' => key['accepted_answers'],
      _ => null,
    },
    'points_awarded': answer?['points_awarded'],
    'is_correct': answer?['is_correct'],
    'feedback': answer?['feedback'],
  };
}

class ResultQuestionCard extends StatelessWidget {
  const ResultQuestionCard({
    super.key,
    required this.question,
    required this.number,
    this.editor,
    this.answerLabel = 'Your answer',
  });
  final ResultJson question;
  final int number;
  final Widget? editor;
  final String answerLabel;
  @override
  Widget build(BuildContext context) {
    final essay = question['type'] == 'essay';
    final empty = essay && blankEssay(question['your_answer']);
    final points = question['points_awarded'] ?? (empty ? 0 : null);
    final status = essay
        ? (points != null ? 'Graded' : 'Not graded yet')
        : question['is_correct'] == true
        ? 'Correct'
        : question['is_correct'] == false
        ? 'Incorrect'
        : 'Not graded yet';
    return Padding(
      padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
      child: FiloPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$number. ${question['prompt']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: FiloSpacing.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: ResultStatusChip(status),
            ),
            const SizedBox(height: FiloSpacing.s8),
            Text(answerLabel, style: Theme.of(context).textTheme.labelMedium!),
            SelectableText(
              empty ? 'No answer' : resultAnswer(question['your_answer']),
            ),
            if (question['correct_answer'] != null) ...[
              const SizedBox(height: FiloSpacing.s12),
              Text(
                'Correct answer',
                style: Theme.of(context).textTheme.labelMedium!,
              ),
              SelectableText(resultAnswer(question['correct_answer'])),
            ],
            const SizedBox(height: FiloSpacing.s12),
            Text('Points: ${points ?? '—'}/${question['points']}'),
            for (final field in [
              ('explanation', 'Explanation'),
              ('feedback', 'Feedback'),
            ])
              if ((question[field.$1] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: FiloSpacing.s12),
                Text(field.$2, style: Theme.of(context).textTheme.labelMedium!),
                SelectableText(question[field.$1] as String),
              ],
            if (editor != null) ...[
              const SizedBox(height: FiloSpacing.s16),
              editor!,
            ],
          ],
        ),
      ),
    );
  }
}
