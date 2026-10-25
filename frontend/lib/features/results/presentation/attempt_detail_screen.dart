import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../exams/domain/student_quiz_status.dart';
import '../../grading/application/grading_providers.dart';
import '../application/results_providers.dart';
import '../data/results_failure.dart';
import '../domain/results.dart';
import 'results_actions.dart';
import 'results_widgets.dart';

class AttemptDetailScreen extends ConsumerStatefulWidget {
  const AttemptDetailScreen({
    super.key,
    required this.quizId,
    required this.sessionId,
  });
  final String quizId, sessionId;
  @override
  ConsumerState<AttemptDetailScreen> createState() =>
      _AttemptDetailScreenState();
}

class _EssayEdit {
  _EssayEdit(Map? answer)
    : points = TextEditingController(
        text: answer?['points_awarded']?.toString() ?? '',
      ),
      feedback = TextEditingController(
        text: answer?['feedback'] as String? ?? '',
      ) {
    accept();
  }
  final TextEditingController points, feedback;
  late String originalPoints, originalFeedback;
  bool get dirty =>
      points.text != originalPoints || feedback.text != originalFeedback;
  void accept() {
    originalPoints = points.text;
    originalFeedback = feedback.text;
  }

  void dispose() {
    points.dispose();
    feedback.dispose();
  }
}

class _AttemptDetailScreenState extends ConsumerState<AttemptDetailScreen> {
  late String _session;
  final _edits = <String, _EssayEdit>{};
  bool _busy = false, _allowPop = false, _reconcile = false;
  String? _error;
  ResultAttemptKey get _key => (quizId: widget.quizId, sessionId: _session);
  AttemptDetail? get _detail =>
      ref.read(resultAttemptProvider(_key)).asData?.value.data;
  bool get _online => ref.read(connectivityProvider).asData?.value == true;
  bool get _dirty => _edits.values.any((e) => e.dirty);
  @override
  void initState() {
    super.initState();
    _session = widget.sessionId;
  }

  void _clear() {
    for (final edit in _edits.values) {
      edit.dispose();
    }
    _edits.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(instructorResultsRepositoryProvider.future);
      await repo!.refreshQuiz(widget.quizId);
      final detail = await repo.refreshDetail(widget.quizId, _session);
      if (!mounted) return;
      if (!_dirty) _clear();
      for (final q in detail.questions) {
        final edit = _edits[q['id']];
        final answer = q['answer'] as Map?;
        if (edit != null &&
            edit.points.text == answer?['points_awarded']?.toString() &&
            edit.feedback.text == (answer?['feedback'] ?? ''))
          edit.accept();
      }
      setState(() => _reconcile = false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save(String questionId) async {
    if (_busy || !_online || _reconcile) return false;
    final detail = _detail;
    final edit = _edits[questionId];
    if (detail == null || edit == null || detail.readOnly) return false;
    final q = detail.questions.where((q) => q['id'] == questionId).first;
    final points = int.tryParse(edit.points.text.trim());
    if (points == null) {
      setState(() => _error = 'Enter a whole-number score.');
      return false;
    }
    if (points < 0 || points > (q['points'] as int)) {
      setState(() => _error = 'Points must be between 0 and ${q['points']}');
      return false;
    }
    if (edit.feedback.text.runes.length > 2000) {
      setState(() => _error = 'Feedback must be at most 2,000 characters.');
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(instructorResultsRepositoryProvider.future);
      final answer = q['answer'] as Map?;
      if (answer?['id'] == null) throw const ResultsFailure('No answer');
      final message = await repo!.gradeEssay(
        widget.quizId,
        _session,
        answer!['id'] as String,
        points,
        feedback: edit.feedback.text.isEmpty ? null : edit.feedback.text,
      );
      if (!mounted) return false;
      edit.accept();
      ref.invalidate(gradingSyncProvider(detail.quiz['class_id'] as String));
      showMessage(context, message);
      return true;
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _reconcile = e is ResultsFailure && e.uncertain;
        });
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _leave() async {
    if (_busy) return false;
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Save changes before leaving?'),
        content: const Text(
          'Save your changes or discard them before leaving this answer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'discard'),
            child: const Text('Discard changes'),
          ),
          FilledButton(
            onPressed: _online && !_reconcile
                ? () => Navigator.pop(dialog, 'save')
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (choice == 'discard') return true;
    if (choice != 'save') return false;
    for (final id in _edits.keys.toList()) {
      if (_edits[id]!.dirty && !await _save(id)) return false;
    }
    return true;
  }

  Future<void> _move(String session) async {
    if (!await _leave() || !mounted) return;
    setState(() {
      _clear();
      _session = session;
      _error = null;
      _reconcile = false;
    });
  }

  Future<void> _override(ResultJson question) async {
    if (!await _leave() || !mounted) return;
    final points = TextEditingController(
      text: (question['answer'] as Map?)?['points_awarded']?.toString() ?? '0',
    );
    final feedback = TextEditingController(
      text: (question['answer'] as Map?)?['feedback'] as String? ?? '',
    );
    final form = GlobalKey<FormState>();
    final value = await showDialog<(int, String)>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Change points?'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This replaces the current mark and updates the total. Saving may release results when grading is complete.',
                ),
                TextFormField(
                  controller: points,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Points',
                    helperText: '0 to ${question['points']}',
                  ),
                  validator: (text) {
                    final n = int.tryParse(text?.trim() ?? '');
                    return n == null
                        ? 'Enter a whole-number score.'
                        : n < 0 || n > (question['points'] as int)
                        ? 'Points must be between 0 and ${question['points']}'
                        : null;
                  },
                ),
                TextFormField(
                  controller: feedback,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Feedback'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(dialog, (
                  int.parse(points.text.trim()),
                  feedback.text,
                ));
            },
            child: const Text('Change points'),
          ),
        ],
      ),
    );
    // Controllers remain alive until the dialog's closing animation has completed.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    points.dispose();
    feedback.dispose();
    if (value == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(instructorResultsRepositoryProvider.future);
      final message = await repo!.overridePoints(
        widget.quizId,
        _session,
        question['id'] as String,
        value.$1,
        feedback: value.$2.isEmpty ? null : value.$2,
      );
      if (mounted) {
        _clear();
        showMessage(context, message);
        ref.invalidate(
          gradingSyncProvider(_detail!.quiz['class_id'] as String),
        );
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _reconcile = e is ResultsFailure && e.uncertain;
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(resultAttemptProvider(_key));
    final state = async.asData?.value;
    final detail = state?.data;
    final monitor = ref
        .watch(quizMonitoringProvider(widget.quizId))
        .asData
        ?.value
        .data;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final readOnly = state?.readOnly != false || _busy || _reconcile;
    final submitted = monitor?.current.where((s) => s.submitted).toList() ?? [];
    submitted.sort((a, b) => a.studentName.compareTo(b.studentName));
    final index = submitted.indexWhere((s) => s.id == _session);
    final questions = detail?.questions.toList() ?? [];
    questions.sort(
      (a, b) =>
          (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0),
    );
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _leave() && mounted) {
          setState(() => _allowPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(detail?.session.studentName ?? 'Attempt detail'),
        ),
        body: SafeArea(
          child: ResultsListBody(
            onRefresh: _refresh,
            offline: !online,
            loading: async.isLoading,
            error:
                _error ??
                state?.error ??
                (async.hasError ? "Couldn't load results. Try again." : null),
            children: [
              if (detail != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ResultStatusChip(
                      detail.readOnly
                          ? 'Previous attempt'
                          : quizResultStatus(
                              detail.session,
                              hasEssay: detail.quiz['has_essay'] == true,
                            ).label,
                    ),
                    Text('Attempt ${detail.session.attempt}'),
                    Text('Leave-app count: ${detail.session.leaves}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${detail.session.score ?? '—'}/${detail.quiz['total_points']} points',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  detail.session.json['submitted_at'] == null
                      ? 'Not submitted'
                      : 'Submitted ${philippineQuizDate(DateTime.parse(detail.session.json['submitted_at'] as String))}',
                ),
                if (detail.readOnly)
                  for (final chance in monitor?.secondChances ?? <ResultJson>[])
                    if (chance['previous_session_id'] == detail.session.id) ...[
                      Text('Reason: ${chance['reason']}'),
                      if (chance['proof_note'] != null)
                        Text('Proof note: ${chance['proof_note']}'),
                    ],
                Text(
                  '${detail.pendingEssays} ${detail.pendingEssays == 1 ? 'essay' : 'essays'} to grade',
                ),
                if (detail.quiz['results_released_at'] != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'The student will see the updated score at the next sync.',
                    ),
                  ),
                if ((detail.quiz['class'] as Map?)?['archived_at'] != null)
                  const Text('This class is archived.'),
                if (!online)
                  const Text('Connect to the internet to save grades.'),
                if (!detail.readOnly)
                  TextButton(
                    onPressed: readOnly
                        ? null
                        : () async {
                            if (await _leave() && context.mounted)
                              await openSecondChance(
                                context,
                                widget.quizId,
                                detail.session.studentId,
                              );
                          },
                    child: const Text('Grant second chance'),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: !_busy && index > 0
                          ? () => _move(submitted[index - 1].id)
                          : null,
                      child: const Text('Previous'),
                    ),
                    Expanded(
                      child: Text(
                        index < 0
                            ? 'Previous attempt'
                            : '${index + 1} of ${submitted.length}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          !_busy && index >= 0 && index + 1 < submitted.length
                          ? () => _move(submitted[index + 1].id)
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
                for (final entry in questions.indexed)
                  Builder(
                    builder: (_) {
                      final q = entry.$2;
                      final answer = q['answer'] as Map?;
                      final canGrade =
                          q['type'] == 'essay' &&
                          !blankEssay(answer?['text_answer']) &&
                          detail.session.submitted &&
                          !detail.readOnly;
                      final edit = canGrade
                          ? _edits.putIfAbsent(
                              q['id'] as String,
                              () => _EssayEdit(answer),
                            )
                          : null;
                      if (edit != null && !edit.dirty) {
                        edit.points.text =
                            answer?['points_awarded']?.toString() ?? '';
                        edit.feedback.text =
                            answer?['feedback'] as String? ?? '';
                        edit.accept();
                      }
                      return ResultQuestionCard(
                        answerLabel: 'Student answer',
                        question: instructorReview(q),
                        number: entry.$1 + 1,
                        editor: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (overriddenMark(answer))
                              const Text(
                                'Edited',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            if (edit != null) ...[
                              TextField(
                                controller: edit.points,
                                enabled: !readOnly,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Points',
                                  helperText: '0 to ${q['points']}',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: edit.feedback,
                                enabled: !readOnly,
                                maxLength: 2000,
                                minLines: 2,
                                maxLines: 4,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Feedback',
                                ),
                              ),
                              FiloButton(
                                label: 'Save',
                                onPressed: readOnly || !edit.dirty
                                    ? null
                                    : () => _save(q['id'] as String),
                              ),
                            ],
                            if (!detail.readOnly && detail.session.submitted)
                              TextButton(
                                onPressed: readOnly ? null : () => _override(q),
                                child: const Text('Change points'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                if (monitor != null)
                  ExpansionTile(
                    title: const Text('Earlier attempts'),
                    children: [
                      for (final old in monitor.history.where(
                        (s) =>
                            s.studentId == detail.session.studentId &&
                            s.id != _session,
                      ))
                        AttemptHistory(
                          quizId: widget.quizId,
                          session: old,
                          chances: monitor.secondChances,
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AttemptHistory extends ConsumerWidget {
  const AttemptHistory({
    super.key,
    required this.quizId,
    required this.session,
    required this.chances,
  });
  final String quizId;
  final ResultSession session;
  final List<ResultJson> chances;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ExpansionTile(
    title: Text('Attempt ${session.attempt} · read-only'),
    children: [
      for (final chance in chances.where(
        (c) => c['previous_session_id'] == session.id,
      ))
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason: ${chance['reason']}'),
              if (chance['proof_note'] != null)
                Text('Proof note: ${chance['proof_note']}'),
            ],
          ),
        ),
      _HistoryAnswers(quizId: quizId, sessionId: session.id),
    ],
  );
}

class _HistoryAnswers extends ConsumerWidget {
  const _HistoryAnswers({required this.quizId, required this.sessionId});
  final String quizId, sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (quizId: quizId, sessionId: sessionId);
    final state = ref.watch(resultAttemptProvider(key));
    final data = state.asData?.value;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (state.isLoading) const ResultsSkeleton(),
          if (data?.error != null || state.hasError)
            Text(data?.error ?? "Couldn't load results. Try again."),
          for (final entry in (data?.data?.questions ?? <ResultJson>[]).indexed)
            ResultQuestionCard(
              answerLabel: 'Student answer',
              question: instructorReview(entry.$2),
              number: entry.$1 + 1,
            ),
          TextButton(
            onPressed: () => ref.invalidate(resultAttemptProvider(key)),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
