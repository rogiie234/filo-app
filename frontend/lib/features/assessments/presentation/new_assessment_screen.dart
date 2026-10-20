import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/preview_controller.dart';
import '../../classes/domain/prototype_models.dart';

class NewAssessmentScreen extends ConsumerStatefulWidget {
  const NewAssessmentScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<NewAssessmentScreen> createState() =>
      _NewAssessmentScreenState();
}

class _NewAssessmentScreenState extends ConsumerState<NewAssessmentScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _minutes = TextEditingController(text: '30');
  final _questions = <_QuestionDraft>[_QuestionDraft()];
  String _type = 'Quiz';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _minutes.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(previewProvider).role != PreviewRole.instructor) {
      return Scaffold(
        appBar: AppBar(title: const Text('New assessment')),
        body: const Center(
          child: Text('Choose the instructor preview to create an assessment.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('New assessment')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'A little challenge. A lot to discover.',
              style: TextStyle(color: FiloColors.secondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _title,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Give your assessment a title.'
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                for (final type in ['Quiz', 'Exam'])
                  ChoiceChip(
                    label: Text(type),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time limit (minutes)',
                suffixIcon: FiloIcon(FiloIcons.clock),
              ),
              validator: (value) {
                final minutes = int.tryParse(value ?? '');
                return minutes == null || minutes < 1 || minutes > 600
                    ? 'Enter 1 to 600 minutes.'
                    : null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _instructions,
              maxLines: 3,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FiloPanel(
              color: FiloColors.lime,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const FiloIcon(FiloIcons.sparkle),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Start with a little inspiration.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _samples,
              icon: const FiloIcon(FiloIcons.sparkle),
              label: const Text('Generate with AI'),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Questions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${_questions.length} total',
                  style: const TextStyle(color: FiloColors.secondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (int index = 0; index < _questions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _questionCard(_questions[index], index),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _questions.add(_QuestionDraft())),
              icon: const FiloIcon(FiloIcons.add),
              label: const Text('Add question'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Drafts and published assessments stay in this preview session.',
              style: TextStyle(color: FiloColors.secondary, fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FiloButton(
                label: 'Publish',
                icon: FiloIcons.forward,
                onPressed: () => _save(false),
              ),
              TextButton(
                onPressed: () => _save(true),
                child: const Text('Save draft'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionCard(_QuestionDraft question, int index) => FiloPanel(
    key: ValueKey(question),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_questions.length > 1)
              IconButton(
                tooltip: 'Remove question ${index + 1}',
                icon: const FiloIcon(FiloIcons.delete),
                onPressed: () async {
                  final remove = await confirmAction(
                    context,
                    title: 'Remove this question?',
                    message: 'Its question text and answers will be removed.',
                    action: 'Remove',
                  );
                  if (remove && mounted) {
                    setState(() {
                      _questions.remove(question);
                      question.dispose();
                    });
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: question.type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Question type'),
          items: [
            for (final type in [
              'Multiple choice',
              'True or false',
              'Identification',
              'Essay',
            ])
              DropdownMenuItem(value: type, child: Text(type)),
          ],
          onChanged: (value) => setState(() {
            question.type = value!;
            question.correct = null;
          }),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: question.prompt,
          minLines: 2,
          maxLines: 5,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Question',
            alignLabelWithHint: true,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Write a question.'
              : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: question.points,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Points'),
          validator: (value) {
            final points = int.tryParse(value ?? '');
            return points == null || points < 1 || points > 1000
                ? 'Enter 1 to 1000 points.'
                : null;
          },
        ),
        const SizedBox(height: 20),
        if (question.type == 'Multiple choice' ||
            question.type == 'True or false') ...[
          const Text(
            'Select the correct answer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: question.correct,
            onChanged: (value) => setState(() => question.correct = value),
            child: Column(
              children: [
                for (
                  int option = 0;
                  option < (question.type == 'True or false' ? 2 : 4);
                  option++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(value: option),
                        Expanded(
                          child: question.type == 'True or false'
                              ? Text(option == 0 ? 'True' : 'False')
                              : TextFormField(
                                  controller: question.options[option],
                                  maxLength: 500,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Option ${String.fromCharCode(65 + option)}',
                                    counterText: '',
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Enter an answer option.'
                                      : null,
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ] else if (question.type == 'Identification')
          TextFormField(
            controller: question.answer,
            decoration: const InputDecoration(labelText: 'Accepted answer'),
            maxLength: 500,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter the accepted answer.'
                : null,
          )
        else
          const Text(
            'Essay answers are scored by the instructor.',
            style: TextStyle(color: FiloColors.secondary),
          ),
      ],
    ),
  );

  Future<void> _samples() async {
    final add = await showFiloBottomSheet<bool>(
      title: 'Sample questions',
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FiloIcon(FiloIcons.sparkle, size: 32),
              const SizedBox(height: 16),
              Text(
                'A starting point.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'AI generation is not connected in this preview. Try two sample questions about computing, then make them your own.',
              ),
              const SizedBox(height: 24),
              FiloButton(
                label: 'Use sample questions',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (add != true || !mounted) return;
    setState(() {
      if (_questions.length == 1 &&
          _questions.first.prompt.text.isEmpty &&
          _questions.first.options.every((option) => option.text.isEmpty)) {
        _questions.removeAt(0).dispose();
      }
      _questions.addAll([
        _QuestionDraft.sample(
          'Which part of a computer processes instructions?',
          ['CPU', 'Monitor', 'Keyboard', 'Printer'],
          0,
        ),
        _QuestionDraft.sample('Which of these is an example of software?', [
          'A mouse',
          'A web browser',
          'A monitor',
          'A keyboard',
        ], 1),
      ]);
    });
  }

  Future<void> _save(bool draft) async {
    if (draft) {
      if (_title.text.trim().isEmpty) {
        setState(() => _error = 'Give your draft a title.');
        return;
      }
    } else {
      final valid = _form.currentState!.validate();
      if (!valid ||
          _questions.any(
            (question) =>
                ['Multiple choice', 'True or false'].contains(question.type) &&
                question.correct == null,
          )) {
        setState(
          () =>
              _error = 'Complete each question and select its correct answer.',
        );
        return;
      }
      final publish = await confirmAction(
        context,
        title: 'Publish this $_type?',
        message:
            '${_questions.length} questions · ${_questions.fold<int>(0, (total, question) => total + (int.tryParse(question.points.text) ?? 0))} points · ${_minutes.text} minutes\n\nThis publishes to the preview only.',
        action: 'Publish',
      );
      if (!publish || !mounted) return;
    }
    ref
        .read(previewProvider.notifier)
        .addAssessment(
          Assessment(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            classId: widget.classId,
            title: _title.text.trim(),
            type: _type,
            minutes: int.tryParse(_minutes.text) ?? 30,
            draft: draft,
            instructions: _instructions.text.trim(),
            questions: _questions
                .map((question) => question.toQuestion())
                .toList(),
          ),
        );
    context.pop();
    showMessage(
      context,
      draft
          ? 'Draft saved in the preview.'
          : 'Assessment published in the preview.',
    );
  }
}

class _QuestionDraft {
  final prompt = TextEditingController();
  final points = TextEditingController(text: '1');
  final answer = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  String type = 'Multiple choice';
  int? correct;
  _QuestionDraft();

  _QuestionDraft.sample(String text, List<String> choices, int correctOption) {
    prompt.text = text;
    for (int i = 0; i < choices.length; i++) {
      options[i].text = choices[i];
    }
    correct = correctOption;
  }

  PreviewQuestion toQuestion() => PreviewQuestion(
    prompt: prompt.text.trim(),
    points: int.tryParse(points.text) ?? 1,
    correct: correct ?? -1,
    type: type,
    answer: answer.text.trim(),
    options: type == 'True or false'
        ? ['True', 'False']
        : type == 'Multiple choice'
        ? options.map((option) => option.text.trim()).toList()
        : [],
  );

  void dispose() {
    prompt.dispose();
    points.dispose();
    answer.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}
