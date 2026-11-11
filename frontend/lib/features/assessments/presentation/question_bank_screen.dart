import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/instructor_quiz_providers.dart';
import '../domain/bank_question.dart';
import '../domain/quiz_draft.dart';
import 'question_card.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key, this.picking = false, this.course});
  final bool picking;
  final String? course;
  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  List<BankQuestion>? _rows;
  final _selected = <String>{};
  String _search = '', _type = 'all';
  String? _courseFilter;
  String? _error;
  bool _loading = true, _busy = false;
  String? _deletingId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading && _rows != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.picking &&
          (widget.course == null || widget.course!.trim().isEmpty)) {
        throw StateError('Course unavailable');
      }
      final repository = await ref.read(questionBankRepositoryProvider.future);
      final rows = await repository.list(
        course: widget.picking ? widget.course : null,
      );
      if (!mounted) return;
      setState(() {
        _rows = widget.picking
            ? rows
                  .where(
                    (row) =>
                        row.courseKey == widget.course!.trim().toLowerCase(),
                  )
                  .toList()
            : rows;
        _selected.removeWhere((id) => !_rows!.any((r) => r.id == id));
        if (_courseFilter != null &&
            !_rows!.any((row) => (row.courseKey ?? '') == _courseFilter))
          _courseFilter = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              widget.picking &&
                  (widget.course == null || widget.course!.trim().isEmpty)
              ? 'Course unavailable. Return to Classwork, refresh the class and try again.'
              : 'Could not load the question bank. Connect and retry.',
        );
      }
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
    if (_busy || _loading) return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Delete this saved question?',
      message: 'This removes it from your bank. Questions already added to assessments stay unchanged.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      icon: FiloIcons.delete,
    );
    if (!confirmed || !mounted || _busy || _loading) return;
    setState(() {
      _busy = true;
      _deletingId = row.id;
    });
    try {
      final repository = await ref.read(questionBankRepositoryProvider.future);
      await repository.delete(row.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Deletion not confirmed. Refresh the bank before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addSelected() {
    final selected = _rows!.where((r) => _selected.contains(r.id)).toList();
    final copies = selected.map((r) => r.tryCopyToQuiz()).toList();
    if (selected.length != _selected.length || copies.any((q) => q == null)) {
      setState(() => _error = BankQuestion.invalidContentMessage);
      return;
    }
    Navigator.pop(context, copies.cast<QuizQuestion>());
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
    final available = online && _rows != null && _error == null;
    final matching = (_rows ?? [])
        .where(
          (r) =>
              (_courseFilter == null || (r.courseKey ?? '') == _courseFilter) &&
              (_type == 'all' || r.row['type'] == _type) &&
              (r.row['prompt'] as String).toLowerCase().contains(
                _search.toLowerCase().trim(),
              ),
        )
        .toList();
    final courses =
        (_rows ?? []).map((row) => row.courseKey ?? '').toSet().toList()
          ..sort();
    final filtered = [
      for (final course in courses)
        ...matching.where((row) => (row.courseKey ?? '') == course),
    ];
    String courseLabel(String key) => key.isEmpty
        ? 'Unassigned'
        : _rows!.firstWhere((row) => row.courseKey == key).course!;
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
              if (index == 0) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FiloSpacing.screen,
                        FiloSpacing.s12,
                        FiloSpacing.screen,
                        FiloSpacing.s8,
                      ),
                      child: Column(
                        children: [
                          if (widget.picking) ...[
                            Text(
                              widget.course ?? 'Course unavailable',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton.icon(
                              icon: const FiloIcon(FiloIcons.folder),
                              label: const Text('Manage saved questions'),
                              onPressed: _busy || _loading
                                  ? null
                                  : () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const QuestionBankScreen(),
                                        ),
                                      );
                                      if (mounted) await _load();
                                    },
                            ),
                          ] else if (_rows != null) ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey(_courseFilter),
                              initialValue: _courseFilter,
                              hint: const Text('All courses'),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Course',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All courses'),
                                ),
                                for (final course in courses)
                                  DropdownMenuItem(
                                    value: course,
                                    child: Text(courseLabel(course)),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _courseFilter = value),
                            ),
                            const SizedBox(height: FiloSpacing.s16),
                          ],
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Search questions',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                          const SizedBox(height: FiloSpacing.s12),
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
                        padding: EdgeInsets.all(FiloSpacing.screen),
                        child: EmptyState(
                          title: "You're offline. Connect, then refresh to use the question bank.",
                          pose: 'sleepy',
                          bob: false,
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(FiloSpacing.screen),
                        child: EmptyState(
                          title: _error!,
                          pose: 'confused',
                          bob: false,
                          action: TextButton(
                            onPressed: online && !_busy && !_loading
                                ? _load
                                : null,
                            child: const Text('Retry'),
                          ),
                        ),
                      ),
                    if (_loading && _rows == null)
                      const Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: FiloCircularProgressIndicator(
                            semanticsLabel: 'Loading question bank',
                          ),
                        ),
                      ),
                  ],
                );
              }
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(FiloSpacing.screen),
                  child: EmptyState(
                    pose: _rows!.isEmpty ? 'thinking' : 'curious',
                    bob: !widget.picking,
                    title: _rows!.isEmpty
                        ? widget.picking
                              ? 'No saved questions for this course yet.'
                              : 'Your question bank is empty.'
                        : 'No matching questions. Try another course, search or question type.',
                    message: _rows!.isEmpty
                        ? 'Save a question from an assessment to reuse it here. Older questions can be assigned to a course in Manage saved questions.'
                        : '',
                  ),
                );
              }
              final row = filtered[index - 1];
              final q = row.tryCopyToQuiz();
              if (q == null) {
                return Padding(
                  padding: const EdgeInsets.all(FiloSpacing.screen),
                  child: FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.row['prompt'] is String
                              ? row.row['prompt'] as String
                              : 'Saved question',
                        ),
                        const Text(BankQuestion.invalidContentMessage),
                        if (!widget.picking)
                          TextButton(
                            onPressed: _loading || _busy
                                ? null
                                : () => _delete(row),
                            child: const Text('Delete'),
                          ),
                      ],
                    ),
                  ),
                );
              }
              if (widget.picking) {
                return CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(q.prompt),
                  subtitle: Text(
                    '${questionTypeLabels[q.type]} / ${q.points} points',
                  ),
                  value: _selected.contains(row.id),
                  onChanged: _loading || _busy
                      ? null
                      : (value) => setState(() {
                          value == true
                              ? _selected.add(row.id)
                              : _selected.remove(row.id);
                        }),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  FiloSpacing.screen,
                  0,
                  FiloSpacing.screen,
                  FiloSpacing.s12,
                ),
                child: FiloPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index == 1 ||
                          filtered[index - 2].courseKey != row.courseKey) ...[
                        Semantics(
                          header: true,
                          child: Text(
                            courseLabel(row.courseKey ?? ''),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: FiloSpacing.s16),
                      ],
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
                              onPressed: _loading || _busy
                                  ? null
                                  : () => _edit(row),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: _loading || _busy
                                  ? null
                                  : () => _delete(row),
                              child: _busy && _deletingId == row.id
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: FiloCircularProgressIndicator(
                                        strokeWidth: 2,
                                        semanticsLabel: 'Deleting question',
                                      ),
                                    )
                                  : const Text('Delete'),
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
            padding: const EdgeInsets.fromLTRB(
              FiloSpacing.screen,
              FiloSpacing.s12,
              FiloSpacing.screen,
              0,
            ),
            child: FiloButton(
              label: 'Add selected (${_selected.length})',
              onPressed:
                  available && !_loading && !_busy && _selected.isNotEmpty
                  ? _addSelected
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
  late String _course = widget.row.course ?? '';
  Future<void> _save() async {
    if (_course.trim().isEmpty || _course.trim().length > 120) {
      setState(() => _error = 'Enter a course of 1 to 120 characters.');
      return;
    }
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
      await repository.save(widget.row.id, _question, course: _course);
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Save not confirmed. Your edits are retained. Connect and retry.',
        );
      }
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
            padding: const EdgeInsets.all(FiloSpacing.screen),
            children: [
              if (!online)
                const Text("You're offline. Connect to save changes."),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              TextFormField(
                initialValue: _course,
                enabled: !_busy,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  hintText: 'Assign this saved question to a course',
                ),
                onChanged: (value) => setState(() {
                  _course = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: FiloSpacing.s16),
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
