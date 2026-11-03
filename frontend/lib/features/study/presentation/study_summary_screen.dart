import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/database_providers.dart';
import '../application/student_ai_providers.dart';
import '../application/study_providers.dart';
import '../application/study_summary_session.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import '../domain/study_summary_usage.dart';
import 'study_chat_message.dart';
import 'study_privacy.dart';
import 'study_widgets.dart';

class StudySummaryScreen extends ConsumerWidget {
  const StudySummaryScreen({super.key, required this.notebookId});
  final String notebookId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(accountDatabaseProvider);
    final repository = ref.watch(studySummaryRepositoryProvider);
    if (!database.isLoading &&
        !database.hasError &&
        database.asData?.value != null &&
        !repository.isLoading &&
        !repository.hasError &&
        repository.asData?.value != null)
      return _SummaryBody(
        key: ObjectKey(database.requireValue),
        notebookId: notebookId,
        repository: repository.requireValue!,
      );
    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: studyAsync(
        database,
        (db) => db == null
            ? const Center(child: Text('Sign in again to open your summary.'))
            : studyAsync(
                repository,
                (_) => const SizedBox.shrink(),
                retry: () => ref.invalidate(studySummaryRepositoryProvider),
              ),
        retry: () => ref.invalidate(accountDatabaseProvider),
      ),
    );
  }
}

class _SummaryBody extends ConsumerStatefulWidget {
  const _SummaryBody({
    super.key,
    required this.notebookId,
    required this.repository,
  });
  final String notebookId;
  final StudySummaryRepository repository;
  @override
  ConsumerState<_SummaryBody> createState() => _SummaryBodyState();
}

class _SummaryBodyState extends ConsumerState<_SummaryBody> {
  late final StudySummarySession _session;
  bool _authorizing = false, _allowPop = false;
  @override
  void initState() {
    super.initState();
    _session = StudySummarySession(
      notebookId: widget.notebookId,
      repository: widget.repository,
      client: ref.read(studentAiClientProvider),
      isCurrent: () =>
          mounted &&
          ref.read(accountDatabaseProvider).asData?.value ==
              widget.repository.db,
      isOnline: () => ref.read(connectivityProvider).asData?.value == true,
    )..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    super.dispose();
  }

  Future<void> _generate(bool replacing) async {
    if (_authorizing || _session.working) return;
    setState(() => _authorizing = true);
    try {
      if (replacing &&
          !await showFiloConfirmation(
            context,
            title: 'Replace this summary?',
            message: 'Your saved summary will be replaced after a new summary is generated and saved.',
            confirmLabel: 'Summarize again',
            cancelLabel: 'Cancel',
          ))
        return;
      if (!mounted) return;
      if (await ensureStudyPrivacy(context, ref) && mounted)
        await _session.generate();
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }

  Future<void> _copy(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) showMessage(context, 'Summary copied.');
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not copy this summary. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(studySummaryProvider(widget.notebookId));
    final sources = ref.watch(studySourcesProvider(widget.notebookId));
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final guard = ref.watch(aiRequestGuardProvider);
    ref.watch(aiRequestBusyProvider);
    final pending = _session.pending;
    final reason = !online
        ? studyAiMessages['OFFLINE']
        : guard.isBusy && !_session.working
        ? studyAiMessages['AI_IN_PROGRESS']
        : sources.isLoading
        ? 'Loading sources...'
        : sources.hasError
        ? 'Could not read notebook sources. Try again.'
        : sources.asData?.value.isEmpty != false
        ? 'Add a readable source to generate a summary.'
        : sources.requireValue.any((s) => s.extractedText.trim().isEmpty)
        ? studyAiMessages['NO_TEXT']
        : null;
    return PopScope(
      canPop: _allowPop || (pending == null && !_session.saving),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _session.saving) return;
        final leave = await showFiloConfirmation(
          context,
          title: 'Leave without saving this summary?',
          message:
              'This summary has not been confirmed saved. Leaving may lose it.',
          confirmLabel: 'Leave',
          cancelLabel: 'Keep open',
        );
        if (leave && mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Summary')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const StudyOfflineBanner(),
            studyAsync(
              summary,
              (saved) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (saved != null) ...[
                    Text(
                      'Saved ${MaterialLocalizations.of(context).formatMediumDate(saved.updatedAt.toLocal())}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    FiloPanel(child: StudyAnswerText(saved.content)),
                    _usage(StudySummaryUsage.decode(saved.usageJson)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _copy(saved.content),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy summary'),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(
                        title: 'Generate a short summary of your sources.',
                        pose: _session.error == null ? 'reading' : 'confused',
                        bob: !_session.working && _session.error == null,
                      ),
                    ),
                  if (pending != null) ...[
                    const SizedBox(height: 16),
                    const Text('New summary — not confirmed saved'),
                    FiloPanel(child: StudyAnswerText(pending.value.answer)),
                    _usage(StudySummaryUsage.fromResult(pending)),
                    TextButton.icon(
                      onPressed: () => _copy(pending.value.answer),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy unsaved summary'),
                    ),
                    FiloButton(
                      label: 'Try saving again',
                      onPressed: _session.working ? null : _session.retrySave,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('AI can make mistakes. Check important answers.'),
                  const SizedBox(height: 16),
                  if (_session.working) ...[
                    if (!_session.saving)
                      const Mascot(pose: 'thinking', size: 120),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _session.saving
                            ? 'Saving summary...'
                            : 'Preparing your summary...',
                      ),
                    ),
                    if (!MediaQuery.disableAnimationsOf(context))
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: FiloCircularProgressIndicator(
                            semanticsLabel: 'Preparing summary',
                          ),
                        ),
                      ),
                    if (!_session.saving) ...[
                      FiloButton(label: 'Cancel', onPressed: _session.cancel),
                      const SizedBox(height: 8),
                      const Text(
                        'Cancel stops waiting on this phone. The server may still finish.',
                      ),
                    ],
                  ] else if (pending == null)
                    FiloButton(
                      label: saved == null
                          ? 'Summarize sources'
                          : 'Summarize again',
                      icon: FiloIcons.sparkle,
                      onPressed: reason != null || _authorizing
                          ? null
                          : () => _generate(saved != null),
                    ),
                ],
              ),
              retry: () =>
                  ref.invalidate(studySummaryProvider(widget.notebookId)),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(reason),
              ),
            if (sources.hasError)
              TextButton(
                onPressed: () =>
                    ref.invalidate(studySourcesProvider(widget.notebookId)),
                child: const Text('Retry loading sources'),
              ),
            if (_session.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_session.error!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _usage(StudySummaryUsage? usage) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (usage == null)
          const Text('Usage details unavailable')
        else ...[
          Text('${usage.retainedCharacters} source characters used.'),
          for (final source in usage.sources)
            if (source.truncated)
              Text(
                'Only the first ${source.retainedCharacters} characters of ${source.name} were used.',
              ),
          if (usage.serverTruncated && !usage.sources.any((s) => s.truncated))
            const Text(
              'Some source text was cut before the summary was generated.',
            ),
        ],
      ],
    ),
  );
}
