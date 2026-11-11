import 'package:flutter/material.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../domain/quiz_draft.dart';
import '../domain/quiz_helpers.dart';

String assessmentDateLabel(DateTime? instant) {
  if (instant == null) return 'Not set';
  final date = utcToManila(instant);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '${months[date.month - 1]} ${date.day}, ${date.year}, $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
}

class AssessmentTypeChip extends StatelessWidget {
  const AssessmentTypeChip({super.key, required this.type});
  final String type;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(type == 'exam' ? 'Exam' : 'Quiz'),
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    labelStyle: Theme.of(context).textTheme.labelMedium!
        .copyWith(color: Theme.of(context).colorScheme.onSurface),
    visualDensity: VisualDensity.compact,
  );
}

class AssessmentRow extends StatelessWidget {
  const AssessmentRow({
    super.key,
    required this.quiz,
    required this.now,
    required this.onOpen,
    this.onDelete,
    this.onEdit,
    this.busy = false,
  });
  final InstructorQuizSummary quiz;
  final DateTime now;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete, onEdit;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final status = quizDisplayStatus(
      status: quiz.status,
      opensAt: quiz.opensAt,
      closesAt: quiz.closesAt,
      now: now,
    );
    final icon = switch (status) {
      QuizDisplayStatus.draft => FiloIcons.edit,
      QuizDisplayStatus.scheduled => FiloIcons.clock,
      QuizDisplayStatus.open => FiloIcons.checkCircle,
      QuizDisplayStatus.closed => FiloIcons.lock,
    };
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: colors.primary.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FiloRadii.large),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(FiloSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(FiloRadii.medium),
                        ),
                        child: Text(
                          quiz.type == 'exam' ? 'Exam' : 'Quiz',
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (busy)
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: FiloCircularProgressIndicator(
                              semanticsLabel: 'Deleting assessment',
                            ),
                          ),
                        )
                      else if (onDelete != null || onEdit != null)
                        PopupMenuButton<String>(
                          tooltip: 'Assessment options',
                          icon: const FiloIcon(FiloIcons.more),
                          onSelected: (action) {
                            switch (action) {
                              case 'edit':
                                onEdit?.call();
                              case 'delete':
                                onDelete?.call();
                            }
                          },
                          itemBuilder: (_) => [
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                height: 48,
                                child: Text('Edit'),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                height: 48,
                                child: Text('Delete'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: FiloSpacing.s8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quiz.title,
                              style: theme.textTheme.titleLarge!.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: FiloSpacing.s8),
                            Text(
                              '${quiz.type == 'exam' ? 'Exam' : 'Quiz'} \u2022 ${quiz.questionCount == null ? 'Question count unavailable' : '${quiz.questionCount} ${quiz.questionCount == 1 ? 'question' : 'questions'}'} \u2022 ${quiz.totalPoints} ${quiz.totalPoints == 1 ? 'point' : 'points'}',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: FiloSpacing.s12),
                            FiloStatusChip(label: status.label, icon: icon),
                          ],
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 360 &&
                          MediaQuery.textScalerOf(context).scale(1) <= 1.2)
                        ExcludeSemantics(
                          child: SizedBox(
                            width: 96,
                            height: 112,
                            child: Image.asset(
                              quiz.type == 'exam'
                                  ? 'assets/illustrations/classwork-exam.png'
                                  : 'assets/illustrations/classwork-quiz.png',
                              fit: BoxFit.contain,
                              cacheWidth:
                                  (96 * MediaQuery.devicePixelRatioOf(context))
                                      .ceil(),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (busy || onOpen == null) ...[
                    const SizedBox(height: FiloSpacing.s8),
                    Text(
                      busy ? 'Deleting...' : 'Draft. Use the menu to edit.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: FiloSpacing.s16,
                vertical: FiloSpacing.s12,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final time in [
                      (
                        icon: FiloIcons.calendar,
                        label: 'Opens',
                        value: quiz.opensAt,
                      ),
                      (
                        icon: FiloIcons.clock,
                        label: 'Closes',
                        value: quiz.closesAt,
                      ),
                    ]) ...[
                      if (time.label == 'Closes')
                        VerticalDivider(
                          width: 24,
                          color: colors.outlineVariant,
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FiloSpacing.s8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  FiloIcon(
                                    time.icon,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: FiloSpacing.s8),
                                  Flexible(
                                    child: Text(
                                      time.label,
                                      style: theme.textTheme.labelMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: FiloSpacing.s4),
                              Text(
                                assessmentDateLabel(time.value),
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
