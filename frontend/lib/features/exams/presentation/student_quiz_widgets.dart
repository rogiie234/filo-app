import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../domain/exam.dart';
import '../domain/student_quiz_status.dart';

class StudentQuizStatusChip extends StatelessWidget {
  const StudentQuizStatusChip({super.key, required this.state});
  final StudentQuizState state;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: FiloIcon(switch (state.status) {
      StudentQuizStatus.upcoming => FiloIcons.calendar,
      StudentQuizStatus.open => FiloIcons.assessment,
      StudentQuizStatus.inProgress => FiloIcons.edit,
      StudentQuizStatus.submitted => FiloIcons.checkCircle,
      StudentQuizStatus.closed => FiloIcons.clock,
      StudentQuizStatus.missed => FiloIcons.info,
    }, size: 16),
    label: Text(state.status.label),
  );
}

class StudentQuizRow extends StatelessWidget {
  const StudentQuizRow({
    super.key,
    required this.quiz,
    required this.now,
    required this.onTap,
    this.classLabel,
  });
  final StudentQuiz quiz;
  final DateTime now;
  final VoidCallback onTap;
  final String? classLabel;
  @override
  Widget build(BuildContext context) {
    final state = studentQuizState(quiz, now);
    return Material(
      color: FiloColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: FiloColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(quiz.title, style: Theme.of(context).textTheme.titleMedium),
              if (classLabel != null)
                Text(
                  classLabel!,
                  style: const TextStyle(color: FiloColors.secondary),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text(quiz.typeLabel)),
                  StudentQuizStatusChip(state: state),
                ],
              ),
              const SizedBox(height: 8),
              Text('Closes: ${philippineQuizDate(quiz.closesAt)}'),
              Text(
                '${quiz.points} points',
                style: const TextStyle(color: FiloColors.secondary),
              ),
              if (state.pending)
                const Text('Refresh to check your exam status.'),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentQuizSkeleton extends StatelessWidget {
  const StudentQuizSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading quiz',
    child: ExcludeSemantics(
      child: FiloPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final width in [1.0, .6, .8])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FractionallySizedBox(
                  widthFactor: width,
                  alignment: Alignment.centerLeft,
                  child: Container(height: 20, color: FiloColors.mint),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
