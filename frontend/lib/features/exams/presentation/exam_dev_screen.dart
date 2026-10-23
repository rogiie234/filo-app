import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/exam_providers.dart';
import '../application/student_exam_repository.dart';
import '../domain/exam.dart';

const examDevEnabled = kDebugMode && AppConfig.environment == 'dev';

class ExamDevScreen extends ConsumerStatefulWidget {
  const ExamDevScreen({super.key});
  @override
  ConsumerState<ExamDevScreen> createState() => _ExamDevScreenState();
}

class _ExamDevScreenState extends ConsumerState<ExamDevScreen> {
  final _quizId = TextEditingController();
  final _text = <String, TextEditingController>{};
  bool _busy = false;
  String? _message;
  String? _session;

  @override
  void dispose() {
    _quizId.dispose();
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _perform(
    Future<void> Function(StudentExamRepository) action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repository = await ref.read(studentExamRepositoryProvider.future);
      if (repository == null)
        throw StateError('Sign in with a verified student account.');
      await action(repository);
    } catch (e) {
      if (mounted)
        setState(
          () =>
              _message = e is StateError ? e.message.toString() : e.toString(),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(ExamAnswer answer) async {
    try {
      final repository = await ref.read(studentExamRepositoryProvider.future);
      await repository?.answer(answer);
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!examDevEnabled)
      return const Scaffold(body: Center(child: Text('Page unavailable')));
    ref.watch(examLifecycleProvider);
    ref.watch(examUpdatesProvider);
    final repositoryState = ref.watch(studentExamRepositoryProvider);
    final repository = repositoryState.asData?.value;
    final attempt = ref.watch(activeExamProvider);
    final answers = ref.watch(examAnswersProvider);
    final remaining =
        ref.watch(examCountdownProvider).asData?.value ?? Duration.zero;
    final editable =
        !_busy &&
        repository?.clock.canEdit == true &&
        repository?.submitting != true;
    if (_session != attempt?.sessionId) {
      for (final controller in _text.values) {
        controller.dispose();
      }
      _text.clear();
      _session = attempt?.sessionId;
    }
    final byQuestion = {
      for (final saved in answers.asData?.value ?? [])
        saved.answer.questionId: saved.answer,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('DEV exam data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Development harness — starts a real DEV attempt. Production exam screens are separate.',
            ),
            if (repositoryState.isLoading) const LinearProgressIndicator(),
            if (repositoryState.hasError)
              const Text(
                'Could not open exam storage. Reopen this screen to retry.',
              ),
            if (repositoryState.asData != null && repository == null)
              const Text('A verified student account is required.'),
            if (_message != null) Text(_message!, semanticsLabel: _message),
            if (repository?.error != null) Text(repository!.error!.message),
            if (repository?.completion != null) Text(repository!.completion!),
            const SizedBox(height: 16),
            FiloButton(
              label: 'Reload / detect attempt',
              onPressed: _busy ? null : () => _perform((r) => r.recover()),
            ),
            if (attempt == null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _quizId,
                decoration: const InputDecoration(labelText: 'DEV quiz UUID'),
              ),
              const SizedBox(height: 12),
              FiloButton(
                label: 'Start / load quiz',
                onPressed: _busy
                    ? null
                    : () => _perform((r) => r.start(_quizId.text.trim())),
              ),
              const SizedBox(height: 16),
              ref
                  .watch(studentQuizzesProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => FiloButton(
                      label: 'Retry quiz list',
                      onPressed: () => ref.invalidate(studentQuizzesProvider),
                    ),
                    data: (quizzes) => Column(
                      children: [
                        if (quizzes.isEmpty)
                          const Text('No published quizzes in active classes.'),
                        for (final quiz in quizzes)
                          ListTile(
                            title: Text(quiz.title),
                            subtitle: Text(
                              quiz.session?.status ?? 'No attempt',
                            ),
                            onTap: _busy
                                ? null
                                : () => _perform((r) => r.start(quiz.id)),
                          ),
                      ],
                    ),
                  ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Time left: ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
              ),
              if (!repository!.clock.verified)
                const Text(
                  'Estimated time only. Reconnect to verify the deadline.',
                ),
              Text(ref.watch(examSavingStateProvider)),
              if (remaining == Duration.zero)
                const Text("Time's up. Reconnect to check your submission."),
              if (answers.isLoading && !answers.hasValue)
                const LinearProgressIndicator(),
              for (final question in attempt.questions) ...[
                const SizedBox(height: 24),
                Text(question.prompt),
                const SizedBox(height: 8),
                if (question.type == 'multiple_choice')
                  for (final option in question.options)
                    CheckboxListTile(
                      title: Text(option['text'] as String),
                      value: byQuestion[question.id]?.optionId == option['id'],
                      onChanged: !editable
                          ? null
                          : (_) => unawaited(
                              _answer(
                                ExamAnswer(
                                  questionId: question.id,
                                  optionId: option['id'] as String,
                                ),
                              ),
                            ),
                    ),
                if (question.type == 'true_false')
                  for (final value in [true, false])
                    CheckboxListTile(
                      title: Text(value ? 'True' : 'False'),
                      value: byQuestion[question.id]?.boolean == value,
                      onChanged: !editable
                          ? null
                          : (_) => unawaited(
                              _answer(
                                ExamAnswer(
                                  questionId: question.id,
                                  boolean: value,
                                ),
                              ),
                            ),
                    ),
                if (question.type == 'identification' ||
                    question.type == 'essay')
                  if (answers.asData != null)
                    TextField(
                      controller: _text.putIfAbsent(
                        question.id,
                        () => TextEditingController(
                          text: byQuestion[question.id]?.text ?? '',
                        ),
                      ),
                      enabled: editable,
                      maxLines: question.type == 'essay' ? 5 : 1,
                      decoration: const InputDecoration(labelText: 'Answer'),
                      onChanged: (value) => unawaited(
                        _answer(
                          ExamAnswer(questionId: question.id, text: value),
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 24),
              FiloButton(
                label: 'Submit',
                onPressed: _busy
                    ? null
                    : () async {
                        final confirmed = await showFiloConfirmation(
                          context,
                          title: 'Submit your answers?',
                          message: "You can't change them afterward.",
                          confirmLabel: 'Submit',
                        );
                        if (confirmed == true && mounted)
                          await _perform((r) => r.submit());
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
