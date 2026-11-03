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
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
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
    this.onResults,
    this.onEdit,
    this.busy = false,
  });
  final InstructorQuizSummary quiz;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback? onDelete, onResults, onEdit;
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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: busy ? null : onOpen,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      AssessmentTypeChip(type: quiz.type),
                      Chip(
                        avatar: FiloIcon(
                          icon,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        label: Text(status.label),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quiz.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Opens: ${assessmentDateLabel(quiz.opensAt)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Closes: ${assessmentDateLabel(quiz.closesAt)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${quiz.questionCount == null ? 'Question count unavailable' : '${quiz.questionCount} ${quiz.questionCount == 1 ? 'question' : 'questions'}'} | ${quiz.totalPoints} ${quiz.totalPoints == 1 ? 'point' : 'points'}',
                  ),
                ],
              ),
            ),
          ),
          if (onDelete != null || onResults != null || onEdit != null || busy)
            Align(
              alignment: Alignment.centerRight,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Deleting...'),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Assessment options',
                      icon: const FiloIcon(FiloIcons.more),
                      onSelected: (action) => action == 'results'
                          ? onResults?.call()
                          : action == 'edit'
                          ? onEdit?.call()
                          : onDelete?.call(),
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            height: 48,
                            child: Text('Edit'),
                          ),
                        if (onResults != null)
                          const PopupMenuItem(
                            value: 'results',
                            height: 48,
                            child: Text('Results'),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            height: 48,
                            child: Text('Delete'),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
