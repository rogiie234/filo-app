import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/database_providers.dart';
import '../application/student_ai_providers.dart';
import '../application/study_flashcard_sessions.dart';
import '../application/study_providers.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import '../domain/study_inputs.dart';
import 'study_deck_scope.dart';
import 'study_flashcard_study_screen.dart';
import 'study_privacy.dart';
import 'study_widgets.dart';

class StudyDecksScreen extends StatelessWidget {
  const StudyDecksScreen({super.key, required this.notebookId});
  final String notebookId;
  @override
  Widget build(BuildContext context) => StudyDeckScope(
    notebookId: notebookId,
    builder: (repo) => Consumer(
      builder: (context, ref, _) => Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const StudyOfflineBanner(),
              studyAsync(
                ref.watch(studyDecksProvider(notebookId)),
                (decks) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FiloButton(
                      label: 'Generate flashcards',
                      icon: FiloIcons.sparkle,
                      onPressed: decks.length >= 10
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StudyDeckGenerateScreen(
                                  notebookId: notebookId,
                                ),
                              ),
                            ),
                    ),
                    if (decks.length >= 10)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(studyDeckLimitMessage),
                      ),
                    const SizedBox(height: 24),
                    if (decks.isEmpty)
                      const EmptyState(
                        title: 'Generate flashcards to review the main ideas.',
                        pose: 'reading',
                      ),
                    for (final deck in decks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FiloPanel(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(deck.title),
                            subtitle: studyAsync(
                              ref.watch(studyCardsProvider(deck.id)),
                              (cards) => Text(
                                '${studyCount(cards.length, 'card')} · ${cards.where((c) => c.status == 'known').length} known',
                              ),
                              retry: () =>
                                  ref.invalidate(studyCardsProvider(deck.id)),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => StudyFlashcardStudyScreen(
                                  notebookId: notebookId,
                                  deckId: deck.id,
                                ),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Deck options for ${deck.title}',
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename deck'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete deck'),
                                ),
                              ],
                              onSelected: (action) async {
                                try {
                                  if (action == 'rename') {
                                    final title = await showStudyDeckName(
                                      context,
                                      deck.title,
                                    );
                                    if (title == null ||
                                        !context.mounted ||
                                        ref
                                                .read(accountDatabaseProvider)
                                                .asData
                                                ?.value !=
                                            repo.db)
                                      return;
                                    if (await repo.rename(deck.id, title) != 1)
                                      throw StateError('Deck unavailable');
                                  } else {
                                    final confirmed =
                                        await showFiloConfirmation(
                                          context,
                                          title: 'Delete this deck?',
                                          message: 'This deck and its cards will be deleted from this device.',
                                          confirmLabel: 'Delete deck',
                                          cancelLabel: 'Cancel',
                                          icon: FiloIcons.delete,
                                        );
                                    if (confirmed &&
                                        context.mounted &&
                                        ref
                                                .read(accountDatabaseProvider)
                                                .asData
                                                ?.value ==
                                            repo.db)
                                      await repo.delete(deck.id);
                                  }
                                } catch (_) {
                                  if (context.mounted)
                                    showMessage(
                                      context,
                                      action == 'rename'
                                          ? 'Could not rename this deck. Try again.'
                                          : 'Could not delete this deck. Try again.',
                                    );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                retry: () => ref.invalidate(studyDecksProvider(notebookId)),
                showMascot: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String?> showStudyDeckName(BuildContext context, String initial) =>
    showFiloDialog<String>(
      context: context,
      builder: (_) => _DeckName(initial: initial),
    );

class _DeckName extends StatefulWidget {
  const _DeckName({required this.initial});
  final String initial;
  @override
  State<_DeckName> createState() => _DeckNameState();
}

class _DeckNameState extends State<_DeckName> {
  late final _name = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename deck'),
    scrollable: true,
    content: TextField(
      controller: _name,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Deck title'),
      inputFormatters: [
        TextInputFormatter.withFunction(
          (old, next) => next.text.runes.length <= 255 ? next : old,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ValueListenableBuilder(
        valueListenable: _name,
        builder: (_, value, __) => TextButton(
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, value.text.trim()),
          child: const Text('Save'),
        ),
      ),
    ],
  );
}

class StudyDeckGenerateScreen extends StatelessWidget {
  const StudyDeckGenerateScreen({super.key, required this.notebookId});
  final String notebookId;
  @override
  Widget build(BuildContext context) => StudyDeckScope(
    notebookId: notebookId,
    builder: (repo) => _DeckGenerateBody(
      key: ObjectKey(repo.db),
      notebookId: notebookId,
      repository: repo,
    ),
  );
}

class _DeckGenerateBody extends ConsumerStatefulWidget {
  const _DeckGenerateBody({
    super.key,
    required this.notebookId,
    required this.repository,
  });
  final String notebookId;
  final StudyDeckRepository repository;
  @override
  ConsumerState<_DeckGenerateBody> createState() => _DeckGenerateBodyState();
}

class _DeckGenerateBodyState extends ConsumerState<_DeckGenerateBody> {
  late final StudyDeckGeneration _session;
  final _topic = TextEditingController();
  int _count = 10;
  bool _authorizing = false, _allowPop = false;
  @override
  void initState() {
    super.initState();
    _session = StudyDeckGeneration(
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
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_session.working || _authorizing) return;
    setState(() => _authorizing = true);
    try {
      if (await ensureStudyPrivacy(context, ref) && mounted)
        await _session.generate(
          StudyDeckSettings(count: _count, topicFocus: _topic.text.trim()),
        );
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(studySourcesProvider(widget.notebookId));
    final decks = ref.watch(studyDecksProvider(widget.notebookId));
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final guard = ref.watch(aiRequestGuardProvider);
    ref.watch(aiRequestBusyProvider);
    final result = _session.result;
    final reason = !online
        ? studyAiMessages['OFFLINE']
        : guard.isBusy && !_session.working
        ? studyAiMessages['AI_IN_PROGRESS']
        : sources.isLoading || decks.isLoading
        ? 'Loading notebook...'
        : sources.hasError || decks.hasError
        ? studyAiMessages['LOAD_FAILED']
        : decks.requireValue.length >= 10
        ? studyDeckLimitMessage
        : sources.requireValue.isEmpty && _topic.text.trim().isEmpty
        ? 'Enter a topic when your notebook has no sources.'
        : sources.requireValue.any((s) => s.extractedText.trim().isEmpty)
        ? studyAiMessages['NO_TEXT']
        : null;
    return PopScope(
      canPop: _allowPop || (!_session.hasUnsaved && !_session.saving),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _session.saving) return;
        if (await showFiloConfirmation(
              context,
              title: 'Leave without saving this deck?',
              message: 'These cards have not been confirmed saved. Leaving may lose them.',
              confirmLabel: 'Leave',
              cancelLabel: 'Keep open',
            ) &&
            mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Generate flashcards')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const StudyOfflineBanner(),
              if (result == null) ...[
                const Text('How many cards?'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _count,
                  decoration: const InputDecoration(
                    labelText: 'Number of cards',
                  ),
                  items: [
                    for (var i = 5; i <= 30; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: _session.working || _authorizing
                      ? null
                      : (value) => setState(() => _count = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _topic,
                  enabled: !_session.working && !_authorizing,
                  decoration: const InputDecoration(
                    labelText: 'Topic (optional with sources)',
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (old, next) => next.text.runes.length <= 200 ? next : old,
                    ),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                Text('${_topic.text.runes.length}/200 characters'),
                const SizedBox(height: 24),
              ],
              if (_session.working) ...[
                if (!_session.saving) const Mascot(pose: 'thinking', size: 120),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _session.saving
                        ? 'Saving deck...'
                        : 'Preparing your flashcards...',
                  ),
                ),
                if (!MediaQuery.disableAnimationsOf(context))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: FiloCircularProgressIndicator(
                        semanticsLabel: 'Preparing flashcards',
                      ),
                    ),
                  ),
                if (!_session.saving)
                  FiloButton(label: 'Cancel', onPressed: _session.cancel),
                const Text(
                  'Cancel stops waiting on this phone. The server may still finish.',
                ),
              ] else if (result == null)
                FiloButton(
                  label: 'Generate',
                  icon: FiloIcons.sparkle,
                  onPressed: reason == null && !_authorizing ? _generate : null,
                ),
              if (reason != null && result == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(reason),
                ),
              if (sources.hasError || decks.hasError)
                TextButton(
                  onPressed: () {
                    ref.invalidate(studySourcesProvider(widget.notebookId));
                    ref.invalidate(studyDecksProvider(widget.notebookId));
                  },
                  child: const Text('Retry loading notebook'),
                ),
              if (result != null) ...[
                const SizedBox(height: 16),
                Text(
                  _session.savedId == null
                      ? 'Deck not confirmed saved'
                      : 'Deck saved.',
                ),
                Text(
                  '${studyCount(result.value.items.length, 'card')} prepared.',
                ),
                if (result.value.dropped > 0)
                  Text(
                    '${result.value.dropped} invalid ${result.value.dropped == 1 ? 'card was' : 'cards were'} dropped.',
                  ),
                if (result.value.missing > 0)
                  Text(
                    '${result.value.missing} requested ${result.value.missing == 1 ? 'card was' : 'cards were'} not returned.',
                  ),
                for (final usage in result.sources.usage)
                  if (usage.truncated)
                    Text(
                      'Only the first ${usage.retainedCharacters} characters of ${usage.name} were used.',
                    ),
                const SizedBox(height: 16),
                if (_session.hasUnsaved && !_session.working)
                  FiloButton(
                    label: 'Try saving again',
                    onPressed: _session.retrySave,
                  ),
                if (_session.savedId != null)
                  FiloButton(
                    label: 'Study deck',
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => StudyFlashcardStudyScreen(
                          notebookId: widget.notebookId,
                          deckId: _session.savedId!,
                        ),
                      ),
                    ),
                  ),
              ],
              if (_session.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_session.error!),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('AI can make mistakes. Check important answers.'),
            ],
          ),
        ),
      ),
    );
  }
}
