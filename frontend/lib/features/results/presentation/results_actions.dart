import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../assessments/domain/quiz_helpers.dart';
import '../../assessments/application/instructor_quiz_providers.dart';
import '../application/results_providers.dart';
import '../domain/results.dart';
import '../data/results_failure.dart';
import 'results_widgets.dart';

Future<void> releaseQuizResults(
  BuildContext context,
  WidgetRef ref,
  String quizId,
) async {
  try {
    final repo = await ref.read(instructorResultsRepositoryProvider.future);
    if (repo == null) return;
    final data = await repo.refreshQuiz(quizId);
    final blocked = data.releaseBlocked(DateTime.now().toUtc());
    if (!context.mounted) return;
    if (blocked != null) {
      showMessage(context, blocked);
      return;
    }
    final count = data.notStarted.length;
    final accepted = await showFiloConfirmation(
      context,
      title: 'Release results?',
      confirmLabel: 'Release results',
      cancelLabel: 'Cancel',
      message:
          'Students who took this quiz will be able to see their scores. They can review answers only if Show correct answers is on.\n\n'
          '${data.submittedCount} of ${data.members.length} ${data.members.length == 1 ? 'student' : 'students'} submitted\n'
          '$count ${count == 1 ? 'student has' : 'students have'} not started.\n\n'
          'Releasing results closes this quiz for anyone who has not started. They will not be able to take it.',
    );
    if (!accepted) return;
    final message = await repo.releaseResults(quizId);
    ref.invalidate(quizMonitoringProvider(quizId));
    if (context.mounted) showMessage(context, message);
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString());
  }
}

Future<void> openSecondChance(
  BuildContext context,
  String quizId,
  String studentId,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => SecondChanceScreen(quizId: quizId, studentId: studentId),
  ),
);

class SecondChanceScreen extends ConsumerStatefulWidget {
  const SecondChanceScreen({
    super.key,
    required this.quizId,
    required this.studentId,
  });
  final String quizId, studentId;
  @override
  ConsumerState<SecondChanceScreen> createState() => _SecondChanceScreenState();
}

class _SecondChanceScreenState extends ConsumerState<SecondChanceScreen> {
  final _reason = TextEditingController(), _proof = TextEditingController();
  bool _busy = false;
  QuizMonitoring? _data;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _reason.dispose();
    _proof.dispose();
    super.dispose();
  }

  bool get _online => ref.read(connectivityProvider).asData?.value == true;
  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(instructorResultsRepositoryProvider.future);
      final data = await repo?.refreshQuiz(widget.quizId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend() async {
    final now = utcToManila(DateTime.now().toUtc());
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(instructorResultsRepositoryProvider.future);
      await repo!.extendClosing(
        widget.quizId,
        manilaToUtc(date.year, date.month, date.day, time.hour, time.minute),
      );
      ref.invalidate(
        instructorQuizListRefreshProvider(_data!.quiz['class_id'] as String),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _refresh();
  }

  Future<void> _grant() async {
    if (_busy || !_online) return;
    if (_reason.text.trim().runes.length < 10) {
      setState(
        () => _error = 'Please give a reason of at least 10 characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(instructorResultsRepositoryProvider.future);
      final fresh = await repo!.refreshQuiz(widget.quizId);
      final attempt = fresh.attemptFor(widget.studentId);
      if (fresh.quiz['results_released_at'] != null)
        throw const ResultsFailure(
          'Results are already released. Create a new quiz instead.',
        );
      if (attempt == null)
        throw const ResultsFailure('This student has no attempt to reset.');
      final name = attempt.studentName;
      if (!mounted) return;
      final accepted = await showFiloConfirmation(
        context,
        title: 'Allow another attempt?',
        confirmLabel: 'Allow another attempt',
        cancelLabel: 'Cancel',
        message:
            "$name's current attempt will be archived. The student can start another attempt before the quiz closes. The previous answers and score will not carry over to the new attempt. The reason and proof note will be recorded.",
      );
      if (!accepted) return;
      final message = await repo.grantSecondChance(
        widget.quizId,
        widget.studentId,
        expectedSessionId: attempt.id,
        reason: _reason.text,
        proof: _proof.text.isEmpty ? null : _proof.text,
      );
      ref.invalidate(quizMonitoringProvider(widget.quizId));
      if (mounted) {
        showMessage(context, message);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final data = _data;
    final attempt = data?.attemptFor(widget.studentId);
    final released = data?.quiz['results_released_at'] != null;
    final closes = DateTime.tryParse('${data?.quiz['closes_at']}');
    final closed = closes != null && !closes.isAfter(DateTime.now().toUtc());
    final archived = (data?.quiz['class'] as Map?)?['archived_at'] != null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Grant second chance')),
        body: SafeArea(
          child: ResultsListBody(
            loading: _busy && data == null,
            offline: !online,
            error: _error,
            onRefresh: _refresh,
            children: [
              if (data != null)
                if (released)
                  const Text(
                    'Results are already released. Create a new quiz instead.',
                  )
                else if (attempt == null)
                  const Text('This student has no attempt to reset.')
                else if (archived)
                  const Text('This class is archived.')
                else ...[
                  Text(
                    attempt.studentName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (closed) ...[
                    const Text(
                      'Extend the closing time first so the student can retake it.',
                    ),
                    TextButton(
                      onPressed: online && !_busy ? _extend : null,
                      child: const Text('Extend closing time'),
                    ),
                  ],
                  TextField(
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      hintText:
                          'At least 10 characters. Describe what happened.',
                      counterText: '${_reason.text.runes.length} characters',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _proof,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Proof note',
                      hintText:
                          'Optional. For example: showed the phone in person.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!online)
                    const Text(
                      'Connect to the internet to allow another attempt.',
                    ),
                  FiloButton(
                    label: _busy ? 'Please wait...' : 'Continue',
                    onPressed: online && !_busy && !closed ? _grant : null,
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
