import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
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
  void _generate(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => StudyDeckGenerateScreen(notebookId: notebookId),
    ),
  );
  @override
  Widget build(BuildContext context) => StudyDeckScope(
    notebookId: notebookId,
    builder: (repo) => Consumer(
      builder: (context, ref, _) {
        final decks = ref.watch(studyDecksProvider(notebookId));
        final showAdd =
            decks.hasValue &&
            !decks.isLoading &&
            !decks.hasError &&
            decks.requireValue.isNotEmpty;
        return EntryBackground(
          variation: 4,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: showAdd
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 72,
                      child: FiloButton(
                        label: 'Generate flashcards',
                        icon: FiloIcons.add,
                        iconOnly: true,
                        minHeight: 72,
                        onPressed: decks.requireValue.length >= 10
                            ? null
                            : () => _generate(context),
                      ),
                    ),
                  )
                : null,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Flashcards'),
            ),
            body: SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  FiloSpacing.screen,
                  FiloSpacing.screen,
                  FiloSpacing.screen,
                  showAdd ? 120 : FiloSpacing.screen,
                ),
                children: [
                  const StudyOfflineBanner(),
                  studyAsync(
                    decks,
                    (decks) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StudyCollectionHeader(
                          title: 'One idea at a time.',
                          body: 'Flip a card, recall the answer, then choose what needs another look.',
                          icon: FiloIcons.slides,
                          summary:
                              '${studyCount(decks.length, 'deck')} saved on this device',
                        ),
                        if (decks.length >= 10)
                          const Padding(
                            padding: EdgeInsets.only(top: FiloSpacing.s12),
                            child: Text(studyDeckLimitMessage),
                          ),
                        if (decks.length >= 10)
                          const SizedBox(height: FiloSpacing.screen),
                        if (decks.isEmpty)
                          EmptyState(
                            primaryAction: EmptyStateAction(
                              label: 'Generate flashcards',
                              onPressed: () => _generate(context),
                            ),
                            title: 'No flashcards yet',
                            body: 'Generate a deck from your sources or a topic to review the main ideas.',
                            pose: 'reading',
                          ),
                        for (final deck in decks)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: FiloSpacing.s12,
                            ),
                            child: FiloPanel(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: FiloSpacing.s16,
                                  vertical: FiloSpacing.s8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(
                                    FiloSpacing.s12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      FiloRadii.medium,
                                    ),
                                  ),
                                  child: FiloIcon(
                                    FiloIcons.slides,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                title: Text(
                                  deck.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                subtitle: studyAsync(
                                  ref.watch(studyCardsProvider(deck.id)),
                                  (cards) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${studyCount(cards.length, 'card')} · ${cards.where((c) => c.status == 'known').length} known',
                                      ),
                                      if (cards.isNotEmpty) ...[
                                        const SizedBox(height: FiloSpacing.s12),
                                        FiloLinearProgressIndicator(
                                          value:
                                              cards
                                                  .where(
                                                    (c) => c.status == 'known',
                                                  )
                                                  .length /
                                              cards.length,
                                          semanticsLabel: 'Cards marked known',
                                        ),
                                      ],
                                      const SizedBox(height: FiloSpacing.s12),
                                      Text(
                                        'Review deck',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  retry: () => ref.invalidate(
                                    studyCardsProvider(deck.id),
                                  ),
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
                                                    .read(
                                                      accountDatabaseProvider,
                                                    )
                                                    .asData
                                                    ?.value !=
                                                repo.db) {
                                          return;
                                        }
                                        if (await repo.rename(deck.id, title) !=
                                            1) {
                                          throw StateError('Deck unavailable');
                                        }
                                      } else {
                                        final confirmed =
                                            await showFiloConfirmation(
                                              context,
                                              title: 'Delete this deck?',
                                              message: 'This deck and its cards will be deleted from this device.',
                                              confirmLabel: 'Delete deck',
                                              cancelLabel: 'Cancel',
                                              confirmDestructive: true,
                                              icon: FiloIcons.delete,
                                            );
                                        if (confirmed &&
                                            context.mounted &&
                                            ref
                                                    .read(
                                                      accountDatabaseProvider,
                                                    )
                                                    .asData
                                                    ?.value ==
                                                repo.db) {
                                          await repo.delete(deck.id);
                                        }
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        showMessage(
                                          context,
                                          action == 'rename'
                                              ? 'Could not rename this deck. Try again.'
                                              : 'Could not delete this deck. Try again.',
                                        );
                                      }
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
        );
      },
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
  Widget build(BuildContext context) => FiloModalDialog(
    title: 'Rename deck',
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
      ValueListenableBuilder(
        valueListenable: _name,
        builder: (_, value, _) => FiloButton(
          onPressed: value.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, value.text.trim()),
          label: 'Save',
        ),
      ),
      FiloButton(
        secondary: true,
        onPressed: () => Navigator.pop(context),
        label: 'Cancel',
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
  final _errorToast = StudyErrorToast();
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
    if (!mounted) return;
    _errorToast.update(
      context,
      _session.error,
      isCurrent: () =>
          ref.read(accountDatabaseProvider).asData?.value ==
          widget.repository.db,
    );
    setState(() {});
    if (_session.savedId == null || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          ref.read(accountDatabaseProvider).asData?.value !=
              widget.repository.db) {
        return;
      }
      final result = _session.result!;
      final message = [
        'Flashcards created.',
        if (result.value.dropped > 0)
          '${result.value.dropped} invalid ${result.value.dropped == 1 ? 'card was' : 'cards were'} dropped.',
        if (result.value.missing > 0)
          '${result.value.missing} requested ${result.value.missing == 1 ? 'card was' : 'cards were'} not returned.',
        if (result.truncated) 'Some source text was shortened.',
      ].join('\n');
      showFiloToast(context, message, kind: FiloToastKind.success);
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => StudyDecksScreen(notebookId: widget.notebookId),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_session.working && ref.read(aiRequestGuardProvider).isBusy) {
      showFiloToast(
        context,
        studyAiMessages['AI_IN_PROGRESS']!,
        kind: FiloToastKind.error,
      );
      return;
    }
    if (_session.working || _authorizing) return;
    setState(() => _authorizing = true);
    try {
      if (await ensureStudyPrivacy(context, ref) && mounted) {
        await _session.generate(
          StudyDeckSettings(count: _count, topicFocus: _topic.text.trim()),
        );
      }
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
      child: EntryBackground(
        variation: 4,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Generate flashcards'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(FiloSpacing.screen),
              children: [
                const StudyOfflineBanner(),
                if (result == null) ...[
                  FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'How many cards?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: FiloSpacing.s16),
                        DropdownButtonFormField<int>(
                          initialValue: _count,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Number of cards',
                            prefixIcon: FiloIcon(FiloIcons.slides),
                          ),
                          items: [
                            for (var i = 5; i <= 30; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('$i cards'),
                              ),
                          ],
                          onChanged: _session.working || _authorizing
                              ? null
                              : (value) => setState(() => _count = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.s16),
                  FiloPanel(
                    child: TextField(
                      controller: _topic,
                      enabled: !_session.working && !_authorizing,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Topic (optional with sources)',
                        alignLabelWithHint: true,
                        counterText:
                            '${_topic.text.runes.length}/200 characters',
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (old, next) =>
                              next.text.runes.length <= 200 ? next : old,
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
                const SizedBox(height: FiloSpacing.s16),
                if (_session.working) ...[
                  StudyGenerationStatus(
                    label: _session.saving
                        ? 'Saving deck...'
                        : 'Preparing your flashcards...',
                    saving: _session.saving,
                    onCancel: _session.cancel,
                  ),
                ] else if (result == null)
                  FiloButton(
                    label: 'Generate',
                    icon: FiloIcons.sparkle,
                    onPressed:
                        !_authorizing &&
                            (reason == null ||
                                reason == studyAiMessages['AI_IN_PROGRESS'])
                        ? _generate
                        : null,
                  ),
                if (reason != null &&
                    reason != studyAiMessages['AI_IN_PROGRESS'] &&
                    reason != studyAiMessages['OFFLINE'] &&
                    result == null)
                  Padding(
                    padding: const EdgeInsets.only(top: FiloSpacing.s12),
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
                  const SizedBox(height: FiloSpacing.s16),
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
                  const SizedBox(height: FiloSpacing.s16),
                  if (_session.hasUnsaved && !_session.working)
                    FiloButton(
                      label: 'Try saving again',
                      onPressed: _session.retrySave,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
