import 'package:flutter/material.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/quiz_draft.dart';

// Reveal the whole field/error, then let EditableText keep it above the keyboard.
Future<void> revealAssessmentField(BuildContext target) async {
  await WidgetsBinding.instance.endOfFrame;
  if (!target.mounted) return;
  EditableText? input;
  void findInput(Element element) {
    if (element.widget is EditableText) {
      input ??= element.widget as EditableText;
    }
    element.visitChildren(findInput);
  }

  target.visitChildElements(findInput);
  input?.focusNode.requestFocus();
  await Scrollable.ensureVisible(target, alignment: 0.15);
}

Future<void> revealQuestionError(
  BuildContext card,
  Map<String, String> errors,
) async {
  BuildContext? target;
  final answerMessage = errors['answer'];
  void findError(Element element) {
    final widget = element.widget;
    if (widget is TextField &&
        (widget.decoration?.errorText != null ||
            (widget.decoration?.labelText == 'Accepted answer' &&
                answerMessage != null))) {
      target ??= element;
    }
    if (widget is Text &&
        answerMessage != null &&
        widget.data == answerMessage) {
      target ??= element;
    }
    element.visitChildren(findError);
  }

  card.visitChildElements(findError);
  await revealAssessmentField(target ?? card);
}

const questionTypeLabels = {
  'multiple_choice': 'Multiple choice',
  'true_false': 'True or false',
  'identification': 'Identification',
  'essay': 'Essay',
};

// Owned by the screen so virtualized cards never discard unfinished input.
class QuestionEditorState {
  QuestionEditorState(QuizQuestion q)
    : points = '${q.points}',
      status = q.id == null ? 'Unsaved changes' : 'Saved';
  String points, pendingAnswer = '', status;
  Map<String, String> errors = {};
}

class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.editor,
    required this.index,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
    required this.onAction,
    this.showActions = true,
    this.canSaveToBank = false,
  });
  final QuizQuestion question;
  final QuestionEditorState editor;
  final int index;
  final bool expanded, enabled;
  final bool showActions, canSaveToBank;
  final VoidCallback onToggle, onChanged;
  final ValueChanged<String> onAction;
  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  void change(VoidCallback edit) {
    setState(() {
      edit();
      widget.editor.status = 'Unsaved changes';
      if (widget.editor.errors.isNotEmpty) {
        widget.editor.errors = widget.question.validationErrors(
          pointsText: widget.editor.points,
          pendingAnswer: widget.editor.pendingAnswer,
        );
      }
    });
    widget.onChanged();
  }

  Widget field(
    String name,
    String label,
    String value,
    ValueChanged<String> update, {
    int? maxLength,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      key: ValueKey(
        '${widget.question.localId}-$name-${name.startsWith('option') ? _optionRevision : 0}',
      ),
      initialValue: value,
      enabled: widget.enabled,
      maxLength: maxLength,
      minLines: name == 'prompt' ? 2 : 1,
      maxLines: number ? 1 : 5,
      keyboardType: number ? TextInputType.number : TextInputType.multiline,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        errorText: widget.editor.errors[name],
        errorMaxLines: 3,
      ),
      onChanged: (v) => change(() => update(v)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final e = widget.editor;
    final options = q.optionTexts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FiloPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${widget.index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (widget.enabled && widget.showActions)
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: const Tooltip(
                      message: 'Drag to reorder',
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.drag_handle,
                          color: FiloColors.secondary,
                        ),
                      ),
                    ),
                  ),
                if (widget.showActions)
                  PopupMenuButton<String>(
                    tooltip: 'Question actions',
                    enabled: widget.enabled || widget.canSaveToBank,
                    onSelected: widget.onAction,
                    itemBuilder: (_) => [
                      if (widget.canSaveToBank)
                        const PopupMenuItem(
                          value: 'bank',
                          child: Text('Save to bank'),
                        ),
                      PopupMenuItem(
                        enabled: widget.enabled,
                        value: 'up',
                        child: Text('Move up'),
                      ),
                      PopupMenuItem(
                        enabled: widget.enabled,
                        value: 'down',
                        child: Text('Move down'),
                      ),
                      PopupMenuItem(
                        enabled: widget.enabled,
                        value: 'duplicate',
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(
                        enabled: widget.enabled,
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            TextButton(
              onPressed: widget.onToggle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: FiloColors.tint,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      questionTypeLabels[q.type]!,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    widget.expanded ? Icons.expand_less : Icons.expand_more,
                    semanticLabel: widget.expanded
                        ? 'Collapse question'
                        : 'Expand question',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.expanded)
              Text(
                q.prompt.isEmpty ? 'Write your question' : q.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_pointsLabel(e.points)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      e.status == 'Saved'
                          ? Icons.check_circle_outline
                          : e.status == 'Save not confirmed'
                          ? Icons.error_outline
                          : Icons.edit_outlined,
                      size: 16,
                      color: e.status == 'Save not confirmed'
                          ? FiloColors.error
                          : FiloColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        e.status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: e.status == 'Save not confirmed'
                              ? FiloColors.error
                              : FiloColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (q.aiGenerated)
                  const Chip(
                    avatar: Icon(Icons.auto_awesome, size: 18),
                    label: Text('AI'),
                  ),
              ],
            ),
            if (!widget.expanded && e.errors.isNotEmpty)
              const Text('Check this question before saving.'),
            if (widget.expanded) ...[
              field(
                'prompt',
                'Question',
                q.prompt,
                (v) => q.payload['prompt'] = v,
                maxLength: 1000,
              ),
              field('points', 'Points', e.points, (v) {
                e.points = v;
                q.payload['points'] = int.tryParse(v) ?? 0;
              }, number: true),
              if (q.type == 'multiple_choice') ...[
                const SizedBox(height: 12),
                const Text('Add answer options and pick one correct option.'),
                for (var i = 0; i < options.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 60,
                        child: Semantics(
                          label: 'Mark option ${i + 1} correct',
                          child: Radio<int>(
                            value: i,
                            groupValue: q.answerKey?.correctOptionIndex,
                            onChanged: widget.enabled
                                ? (v) => change(
                                    () => q.payload['correct_option_index'] = v,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Expanded(
                        child: field(
                          'option$i',
                          'Option ${i + 1}',
                          options[i],
                          (v) {
                            final texts = q.optionTexts.toList();
                            texts[i] = v;
                            q.payload['options'] = texts;
                          },
                          maxLength: 500,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove option ${i + 1}',
                        onPressed: widget.enabled && options.length > 2
                            ? () => change(() {
                                q.removeOption(i);
                                _optionRevision++;
                              })
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: widget.enabled && options.length < 10
                      ? () => change(
                          () => q.payload['options'] = [...options, ''],
                        )
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              ],
              if (q.type == 'true_false') ...[
                const Text(
                  'Choose whether the correct answer is True or False.',
                ),
                for (final value in [true, false])
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(value ? 'True' : 'False'),
                    value: value,
                    groupValue: q.answerKey?.correctBoolean,
                    onChanged: widget.enabled
                        ? (v) => change(() => q.payload['correct_boolean'] = v)
                        : null,
                  ),
              ],
              if (q.type == 'identification') ...[
                const SizedBox(height: 12),
                const Text(
                  'Add every spelling you accept. Capital letters and extra spaces are ignored.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (
                      var i = 0;
                      i < q.answerKey!.acceptedAnswers.length;
                      i++
                    )
                      InputChip(
                        label: Text(q.answerKey!.acceptedAnswers[i]),
                        onDeleted: widget.enabled
                            ? () => change(() {
                                final answers =
                                    q.answerKey!.acceptedAnswers.toList()
                                      ..removeAt(i);
                                q.payload['accepted_answers'] = answers;
                              })
                            : null,
                      ),
                  ],
                ),
                field(
                  'pending-$_answerRevision',
                  'Accepted answer',
                  e.pendingAnswer,
                  (v) => e.pendingAnswer = v,
                ),
                TextButton.icon(
                  onPressed:
                      widget.enabled &&
                          e.pendingAnswer.trim().isNotEmpty &&
                          q.answerKey!.acceptedAnswers.length < 10
                      ? () => change(() {
                          q.payload['accepted_answers'] = [
                            ...q.answerKey!.acceptedAnswers,
                            e.pendingAnswer,
                          ];
                          e.pendingAnswer = '';
                          _answerRevision++;
                        })
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add answer'),
                ),
              ],
              if (q.type == 'essay')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('You grade this by hand after the quiz.'),
                ),
              if (e.errors['answer'] != null)
                Text(
                  e.errors['answer']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              field(
                'explanation',
                'Explanation (optional)',
                q.explanation ?? '',
                (v) => q.payload['explanation'] = v.isEmpty ? null : v,
                maxLength: 500,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _pointsLabel(String value) {
    final n = int.tryParse(value);
    return n != null && n >= 1 && n <= 1000
        ? '$n ${n == 1 ? 'point' : 'points'}'
        : 'Points need attention';
  }

  int _answerRevision = 0, _optionRevision = 0;
}
