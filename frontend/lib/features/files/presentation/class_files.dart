import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../posts/application/post_providers.dart';
import '../application/files_providers.dart';
import 'class_files_preview.dart';
import 'download_file_card.dart';

class ClassFiles extends ConsumerStatefulWidget {
  const ClassFiles({
    super.key,
    required this.hasSamples,
    this.classId,
    this.showHeading = true,
  });
  final bool hasSamples;
  final bool showHeading;
  final String? classId;
  @override
  ConsumerState<ClassFiles> createState() => _ClassFilesState();
}

class _ClassFilesState extends ConsumerState<ClassFiles> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final id = widget.classId;
    if (id == null) {
      return PreviewClassFiles(
        hasSamples: widget.hasSamples,
        showHeading: widget.showHeading,
      );
    }
    final data = ref.watch(classFilesProvider(id));
    final sync = ref.watch(postSyncProvider(id));
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final snapshots = ref.watch(classFileSnapshotsProvider);
    final cached = data.asData?.value ?? snapshots[id];
    final allRows = cached ?? <ClassFileEntry>[];
    final checkpoint = allRows.isEmpty
        ? ref.watch(streamLoadedProvider(id))
        : null;
    final failed =
        data.hasError || sync.hasError || checkpoint?.hasError == true;
    final known = allRows.isNotEmpty || checkpoint?.asData?.value == true;
    final initialLoading =
        !failed &&
        ((data.isLoading && cached == null) ||
            (online && allRows.isEmpty && !known && sync.isLoading));
    final rows = allRows.where((row) {
      final icon = fileIcon(row.attachment.name, row.attachment.mimeType);
      return filter == 'All' ||
          filter == 'Images' && icon == FiloIcons.image ||
          filter == 'PDFs' && icon == FiloIcons.pdf ||
          filter == 'Documents' &&
              ![FiloIcons.image, FiloIcons.pdf].contains(icon);
    }).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(FiloSpacing.screen),
      children: [
        if (widget.showHeading) ...[
          Text(
            'Class files',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: FiloSpacing.s8),
        ],
        Text(
          'Files shared in this class.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (!online)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: FiloSpacing.s12),
            child: Text(
              'You\u2019re offline. Files marked Available offline can still be opened. Connect to download more files or open web links.',
            ),
          ),
        const SizedBox(height: FiloSpacing.s16),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [FiloPaint.white, FiloPaint.white, FiloPaint.transparent],
            stops: [0, 0.9, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in ['All', 'Images', 'PDFs', 'Documents'])
                  Padding(
                    padding: const EdgeInsets.only(right: FiloSpacing.s8),
                    child: FiloAnimatedChip(
                      label: Text(name),
                      selected: filter == name,
                      onSelected: (_) => setState(() => filter = name),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FiloSpacing.s16),
        if (initialLoading)
          const Padding(
            padding: EdgeInsets.all(FiloSpacing.screen),
            child: Center(
              child: FiloCircularProgressIndicator(
                semanticsLabel: 'Loading class files',
              ),
            ),
          ),
        if (failed && rows.isNotEmpty)
          TextButton(
            onPressed: () {
              ref.invalidate(classFilesProvider(id));
              ref.invalidate(postSyncProvider(id));
              if (checkpoint?.hasError == true) {
                ref.invalidate(streamLoadedProvider(id));
              }
            },
            child: const Text("Couldn't load files. Try again."),
          ),
        if (rows.isEmpty && !initialLoading)
          if (!failed && (online || known))
            FiloIllustratedEmptyState(
              asset: 'assets/illustrations/library-empty-folder.png',
              title: filter != 'All' ? 'No matching files.' : 'No files yet.',
            )
          else
            EmptyState(
              pose: failed ? 'confused' : 'sleepy',
              bob: false,
              action: failed
                  ? TextButton(
                      onPressed: () {
                        ref.invalidate(classFilesProvider(id));
                        ref.invalidate(postSyncProvider(id));
                        if (checkpoint?.hasError == true) {
                          ref.invalidate(streamLoadedProvider(id));
                        }
                      },
                      child: const Text('Retry'),
                    )
                  : null,
              title: data.hasError || checkpoint?.hasError == true
                  ? "Couldn't load files. Try again."
                  : sync.hasError
                  ? 'Could not refresh class files.'
                  : "You're offline. Connect to load class files.",
            ),
        for (final row in rows)
          DownloadFileCard(
            showMascot: true,
            key: ValueKey(row.attachment.id),
            classId: id,
            postId: row.post.id,
            attachment: row.attachment,
            postTitle: row.post.title,
          ),
      ],
    );
  }
}
