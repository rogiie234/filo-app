import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_request_providers.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/database_providers.dart';
import '../application/student_ai_providers.dart';
import '../application/study_chat_session.dart';
import '../application/study_providers.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import 'study_chat_history.dart';
import 'study_chat_message.dart';
import 'study_privacy.dart';
import 'study_source_picker.dart';
import 'study_widgets.dart';

class StudyChatScreen extends ConsumerWidget {
  const StudyChatScreen({super.key, required this.notebookId, this.chatId});
  final String notebookId;
  final String? chatId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(accountDatabaseProvider);
    final repo = ref.watch(studyChatRepositoryProvider);
    if (db.isLoading ||
        db.hasError ||
        db.asData?.value == null ||
        repo.isLoading ||
        repo.hasError ||
        repo.asData?.value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: studyAsync(
          db,
          (value) => value == null
              ? const Center(child: Text('Sign in again to open your chats.'))
              : studyAsync(
                  repo,
                  (_) => const SizedBox.shrink(),
                  retry: () => ref.invalidate(studyChatRepositoryProvider),
                ),
          retry: () => ref.invalidate(accountDatabaseProvider),
        ),
      );
    }
    return _ChatBody(
      key: ObjectKey(db.requireValue),
      notebookId: notebookId,
      chatId: chatId,
      repository: repo.requireValue!,
    );
  }
}

class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({
    super.key,
    required this.notebookId,
    required this.repository,
    this.chatId,
  });
  final String notebookId;
  final String? chatId;
  final StudyChatRepository repository;
  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final StudyChatSession _session;
  bool _authorizing = false, _allowPop = false;
  int _lastCount = 0;
  bool _hadPending = false;
  @override
  void initState() {
    super.initState();
    _session = StudyChatSession(
      notebookId: widget.notebookId,
      repository: widget.repository,
      client: ref.read(studentAiClientProvider),
      isCurrent: () =>
          mounted &&
          ref.read(accountDatabaseProvider).asData?.value ==
              widget.repository.db,
      isOnline: () => ref.read(connectivityProvider).asData?.value == true,
    );
    _session.addListener(_changed);
    _session.open(id: widget.chatId, latest: widget.chatId == null);
  }

  void _changed() {
    if (!mounted) return;
    final nearEnd = !_scroll.hasClients || _scroll.position.extentAfter < 100;
    final added =
        _session.messages.length != _lastCount ||
        (_session.pendingAnswer != null) != _hadPending;
    final ownMessage =
        _session.messages.isNotEmpty && _session.messages.last.role == 'user';
    _lastCount = _session.messages.length;
    _hadPending = _session.pendingAnswer != null;
    if (_input.text != _session.draft)
      _input.value = TextEditingValue(
        text: _session.draft,
        selection: TextSelection.collapsed(offset: _session.draft.length),
      );
    setState(() {});
    if (added && (nearEnd || ownMessage))
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients)
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    _session.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _canLeave() async =>
      _session.pendingAnswer == null ||
      await showFiloConfirmation(
        context,
        title: 'Leave without saving this answer?',
        message:
            'This answer has not been confirmed saved. Leaving may lose it.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep open',
      );

  Future<void> _send() async {
    if (_authorizing || _session.working) return;
    setState(() => _authorizing = true);
    try {
      if (await ensureStudyPrivacy(context, ref) && mounted)
        await _session.send();
    } finally {
      if (mounted) setState(() => _authorizing = false);
    }
  }

  Future<void> _menu(String action) async {
    if (_session.working || _authorizing) return;
    if (action == 'privacy') {
      await ensureStudyPrivacy(context, ref, showAgain: true);
      return;
    }
    if (!await _canLeave() || !mounted) return;
    if (action == 'new') {
      await _session.open();
      return;
    }
    if (action == 'history') {
      try {
        await widget.repository.purgeExpired();
        if (!mounted) return;
        final id = await showStudyChatHistory(context, widget.notebookId);
        if (mounted && id != null) await _session.open(id: id);
      } catch (_) {
        if (mounted) showMessage(context, studyAiMessages['LOAD_FAILED']!);
      }
      return;
    }
    final id = _session.chatId;
    if (id == null) return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Delete this chat?',
      message: 'This chat and its messages will be deleted from this device.',
      confirmLabel: 'Delete chat',
      cancelLabel: 'Cancel',
      icon: FiloIcons.delete,
    );
    if (!mounted || !confirmed) return;
    try {
      if (ref.read(accountDatabaseProvider).asData?.value !=
          widget.repository.db)
        return;
      await widget.repository.delete(id);
      if (mounted) await _session.open();
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not delete this chat. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final busy =
        ref.watch(aiRequestBusyProvider).asData?.value ??
        _session.client.guard.isBusy;
    final cooldown =
        ref.watch(aiChatCooldownProvider).asData?.value ??
        _session.client.guard.chatCooldownRemaining;
    final sources = ref.watch(studySourcesProvider(widget.notebookId));
    final mode = _session.working && _session.requestMode != null
        ? _session.requestMode!
        : sources.hasValue &&
              !sources.isLoading &&
              !sources.hasError &&
              sources.requireValue.isNotEmpty
        ? 'files'
        : 'general';
    final reason = _session.loading
        ? 'Opening saved chat...'
        : _session.pendingAnswer != null
        ? 'Save this answer before sending another message.'
        : !online
        ? studyAiMessages['OFFLINE']!
        : _session.working || _authorizing
        ? 'Preparing an answer...'
        : busy
        ? studyAiMessages['AI_IN_PROGRESS']!
        : cooldown > Duration.zero
        ? 'Wait ${(cooldown.inMilliseconds / 1000).ceil()} seconds before sending another message.'
        : sources.isLoading
        ? 'Loading saved sources...'
        : sources.hasError
        ? studyAiMessages['LOAD_FAILED']!
        : null;
    final blocked =
        reason != null ||
        _session.error == studyAiMessages['LOAD_FAILED'] &&
            _session.messages.isEmpty;
    final modeLabel = _session.working && _session.requestMode != null
        ? mode == 'files'
              ? 'Answers use your files'
              : 'General knowledge'
        : sources.isLoading
        ? 'Loading saved sources...'
        : sources.hasError
        ? 'Sources unavailable'
        : mode == 'files'
        ? 'Answers use your files'
        : 'General knowledge';
    return PopScope(
      canPop: _allowPop || _session.pendingAnswer == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _canLeave() || !mounted) return;
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              enabled: !_session.working && !_authorizing,
              onSelected: _menu,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'new', child: Text('New chat')),
                const PopupMenuItem(value: 'history', child: Text('History')),
                PopupMenuItem(
                  value: 'delete',
                  enabled: _session.chatId != null,
                  child: const Text('Delete chat'),
                ),
                const PopupMenuItem(
                  value: 'privacy',
                  child: Text('AI Study privacy'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: studyAsync(ref.watch(studyNotebooksProvider), (notebooks) {
            if (!notebooks.any((n) => n.id == widget.notebookId))
              return const Center(
                child: Text('This notebook is no longer available.'),
              );
            return LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Text(
                      modeLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Expanded(
                    child: _session.loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: 'Opening saved chat',
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount:
                                _session.messages.length +
                                (_session.pendingAnswer != null ? 1 : 0) +
                                1,
                            itemBuilder: (_, index) {
                              if (index < _session.messages.length) {
                                final m = _session.messages[index];
                                return StudyChatBubble(
                                  key: ValueKey(m.id),
                                  content: m.content,
                                  role: m.role,
                                  mode: m.mode,
                                  time: m.createdAt,
                                );
                              }
                              if (index == _session.messages.length &&
                                  _session.pendingAnswer != null) {
                                return StudyChatBubble(
                                  content: _session.pendingAnswer!.answer,
                                  role: 'assistant',
                                  mode: _session.pendingAnswer!.mode,
                                  unsaved: true,
                                );
                              }
                              if (_session.working &&
                                  _session.pendingAnswer == null)
                                return Column(
                                  children: [
                                    const Mascot(pose: 'thinking', size: 96),
                                    Semantics(
                                      liveRegion: true,
                                      child: const Text(
                                        'Preparing an answer...',
                                      ),
                                    ),
                                    if (!MediaQuery.disableAnimationsOf(
                                      context,
                                    ))
                                      const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    else
                                      const Text('...'),
                                    TextButton(
                                      onPressed: _session.cancel,
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                );
                              return _session.messages.isEmpty &&
                                      _session.pendingAnswer == null
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Ask a question to start a chat.',
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            },
                          ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * .55,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const StudyOfflineBanner(),
                          const Text(
                            'AI can make mistakes. Check important answers.',
                          ),
                          const SizedBox(height: 8),
                          for (final notice in _session.notices) Text(notice),
                          if (_session.error != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(_session.error!),
                            ),
                          if (_session.error ==
                                  studyAiMessages['LOAD_FAILED'] &&
                              _session.messages.isEmpty)
                            TextButton(
                              onPressed: () => _session.open(
                                id: _session.chatId,
                                latest: _session.chatId == null,
                              ),
                              child: const Text('Try again'),
                            ),
                          if (_session.pendingAnswer != null)
                            TextButton(
                              onPressed: _session.working
                                  ? null
                                  : _session.retrySave,
                              child: const Text('Try saving again'),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: FiloColors.surface,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: FiloColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Add source files',
                                  onPressed:
                                      _session.working ||
                                          _authorizing ||
                                          _session.pendingAnswer != null
                                      ? null
                                      : () => showStudySourcePicker(
                                          context,
                                          widget.notebookId,
                                        ),
                                  icon: const Icon(Icons.attach_file),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _input,
                                    enabled:
                                        !_session.working &&
                                        !_authorizing &&
                                        !_session.loading &&
                                        _session.pendingAnswer == null,
                                    minLines: 1,
                                    maxLines: 4,
                                    onChanged: _session.setDraft,
                                    decoration: const InputDecoration(
                                      labelText: 'Ask a study question...',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Send message',
                                  onPressed:
                                      blocked || _session.draft.trim().isEmpty
                                      ? null
                                      : _send,
                                  icon: const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ),
                          if (reason != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(reason),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }, retry: () => ref.invalidate(studyNotebooksProvider)),
        ),
      ),
    );
  }
}
