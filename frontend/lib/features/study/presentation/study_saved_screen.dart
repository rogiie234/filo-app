import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../application/study_providers.dart';
import 'study_widgets.dart';

enum StudyTool {
  chat('Chat'),
  summary('Summary'),
  decks('Flashcards'),
  quizzes('Practice quiz');

  const StudyTool(this.label);
  final String label;
}

String savedCount(WidgetRef ref, StudyTool tool, String id) {
  final AsyncValue<Object?> value = switch (tool) {
    StudyTool.chat => ref.watch(studyChatsProvider(id)),
    StudyTool.summary => ref.watch(studySummaryProvider(id)),
    StudyTool.decks => ref.watch(studyDecksProvider(id)),
    StudyTool.quizzes => ref.watch(studyQuizzesProvider(id)),
  };
  if (value.isLoading) return 'Loading saved content...';
  if (value.hasError) return 'Saved count unavailable';
  if (tool == StudyTool.summary)
    return value.value == null ? 'No summary saved' : '1 summary saved';
  return studyCount((value.value as List).length, switch (tool) {
    StudyTool.chat => 'chat',
    StudyTool.decks => 'deck',
    _ => 'quiz',
  });
}

class StudySavedScreen extends ConsumerWidget {
  const StudySavedScreen({
    super.key,
    required this.notebookId,
    required this.tool,
    this.childId,
    this.title,
  });
  final String notebookId;
  final StudyTool tool;
  final String? childId, title;
  // Saved practice-question details also contain attempt results.
  bool get _showMascot => tool != StudyTool.quizzes || childId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(studyNotebooksProvider);
    final available =
        !notebooks.isLoading &&
        !notebooks.hasError &&
        notebooks.hasValue &&
        notebooks.requireValue.any((n) => n.id == notebookId);
    return Scaffold(
      appBar: AppBar(title: Text(available ? title ?? tool.label : tool.label)),
      body: SafeArea(
        child: studyAsync(
          notebooks,
          (items) {
            if (!items.any((n) => n.id == notebookId)) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  showMascot: _showMascot,
                  title: 'This notebook is no longer available.',
                  pose: 'confused',
                  bob: false,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const StudyOfflineBanner(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Saved content · read only'),
                ),
                _content(context, ref),
                const SizedBox(height: 24),
                const Text('AI can make mistakes. Check important answers.'),
              ],
            );
          },
          showMascot: _showMascot,
          retry: () => ref.invalidate(studyNotebooksProvider),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final id = childId;
    if (tool == StudyTool.summary)
      return studyAsync(
        ref.watch(studySummaryProvider(notebookId)),
        (summary) => summary == null
            ? const EmptyState(title: 'No summary saved yet.', pose: 'reading')
            : SelectableText(summary.content),
        showMascot: _showMascot,
        retry: () => ref.invalidate(studySummaryProvider(notebookId)),
      );
    if (id != null)
      return switch (tool) {
        StudyTool.chat => studyAsync(
          ref.watch(studyMessagesProvider(id)),
          (messages) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (messages.isEmpty)
                const EmptyState(
                  title: 'No messages saved yet.',
                  pose: 'reading',
                ),
              for (final message in messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${message.role == 'user' ? 'You' : 'AI'} · ${message.mode == 'general' ? 'General knowledge' : 'Answers use your files'}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(message.content),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          showMascot: _showMascot,
          retry: () => ref.invalidate(studyMessagesProvider(id)),
        ),
        StudyTool.decks => studyAsync(
          ref.watch(studyCardsProvider(id)),
          (cards) => Column(
            children: [
              if (cards.isEmpty)
                const EmptyState(title: 'No cards saved yet.', pose: 'reading'),
              for (final card in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          card.front,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(),
                        SelectableText(card.back),
                        const SizedBox(height: 8),
                        Text('Status: ${card.status}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          showMascot: _showMascot,
          retry: () => ref.invalidate(studyCardsProvider(id)),
        ),
        StudyTool.quizzes => studyAsync(
          ref.watch(studyQuestionsProvider(id)),
          (questions) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (questions.isEmpty)
                const EmptyState(
                  title: 'No questions saved yet.',
                  showMascot: false,
                ),
              for (final question in questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FiloPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          question.prompt,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (question.options != null)
                          SelectableText(
                            (jsonDecode(question.options!) as List).join('\n'),
                          ),
                        const Divider(),
                        SelectableText(
                          'Answer: ${question.correctBoolean ?? (question.correctIndex != null ? (jsonDecode(question.options!) as List)[question.correctIndex!] : (jsonDecode(question.acceptedAnswers!) as List).join(' / '))}',
                        ),
                        SelectableText(question.explanation),
                      ],
                    ),
                  ),
                ),
              Text(
                'Saved attempts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              studyAsync(
                ref.watch(studyAttemptsProvider(id)),
                (attempts) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (attempts.isEmpty) const Text('No attempts saved yet.'),
                    for (final attempt in attempts)
                      ListTile(
                        title: Text('${attempt.score} / ${attempt.total}'),
                        subtitle: Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(attempt.attemptedAt.toLocal()),
                        ),
                      ),
                  ],
                ),
                retry: () => ref.invalidate(studyAttemptsProvider(id)),
              ),
            ],
          ),
          showMascot: _showMascot,
          retry: () => ref.invalidate(studyQuestionsProvider(id)),
        ),
        _ => const SizedBox.shrink(),
      };
    void open(String id, String title) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudySavedScreen(
          notebookId: notebookId,
          tool: tool,
          childId: id,
          title: title,
        ),
      ),
    );
    return switch (tool) {
      StudyTool.chat => studyAsync(
        ref.watch(studyChatsProvider(notebookId)),
        (items) => Column(
          children: [
            if (items.isEmpty)
              const EmptyState(title: 'No chats yet.', pose: 'reading'),
            for (final item in items)
              ListTile(
                title: Text(item.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(item.id, item.title),
              ),
          ],
        ),
        showMascot: _showMascot,
        retry: () => ref.invalidate(studyChatsProvider(notebookId)),
      ),
      StudyTool.decks => studyAsync(
        ref.watch(studyDecksProvider(notebookId)),
        (items) => Column(
          children: [
            if (items.isEmpty)
              const EmptyState(title: 'No decks saved yet.', pose: 'reading'),
            for (final item in items)
              ListTile(
                title: Text(item.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(item.id, item.title),
              ),
          ],
        ),
        showMascot: _showMascot,
        retry: () => ref.invalidate(studyDecksProvider(notebookId)),
      ),
      StudyTool.quizzes => studyAsync(
        ref.watch(studyQuizzesProvider(notebookId)),
        (items) => Column(
          children: [
            if (items.isEmpty)
              const EmptyState(
                title: 'No practice quizzes saved yet.',
                pose: 'reading',
              ),
            for (final item in items)
              ListTile(
                title: Text(item.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(item.id, item.title),
              ),
          ],
        ),
        showMascot: _showMascot,
        retry: () => ref.invalidate(studyQuizzesProvider(notebookId)),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
