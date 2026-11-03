import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database_providers.dart';
import '../application/study_flashcard_sessions.dart';
import '../application/study_providers.dart';
import '../data/study_repositories.dart';
import 'study_deck_scope.dart';
import 'study_flashcard.dart';
import 'study_widgets.dart';

class StudyFlashcardStudyScreen extends StatelessWidget {
  const StudyFlashcardStudyScreen({
    super.key,
    required this.notebookId,
    required this.deckId,
  });
  final String notebookId, deckId;
  @override
  Widget build(BuildContext context) => StudyDeckScope(
    notebookId: notebookId,
    builder: (repo) => _StudyBody(
      key: ValueKey((repo.db, notebookId, deckId)),
      notebookId: notebookId,
      deckId: deckId,
      repository: repo,
    ),
  );
}

class _StudyBody extends ConsumerStatefulWidget {
  const _StudyBody({
    super.key,
    required this.notebookId,
    required this.deckId,
    required this.repository,
  });
  final String notebookId, deckId;
  final StudyDeckRepository repository;
  @override
  ConsumerState<_StudyBody> createState() => _StudyBodyState();
}

class _StudyBodyState extends ConsumerState<_StudyBody> {
  late final StudyFlashcardSession _session;
  final _scroll = ScrollController();
  int _revision = -1;
  bool _confirming = false;
  @override
  void initState() {
    super.initState();
    _session = StudyFlashcardSession(
      notebookId: widget.notebookId,
      deckId: widget.deckId,
      repository: widget.repository,
      isCurrent: () =>
          mounted &&
          ref.read(accountDatabaseProvider).asData?.value ==
              widget.repository.db,
    )..addListener(_changed);
    _session.open();
  }

  void _changed() {
    if (!mounted) return;
    final nextCard = _revision != _session.revision;
    _revision = _session.revision;
    setState(() {});
    if (nextCard)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirming || _session.working) return;
    setState(() => _confirming = true);
    try {
      final confirmed = await showFiloConfirmation(
        context,
        title: 'Delete this card?',
        message: 'This card will be deleted from this deck.',
        confirmLabel: 'Delete card',
        cancelLabel: 'Cancel',
        icon: FiloIcons.delete,
      );
      if (confirmed && mounted) await _session.deleteCurrent();
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(studyDecksProvider(widget.notebookId));
    final matches = decks.asData?.value
        .where((d) => d.id == widget.deckId)
        .toList();
    final card = _session.card;
    final enabled = !_session.working && !_session.loading && !_confirming;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          matches?.isNotEmpty == true ? matches!.first.title : 'Flashcards',
        ),
        actions: [
          IconButton(
            tooltip: 'Shuffle remaining cards',
            onPressed: enabled && card != null ? _session.shuffle : null,
            icon: const Icon(Icons.shuffle),
          ),
          IconButton(
            tooltip: 'Delete card',
            onPressed: enabled && card != null ? _delete : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: studyAsync(
          decks,
          (_) => matches!.isEmpty
              ? const Center(child: Text('This deck is no longer available.'))
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(24),
                  children: [
                    const StudyOfflineBanner(),
                    if (_session.loading)
                      const Center(
                        child: FiloCircularProgressIndicator(
                          semanticsLabel: 'Opening deck',
                        ),
                      )
                    else if (card != null) ...[
                      Semantics(
                        label: 'Study progress',
                        value:
                            '${_session.completed} of ${_session.total} cards reviewed',
                        child: FiloLinearProgressIndicator(
                          value: _session.progress,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Card ${_session.completed + 1} of ${_session.total}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: StudyFlashcard(
                            key: ValueKey(_session.revision),
                            front: card.front,
                            back: card.back,
                            number: _session.completed + 1,
                            total: _session.total,
                            enabled: enabled,
                            onMark: (status) => _session.mark(status),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Swipe left for Still learning or right for Got it. You can also use the buttons.',
                      ),
                      const SizedBox(height: 16),
                      FiloButton(
                        label: 'Still learning',
                        secondary: true,
                        leading: Icon(
                          Icons.school_outlined,
                          color: FiloThemeTokens.of(context).warning,
                        ),
                        onPressed: enabled
                            ? () => _session.mark('learning')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      FiloButton(
                        label: 'Got it',
                        icon: Icons.check,
                        onPressed: enabled
                            ? () => _session.mark('known')
                            : null,
                      ),
                    ] else if (_session.cards.isEmpty &&
                        _session.error == null) ...[
                      const Text('This deck has no cards.'),
                      const Text(
                        'Go back to your notebook to generate another deck.',
                      ),
                    ] else if (_session.error == null) ...[
                      const Text('Deck complete'),
                      Text('${_session.known} known'),
                      Text('${_session.learning} still learning'),
                      const SizedBox(height: 16),
                      if (_session.learning > 0)
                        FiloButton(
                          label: 'Study missed cards again',
                          onPressed: _session.repeatMissed,
                        ),
                      const SizedBox(height: 12),
                      FiloButton(
                        label: 'Back to decks',
                        secondary: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                    if (_session.working)
                      Semantics(
                        liveRegion: true,
                        child: const Text('Saving card...'),
                      ),
                    if (_session.error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(liveRegion: true, child: Text(_session.error!)),
                      TextButton(
                        onPressed: !enabled
                            ? null
                            : _session.retryStatus != null
                            ? () => _session.mark(_session.retryStatus!)
                            : () => _session.open(),
                        child: const Text('Try again'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'AI can make mistakes. Check important answers.',
                    ),
                  ],
                ),
          retry: () => ref.invalidate(studyDecksProvider(widget.notebookId)),
        ),
      ),
    );
  }
}
