import 'package:flutter/material.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../domain/exam.dart';

class ExamQuestionCard extends StatefulWidget {
  const ExamQuestionCard({
    super.key,
    required this.question,
    required this.number,
    required this.answer,
    required this.enabled,
    required this.onChanged,
  });
  final ExamQuestion question;
  final int number;
  final ExamAnswer? answer;
  final bool enabled;
  final ValueChanged<ExamAnswer> onChanged;

  @override
  State<ExamQuestionCard> createState() => _ExamQuestionCardState();
}

class _ExamQuestionCardState extends State<ExamQuestionCard> {
  late final _text = TextEditingController(text: widget.answer?.text ?? '');

  @override
  void didUpdateWidget(covariant ExamQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.answer?.text ?? '';
    if (_text.text != value) {
      _text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return SelectionContainer.disabled(
      child: FiloPanel(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${widget.number} · ${q.points} ${q.points == 1 ? 'point' : 'points'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                q.prompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            if (q.type == 'multiple_choice')
              for (final option in q.options)
                _option(
                  option['text'] as String,
                  widget.answer?.optionId == option['id'],
                  ExamAnswer(
                    questionId: q.id,
                    optionId: option['id'] as String,
                  ),
                ),
            if (q.type == 'true_false')
              for (final value in [true, false])
                _option(
                  value ? 'True' : 'False',
                  widget.answer?.boolean == value,
                  ExamAnswer(questionId: q.id, boolean: value),
                ),
            if (q.type == 'identification' || q.type == 'essay')
              TextField(
                controller: _text,
                enabled: widget.enabled,
                minLines: q.type == 'essay' ? 4 : 1,
                maxLines: q.type == 'essay' ? null : 3,
                enableInteractiveSelection: false,
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Answer'),
                onChanged: (value) =>
                    widget.onChanged(ExamAnswer(questionId: q.id, text: value)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _option(String label, bool selected, ExamAnswer answer) => Semantics(
    checked: selected,
    inMutuallyExclusiveGroup: true,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 48,
      enabled: widget.enabled,
      leading: ExcludeSemantics(
        child: FiloIcon(selected ? FiloIcons.checkCircle : FiloIcons.circle),
      ),
      title: Text(label),
      onTap: widget.enabled ? () => widget.onChanged(answer) : null,
    ),
  );
}
