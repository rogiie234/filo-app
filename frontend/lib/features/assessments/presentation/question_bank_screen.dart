import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/instructor_quiz_providers.dart';
import '../domain/bank_question.dart';
import '../domain/quiz_draft.dart';
import 'question_card.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key, this.picking = false});
  final bool picking;
  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  List<BankQuestion>? _rows;
  final _selected = <String>{};
  String _search = '', _type = 'all';
  String? _error;
  bool _loading = true, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = await ref.read(questionBankRepositoryProvider.future);
      final rows = await repository.list();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _selected.removeWhere((id) => !rows.any((r) => r.id == id));
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not load the question bank. Connect and retry.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(BankQuestion row) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => _BankEditor(row: row)));
    if (mounted) await _load();
  }

  Future<void> _delete(BankQuestion row) async {
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Delete this saved question?',
      message: 'This removes it from your bank. Questions already added to assessments stay unchanged.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      icon: FiloIcons.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final repository = await ref.read(questionBankRepositoryProvider.future);
      await repository.delete(row.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Deletion not confirmed. Refresh the bank before trying again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (previous, next) {
      if (next.asData?.value != true) {
        setState(() {
          _rows = null;
          _selected.clear();
        });
      } else if (previous?.asData?.value != true && !_loading && !_busy) {
        _load();
      }
    });
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final available =
        online && _rows != null && !_loading && !_busy && _error == null;
    final filtered = (_rows ?? [])
        .where(
          (r) =>
              (_type == 'all' || r.row['type'] == _type) &&
              (r.row['prompt'] as String).toLowerCase().contains(
                _search.toLowerCase().trim(),
              ),
        )
        .toList();
    final content = Column(
      mainAxisSize: widget.picking ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Flexible(
          fit: widget.picking ? FlexFit.loose : FlexFit.tight,
          child: ListView.builder(
            shrinkWrap: widget.picking && filtered.length < 8,
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount:
                1 + (available ? (filtered.isEmpty ? 1 : filtered.length) : 0),
            itemBuilder: (context, index) {
              if (index == 0)
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search questions',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _type,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Question type',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All types'),
                              ),
                              for (final entry in questionTypeLabels.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? 'all'),
                          ),
                        ],
                      ),
                    ),
                    if (!online)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "You're offline. Connect, then refresh to use the question bank.",
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: online && !_busy ? _load : null,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    if (_loading || _busy) const LinearProgressIndicator(),
                  ],
                );
              if (filtered.isEmpty)
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _rows!.isEmpty
                        ? 'No saved questions yet. Use Save to bank on a question in an assessment.'
                        : 'No matching questions. Try another search or question type.',
                  ),
                );
              final row = filtered[index - 1];
              final q = row.copyToQuiz();
              if (widget.picking) {
                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(q.prompt),
                  subtitle: Text(
                    '${questionTypeLabels[q.type]} / ${q.points} points',
                  ),
                  value: _selected.contains(row.id),
                  onChanged: (value) => setState(() {
                    value == true
                        ? _selected.add(row.id)
                        : _selected.remove(row.id);
                  }),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: FiloPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.prompt,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${questionTypeLabels[q.type]} / ${q.points} points',
                      ),
                      if (q.type == 'multiple_choice')
                        for (var i = 0; i < q.optionTexts.length; i++)
                          Text(
                            '${i == q.answerKey!.correctOptionIndex ? 'Correct: ' : ''}${q.optionTexts[i]}',
                          ),
                      if (q.type == 'true_false')
                        Text(
                          'Answer: ${q.answerKey!.correctBoolean == true ? 'True' : 'False'}',
                        ),
                      if (q.type == 'identification')
                        Text(
                          'Accepted answers: ${q.answerKey!.acceptedAnswers.join(', ')}',
                        ),
                      if (q.type == 'essay') const Text('Manually graded'),
                      if (q.explanation?.isNotEmpty == true)
                        Text('Explanation: ${q.explanation}'),
                      if (!widget.picking)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () => _edit(row),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: () => _delete(row),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.picking)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: FiloButton(
              label: 'Add selected (${_selected.length})',
              onPressed: available && _selected.isNotEmpty
                  ? () => Navigator.pop(
                      context,
                      _rows!
                          .where((r) => _selected.contains(r.id))
                          .map((r) => r.copyToQuiz())
                          .toList(),
                    )
                  : null,
            ),
          ),
      ],
    );
    if (widget.picking) return content;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Question bank'),
          actions: [
            IconButton(
              tooltip: 'Refresh bank',
              onPressed: online && !_busy && !_loading ? _load : null,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(child: content),
      ),
    );
  }
}

class _BankEditor extends ConsumerStatefulWidget {
  const _BankEditor({required this.row});
  final BankQuestion row;
  @override
  ConsumerState<_BankEditor> createState() => _BankEditorState();
}

class _BankEditorState extends ConsumerState<_BankEditor> {
  late final QuizQuestion _question = widget.row.copyToQuiz();
  late final QuestionEditorState _editor = QuestionEditorState(_question);
  final _cardKey = GlobalKey();
  bool _busy = false, _dirty = false;
  String? _error;
  Future<void> _save() async {
    setState(
      () => _editor.errors = _question.validationErrors(
        pointsText: _editor.points,
        pendingAnswer: _editor.pendingAnswer,
      ),
    );
    if (_editor.errors.isNotEmpty) {
      final target = _cardKey.currentContext;
      if (target != null) await revealQuestionError(target, _editor.errors);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(questionBankRepositoryProvider.future);
      await repository.save(widget.row.id, _question);
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Save not confirmed. Your edits are retained. Connect and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final discard =
        !_dirty ||
        await showFiloConfirmation(
          context,
          title: 'Discard changes?',
          message: 'Your changes to this saved question will be lost.',
          confirmLabel: 'Discard',
          cancelLabel: 'Keep editing',
          icon: FiloIcons.delete,
        );
    if (discard && mounted) {
      setState(() => _dirty = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit saved question'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _busy ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!online)
                const Text("You're offline. Connect to save changes."),
              if (_error != null) Text(_error!),
              QuestionCard(
                key: _cardKey,
                question: _question,
                editor: _editor,
                index: 0,
                expanded: true,
                enabled: !_busy,
                showActions: false,
                onToggle: () {},
                onChanged: () => setState(() => _dirty = true),
                onAction: (_) {},
              ),
              FiloButton(
                onPressed: online && !_busy ? _save : null,
                busy: _busy,
                label: 'Save changes',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
