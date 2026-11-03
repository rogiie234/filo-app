import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../assessments/data/lesson_text_extractor.dart';
import '../../assessments/domain/ai_sources.dart';
import '../../files/application/files_providers.dart';
import '../application/study_providers.dart';
import '../application/study_source_reader.dart';
import '../domain/study_inputs.dart';
import 'study_widgets.dart';

Future<void> showStudySourcePicker(BuildContext context, String notebookId) =>
    showFiloBottomSheet<void>(
      context: context,
      title: 'Add up to 3 files',
      scrollBody: false,
      builder: (_) => Consumer(
        builder: (_, ref, __) => studyAsync(
          ref.watch(accountDatabaseProvider),
          (db) => db == null
              ? const Text('Sign in again to access your files.')
              : StudySourcePicker(key: ObjectKey(db), notebookId: notebookId),
        ),
      ),
    );

class StudySourcePicker extends ConsumerStatefulWidget {
  const StudySourcePicker({super.key, required this.notebookId});
  final String notebookId;
  @override
  ConsumerState<StudySourcePicker> createState() => _StudySourcePickerState();
}

class _StudySourcePickerState extends ConsumerState<StudySourcePicker> {
  final _selected = <String, LocalFileRecord>{};
  final _status = <String, String>{};
  final _ready = <String>{};
  final _cancel = AiCancelToken();
  bool _reading = false;
  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  void _select(LocalFileRecord file, List<StudySource> sources) {
    if (_reading || _ready.contains(file.id)) return;
    if (_selected.containsKey(file.id)) {
      setState(() {
        _selected.remove(file.id);
        _status.remove(file.id);
      });
      return;
    }
    final problem = StudySourceReader.selectionError(
      file,
      sources,
      pending: _selected.keys.where((id) => !_ready.contains(id)).length,
    );
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    setState(() => _selected[file.id] = file);
  }

  Future<void> _read() async {
    if (_reading) return;
    setState(() => _reading = true);
    try {
      final reader = await ref.read(studySourceReaderProvider.future);
      if (!mounted || reader == null) return;
      for (final file in _selected.values.toList()) {
        if (!mounted || _cancel.isCancelled) break;
        if (_ready.contains(file.id)) continue;
        setState(() => _status[file.id] = 'Reading file...');
        try {
          await reader.add(widget.notebookId, file, operation: _cancel);
          if (!mounted) break;
          setState(() {
            _ready.add(file.id);
            _status[file.id] = 'Ready';
          });
        } on AiCancelled {
          break;
        } on LessonReadException catch (error) {
          if (mounted) setState(() => _status[file.id] = error.message);
        } on StudyLimitExceeded {
          if (mounted)
            setState(() => _status[file.id] = studySourceLimitMessage);
        } catch (_) {
          if (mounted)
            setState(
              () => _status[file.id] =
                  'This file could not be read. Try adding it again.',
            );
        }
      }
      if (mounted)
        ref.invalidate(studyMissingSourcesProvider(widget.notebookId));
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not read saved files. Try again.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retain the autoDispose reader throughout selection/extraction.
    final reader = ref.watch(studySourceReaderProvider);
    final files = ref.watch(localFilesProvider);
    final sources = ref.watch(studySourcesProvider(widget.notebookId));
    final pending = _selected.keys.any((id) => !_ready.contains(id));
    final done = _selected.isNotEmpty && !pending;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
              child: StudyOfflineBanner(),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Downloaded from classes'),
                Tab(text: 'My files'),
              ],
            ),
            Expanded(
              child: studyAsync(
                sources,
                (saved) => studyAsync(
                  files,
                  (items) => TabBarView(
                    children: [
                      _list(
                        items
                            .where(
                              (f) =>
                                  f.sourceAttachmentId != null ||
                                  f.classId != null,
                            )
                            .toList(),
                        saved,
                      ),
                      _list(
                        items
                            .where(
                              (f) =>
                                  f.sourceAttachmentId == null &&
                                  f.classId == null,
                            )
                            .toList(),
                        saved,
                      ),
                    ],
                  ),
                  retry: () => ref.invalidate(localFilesProvider),
                ),
                retry: () =>
                    ref.invalidate(studySourcesProvider(widget.notebookId)),
              ),
            ),
            if (reader.hasError)
              const Padding(
                padding: EdgeInsets.all(FiloSpacing.s16),
                child: EmptyState(
                  title: 'Could not open your saved files. Try reopening the picker.',
                  pose: 'confused',
                  bob: false,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(FiloSpacing.screen),
              child: FiloButton(
                label: _reading
                    ? 'Reading file...'
                    : done
                    ? 'Done'
                    : _status.keys.any((id) => !_ready.contains(id)) && pending
                    ? 'Try again'
                    : 'Add files',
                onPressed: done
                    ? () => Navigator.pop(context)
                    : _reading ||
                          !pending ||
                          reader.isLoading ||
                          reader.hasError ||
                          reader.value == null
                    ? null
                    : _read,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<LocalFileRecord> files, List<StudySource> sources) {
    if (files.isEmpty)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(FiloSpacing.screen),
          child: EmptyState(
            title: 'No saved files here. Add files in Files or download class files first.',
            pose: 'folder',
            bob: false,
          ),
        ),
      );
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (_, index) {
        final file = files[index];
        final existing = sources.any(
          (s) =>
              s.fileId == file.id ||
              (file.sourceAttachmentId != null &&
                  s.sourceKey == 'att:${file.sourceAttachmentId}'),
        );
        final detail = _status[file.id] ?? (existing ? 'Ready' : null);
        return CheckboxListTile(
          secondary: FiloFileTypeTile(
            details: FiloFileDetails.fromName(
              file.name,
              mimeType: file.mimeType,
            ),
          ),
          title: Text(file.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FiloFileTypeLabel(
                details: FiloFileDetails.fromName(
                  file.name,
                  mimeType: file.mimeType,
                ),
              ),
              Text(
                '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB${detail == null ? '' : '\n$detail'}',
              ),
            ],
          ),
          value: existing || _selected.containsKey(file.id),
          onChanged: _reading || existing
              ? null
              : (_) => _select(file, sources),
        );
      },
    );
  }
}
