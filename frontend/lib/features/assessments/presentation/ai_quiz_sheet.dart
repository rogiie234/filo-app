import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_providers.dart';
import '../../files/application/files_providers.dart';
import '../../files/data/file_storage.dart';
import '../application/ai_providers.dart';
import '../data/ai_quiz_client.dart';
import '../data/ai_quiz_response.dart';
import '../data/ai_source_loader.dart';
import '../data/lesson_text_extractor.dart';
import '../domain/ai_sources.dart';

class AiQuizSheet extends ConsumerStatefulWidget {
  const AiQuizSheet({
    super.key,
    required this.classId,
    required this.quizId,
    this.regenerateType,
    this.initialContext,
    this.currentPrompts = const [],
  });
  final String classId, quizId;
  final String? regenerateType;
  final AiSourceContext? initialContext;
  final List<String> currentPrompts;
  @override
  ConsumerState<AiQuizSheet> createState() => _AiQuizSheetState();
}

class _AiQuizSheetState extends ConsumerState<AiQuizSheet> {
  final _sources = <AiSourceSelection>[];
  final _topic = TextEditingController();
  late final Map<String, int> _counts;
  String _difficulty = 'easy';
  bool _busy = false, _acknowledged = false, _initializing = true;
  bool _restoredContext = false;
  String? _error;
  AiCancelToken? _generation;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _counts = {
      for (var i = 0; i < aiQuestionTypes.length; i++)
        aiQuestionTypes[i]: widget.regenerateType == null
            ? [6, 2, 2, 1][i]
            : widget.regenerateType == aiQuestionTypes[i]
            ? 1
            : 0,
    };
    _difficulty = widget.initialContext?.difficulty ?? 'easy';
    _topic.text = widget.initialContext?.topicFocus ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      final cache = await ref.read(fileTextCacheProvider.future);
      if (!mounted) return;
      if (cache == null) throw const AiFailure('AUTH');
      final accepted = await cache.privacyAccepted();
      final context = widget.initialContext;
      if (context != null) {
        final restored = await cache.restore(context);
        if (!mounted) return;
        if (restored == null) {
          _error = 'Cached source text is no longer available. Pick the files again to regenerate.';
        } else {
          _restoredContext = true;
          for (var i = 0; i < restored.length; i++) {
            _sources.add(
              AiSourceSelection(
                  id: context.sources[i].key,
                  name: context.sources[i].name,
                  size: 0,
                )
                ..result = LessonText(
                  text: restored[i]['text']!,
                  sourceKey: context.sources[i].key,
                  fromCache: true,
                ),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _acknowledged = accepted;
        _initializing = false;
      });
      if (!accepted) await _privacy();
    } catch (e) {
      if (mounted)
        setState(() {
          _error = aiFriendlyError(e);
          _initializing = false;
        });
    }
  }

  Future<void> _privacy() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Before using AI'),
        content: const Text(aiPrivacyNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    try {
      final cache = await ref.read(fileTextCacheProvider.future);
      if (cache == null) throw const AiFailure('AUTH');
      await cache.acceptPrivacy();
      if (mounted) setState(() => _acknowledged = true);
    } catch (e) {
      if (mounted) setState(() => _error = aiFriendlyError(e));
    }
  }

  @override
  void dispose() {
    _generation?.cancel();
    for (final source in _sources) {
      source.cancel.cancel();
    }
    _topic.dispose();
    super.dispose();
  }

  Future<void> _pickPhone() async {
    if (_busy ||
        (widget.regenerateType != null && _restoredContext) ||
        _sources.length >= 3)
      return;
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: LessonTextExtractor.supported,
      );
      if (!mounted || picked.isEmpty) return;
      if (_sources.length + picked.length > 3) {
        setState(() => _error = 'Pick up to 3 files.');
        return;
      }
      final pending = <(AiSourceSelection, String?)>[];
      for (final file in picked) {
        int? size;
        try {
          size = await file.length();
        } catch (_) {}
        if (!mounted) return;
        final source = AiSourceSelection(
          id: 'phone:${_serial++}',
          name: file.name,
          size: size,
        );
        _sources.add(source);
        if (size == null) {
          source.error = 'The file size could not be read. Remove this file and choose it again.';
          continue;
        }
        pending.add((source, file.path));
      }
      setState(() => _error = null);
      for (final (source, path) in pending) {
        if (!mounted) return;
        await _read(source, () async {
          checkAiSource(source.name, source.size!);
          if (path == null) throw lessonReadFailed;
          final extractor = await ref.read(lessonExtractorProvider.future);
          source.cancel.check();
          return extractor.extract(
            path,
            extension(source.name),
            draftQuizId: widget.quizId,
            cancel: source.cancel,
            onProgress: (p) => _progress(source, p),
          );
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'The files could not be selected. Try again.');
    }
  }

  Future<void> _pickClass(ClassFileEntry entry) async {
    if (_busy ||
        (widget.regenerateType != null && _restoredContext) ||
        _sources.length >= 3 ||
        _sources.any((s) => s.id == 'att:${entry.attachment.id}'))
      return;
    final source = AiSourceSelection(
      id: 'att:${entry.attachment.id}',
      name: entry.attachment.name,
      size: entry.attachment.sizeBytes ?? 0,
    );
    setState(() {
      _sources.add(source);
      _error = null;
    });
    await _read(source, () async {
      final userClient = ref.read(supabaseClientProvider);
      final user = userClient.auth.currentUser?.id;
      final files = await ref.read(filesRepositoryProvider.future);
      if (!mounted) throw const AiCancelled();
      final cache = await ref.read(fileTextCacheProvider.future);
      if (!mounted) throw const AiCancelled();
      final extractor = await ref.read(lessonExtractorProvider.future);
      if (files == null || cache == null) throw const AiFailure('AUTH');
      source.cancel.check();
      return AiSourceLoader(
        files,
        userClient,
        extractor,
        cache,
        () => mounted && userClient.auth.currentUser?.id == user,
      ).classMaterial(
        entry,
        widget.classId,
        widget.quizId,
        source.cancel,
        (p) => _progress(source, p),
      );
    });
  }

  void _progress(AiSourceSelection source, ExtractionProgress progress) {
    if (mounted && _sources.contains(source) && !source.cancel.isCancelled)
      setState(() => source.progress = progress);
  }

  Future<void> _read(
    AiSourceSelection source,
    Future<LessonText> Function() read,
  ) async {
    try {
      source.cancel.check();
      final result = await read();
      source.cancel.check();
      if (mounted && _sources.contains(source))
        setState(() => source.result = result);
    } catch (e) {
      if (mounted && _sources.contains(source))
        setState(
          () => source.error = e is AiCancelled
              ? 'Reading cancelled. Remove this file to choose it again.'
              : e is LessonReadException
              ? e.message
              : e is FileProblem
              ? e.message
              : 'This file could not be read. Choose it again.',
        );
    }
  }

  Future<void> _refreshFiles() async {
    try {
      await (await ref.read(syncCoordinatorProvider.future))?.run();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Class materials could not be refreshed. Check your connection and try again.',
        );
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    final allocation = allocateAiSources(_sources);
    if (allocation.texts.isEmpty) return;
    final token = AiCancelToken();
    _generation = token;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(aiQuizClientProvider);
      var texts = allocation.texts;
      var sourceContext = AiSourceContext(
        sources: allocation.prefixes,
        difficulty: _difficulty,
        topicFocus: _topic.text.trim(),
      );
      if (widget.regenerateType != null && widget.initialContext != null) {
        final original = widget.initialContext!;
        final keys = _sources.map((s) => s.result?.sourceKey).toSet();
        if (original.sources.any((s) => !keys.contains(s.key))) {
          throw const LessonReadException(
            'SOURCE_CHANGED',
            'Choose the original files to regenerate from the same text, or generate a new question instead.',
          );
        }
        final cache = await ref.read(fileTextCacheProvider.future);
        final restored = await cache?.restore(original);
        if (restored == null)
          throw const LessonReadException(
            'NO_TEXT',
            'The original source text is unavailable. Choose the original files again.',
          );
        texts = restored;
        sourceContext = original;
      }
      final result = await client.generate(
        classId: widget.classId,
        quizId: widget.quizId,
        texts: texts,
        counts: Map.of(_counts),
        cancel: token,
        context: sourceContext,
        regenerateType: widget.regenerateType,
        currentPrompts: widget.currentPrompts,
      );
      if (!mounted || token.isCancelled) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${result.questions.length} questions generated'),
          content: Text(
            [
              for (final type in aiQuestionTypes)
                '${_label(type)}: ${result.questions.where((q) => q.type == type).length} returned, ${result.dropped[type]} dropped, ${result.missing[type]} missing.',
            ].join('\n\n'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (mounted && !token.isCancelled) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => _error = aiFriendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(String type) => const {
    'multiple_choice': 'Multiple choice',
    'true_false': 'True or false',
    'identification': 'Identification',
    'essay': 'Essay',
  }[type]!;
  IconData _icon(String name) =>
      ['png', 'jpg', 'jpeg', 'webp'].contains(extension(name))
      ? Icons.image_outlined
      : extension(name) == 'pdf'
      ? Icons.picture_as_pdf_outlined
      : Icons.description_outlined;

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final allocation = allocateAiSources(_sources);
    final total = _counts.values.fold<int>(0, (n, v) => n + v);
    final reading = _sources.any((s) => s.result == null && s.error == null);
    final classFiles = ref.watch(classFilesProvider(widget.classId));
    final canPickSources =
        !_busy && !(widget.regenerateType != null && _restoredContext);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pick up to 3 files, 10 MB each. Text-based PDF, DOCX, PPTX, TXT, JPEG, PNG and WebP are supported. Scanned PDFs are unsupported.',
          ),
          const SizedBox(height: 12),
          if (canPickSources)
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(
                        text: online
                            ? 'Class materials'
                            : 'Class materials (offline)',
                      ),
                      const Tab(text: 'From phone'),
                    ],
                  ),
                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      children: [
                        if (!online)
                          const Center(
                            child: Text(
                              'Connect to choose class materials. You can still read files available through From phone.',
                            ),
                          )
                        else
                          classFiles.when(
                            data: (entries) => Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _refreshFiles,
                                    child: const Text('Refresh'),
                                  ),
                                ),
                                Expanded(
                                  child: entries.isEmpty
                                      ? const Center(
                                          child: Text('No class files yet.'),
                                        )
                                      : ListView(
                                          children: [
                                            for (final entry in entries)
                                              ListTile(
                                                leading: Icon(
                                                  _icon(entry.attachment.name),
                                                ),
                                                title: Text(
                                                  entry.attachment.name,
                                                ),
                                                subtitle: Text(
                                                  '${entry.attachment.sizeBytes ?? 0} bytes',
                                                ),
                                                enabled:
                                                    _sources.length < 3 &&
                                                    !_sources.any(
                                                      (s) =>
                                                          s.id ==
                                                          'att:${entry.attachment.id}',
                                                    ),
                                                onTap: () => _pickClass(entry),
                                              ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => Center(
                              child: TextButton(
                                onPressed: _refreshFiles,
                                child: const Text(
                                  'Retry loading class materials',
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _sources.length < 3 ? _pickPhone : null,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Select from phone'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          for (final source in _sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(source.name)),
              title: Text(source.name),
              subtitle: Text(
                '${source.size == null ? 'Size unavailable' : '${source.size} bytes'}\n${source.error ?? (source.result == null ? source.progress?.stage ?? 'Reading file...' : 'Ready · ${source.result!.characterCount} characters${source.result!.fromCache ? ' · Cached' : ''}')}',
              ),
              trailing: IconButton(
                tooltip: 'Remove ${source.name}',
                onPressed: !canPickSources
                    ? null
                    : () {
                        source.cancel.cancel();
                        setState(() => _sources.remove(source));
                      },
                icon: const Icon(Icons.close),
              ),
            ),
          for (final source in _sources) ...[
            if (source.progress?.total != null &&
                source.result == null &&
                source.error == null)
              Text(
                '${source.name}: ${source.progress!.completed ?? 0} / ${source.progress!.total}',
              ),
            for (final warning in source.result?.warnings ?? <String>[])
              Text('${source.name}: $warning'),
          ],
          for (final warning in allocation.warnings) Text(warning),
          const SizedBox(height: 16),
          if (widget.regenerateType == null) ...[
            Text(
              '$total of 20 questions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final type in aiQuestionTypes)
              Row(
                children: [
                  Expanded(child: Text(_label(type))),
                  IconButton(
                    tooltip: 'Fewer ${_label(type)} questions',
                    onPressed: !_busy && _counts[type]! > 0
                        ? () =>
                              setState(() => _counts[type] = _counts[type]! - 1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('${_counts[type]}'),
                  IconButton(
                    tooltip: 'More ${_label(type)} questions',
                    onPressed: !_busy && total < 20
                        ? () =>
                              setState(() => _counts[type] = _counts[type]! + 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            const Text('Difficulty'),
            Wrap(
              spacing: 8,
              children: [
                for (final level in ['easy', 'medium', 'hard'])
                  ChoiceChip(
                    label: Text(
                      '${level[0].toUpperCase()}${level.substring(1)}',
                    ),
                    selected: _difficulty == level,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _difficulty = level),
                  ),
              ],
            ),
            TextField(
              controller: _topic,
              enabled: !_busy,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Topic focus (optional)',
                helperText: 'Enter a topic from your files, or leave blank to use the full text.',
              ),
            ),
          ] else
            Text(
              'Regenerate one ${_label(widget.regenerateType!)} question · $_difficulty',
            ),
          const SizedBox(height: 16),
          const Text(aiPrivacyNotice),
          if (!_acknowledged && !_initializing)
            TextButton(
              onPressed: _privacy,
              child: const Text('Read and acknowledge privacy notice'),
            ),
          if (_busy) ...[
            Image.asset(
              'assets/mascots/thinking.png',
              height: 120,
              semanticLabel: 'Generating questions',
            ),
            Semantics(liveRegion: true, child: Text('Generating questions...')),
            TextButton(
              onPressed: () => _generation?.cancel(),
              child: const Text('Cancel'),
            ),
            const Text('Cancel stops waiting. The server may still finish.'),
          ],
          if (!online)
            const Text(
              "You're offline. Connect to the internet to generate questions, or create questions manually.",
            ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                !_busy &&
                    !_initializing &&
                    _acknowledged &&
                    online &&
                    !reading &&
                    allocation.texts.isNotEmpty &&
                    total > 0
                ? _generate
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: FiloColors.primary,
            ),
            child: Text(
              widget.regenerateType == null
                  ? 'Generate'
                  : 'Regenerate question',
            ),
          ),
        ],
      ),
    );
  }
}
