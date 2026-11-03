import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../domain/exam.dart';
import '../domain/student_quiz_status.dart';
import 'student_quiz_widgets.dart';

class StudentQuizOverview extends StatelessWidget {
  const StudentQuizOverview({
    super.key,
    required this.quiz,
    required this.now,
    required this.archived,
    required this.online,
    required this.loading,
    required this.understood,
    required this.busy,
    required this.onChanged,
    required this.onStart,
    required this.onRefresh,
    this.message,
    this.onRetry,
    this.resultAction,
  });
  final StudentQuiz? quiz;
  final DateTime now;
  final bool archived, online, loading, understood, busy;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onStart, onRetry;
  final Future<void> Function() onRefresh;
  final String? message;
  final Widget? resultAction;

  @override
  Widget build(BuildContext context) {
    final q = quiz;
    final state = q == null ? null : studentQuizState(q, now);
    final resume = q?.session?.inProgress == true;
    final canAttempt =
        !archived &&
        (state?.status == StudentQuizStatus.open ||
            state?.status == StudentQuizStatus.upcoming);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: PageStorageKey('quiz-overview-${q?.id ?? 'loading'}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FiloSpacing.screen),
        children: [
          if (!online) ...[
            const OfflineBanner(),
            const SizedBox(height: FiloSpacing.s16),
          ],
          if (q == null && loading) const StudentQuizSkeleton(),
          if (q != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(q.typeLabel)),
                StudentQuizStatusChip(state: state!),
              ],
            ),
            const SizedBox(height: FiloSpacing.s12),
            Semantics(
              header: true,
              child: Text(
                q.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: FiloSpacing.screen),
            FiloPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      _metric(
                        context,
                        'Time limit',
                        '${q.minutes} ${q.minutes == 1 ? 'minute' : 'minutes'}',
                      ),
                      _metric(context, 'Points', '${q.points}'),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: FiloSpacing.s12),
                    child: Divider(),
                  ),
                  _schedule(context, 'Opens', philippineQuizDate(q.opensAt)),
                  const SizedBox(height: FiloSpacing.s16),
                  _schedule(context, 'Closes', philippineQuizDate(q.closesAt)),
                ],
              ),
            ),
            const SizedBox(height: FiloSpacing.screen),
            Semantics(
              header: true,
              child: Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: FiloSpacing.s8),
            Text(
              q.instructions.isEmpty
                  ? 'No instructions provided.'
                  : q.instructions,
            ),
            if (canAttempt && !resume) ...[
              const SizedBox(height: FiloSpacing.screen),
              FiloPanel(
                color: FiloThemeTokens.of(context).warningTint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Before you start',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: FiloSpacing.s8),
                    for (final rule in const [
                      (FiloIcons.checkCircle, 'You have one attempt only.'),
                      (
                        FiloIcons.lock,
                        "You can't go back to other screens during the exam.",
                      ),
                      (
                        FiloIcons.info,
                        'Have enough battery and mobile data or Wi-Fi.',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: FiloSpacing.s8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: FiloIcon(
                                rule.$1,
                                color: FiloThemeTokens.of(context).warning,
                              ),
                            ),
                            const SizedBox(width: FiloSpacing.s12),
                            Expanded(child: Text(rule.$2)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: FiloSpacing.s12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I understand'),
                value: understood,
                onChanged: busy ? null : onChanged,
              ),
            ],
          ],
          if (message != null) ...[
            const SizedBox(height: FiloSpacing.s16),
            Semantics(liveRegion: true, child: Text(message!)),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: FiloSpacing.s8),
            TextButton(
              onPressed: busy ? null : onRetry,
              child: const Text('Try again'),
            ),
          ],
          if (resultAction != null) ...[
            const SizedBox(height: FiloSpacing.screen),
            resultAction!,
          ] else if (q != null) ...[
            const SizedBox(height: FiloSpacing.screen),
            FiloButton(
              label: busy
                  ? 'Please wait...'
                  : resume
                  ? 'Continue'
                  : 'Start now',
              labelVariants: resume
                  ? const ['Continue', 'Please wait...']
                  : const ['Start now', 'Please wait...'],
              leading: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: FiloCircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : null,
              busy: busy,
              onPressed: !busy && (resume || understood) ? onStart : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: FiloSpacing.s4),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );

  Widget _schedule(BuildContext context, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(
        child: FiloIcon(
          FiloIcons.clock,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      const SizedBox(width: FiloSpacing.s12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: FiloSpacing.s4),
            Text(value),
          ],
        ),
      ),
    ],
  );
}
