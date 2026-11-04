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
    final rows = (data.asData?.value ?? []).where((row) {
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
        if (widget.showHeading)
          Text(
            'Class files',
            style: Theme.of(context).textTheme.headlineMedium,
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
        if (data.isLoading || sync.isLoading && rows.isEmpty) ...[
          for (var i = 0; i < 3; i++) const _ClassFileSkeleton(),
        ] else if ((data.hasError || sync.hasError) && rows.isNotEmpty)
          TextButton(
            onPressed: () {
              ref.invalidate(classFilesProvider(id));
              ref.invalidate(postSyncProvider(id));
            },
            child: const Text("Couldn't load files. Try again."),
          ),
        if (rows.isEmpty && !data.isLoading && !sync.isLoading)
          if (!data.hasError && !sync.hasError && online)
            FiloIllustratedEmptyState(
              asset: 'assets/illustrations/library-empty-folder.png',
              title: filter != 'All' ? 'No matching files.' : 'No files yet.',
            )
          else
            EmptyState(
              pose: data.hasError || sync.hasError
                  ? 'confused'
                  : !online
                  ? 'sleepy'
                  : filter != 'All'
                  ? 'curious'
                  : 'folder',
              bob: online && !data.hasError && !sync.hasError,
              action: data.hasError || sync.hasError
                  ? TextButton(
                      onPressed: () {
                        ref.invalidate(classFilesProvider(id));
                        ref.invalidate(postSyncProvider(id));
                      },
                      child: const Text('Retry'),
                    )
                  : null,
              title: data.hasError
                  ? "Couldn't load files. Try again."
                  : sync.hasError
                  ? 'Could not refresh class files.'
                  : !online && (data.asData?.value.isEmpty ?? true)
                  ? "You're offline. Connect to load class files."
                  : filter != 'All'
                  ? 'No matching files.'
                  : 'No files yet.',
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

class _ClassFileSkeleton extends StatelessWidget {
  const _ClassFileSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading class file',
    child: ExcludeSemantics(
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: FiloSpacing.s12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FiloRadii.large),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FiloSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FiloSkeleton(width: 48, height: 48),
                  const SizedBox(width: FiloSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        FractionallySizedBox(
                          widthFactor: .8,
                          child: FiloSkeleton(),
                        ),
                        SizedBox(height: FiloSpacing.s4),
                        FractionallySizedBox(
                          widthFactor: .35,
                          child: FiloSkeleton(height: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FiloSpacing.s4),
              const FractionallySizedBox(
                widthFactor: .55,
                child: FiloSkeleton(height: 14),
              ),
              const SizedBox(height: FiloSpacing.s4),
              const FractionallySizedBox(
                widthFactor: .7,
                child: FiloSkeleton(height: 16),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: FiloSpacing.s4),
                child: Divider(height: 1),
              ),
              const OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: FiloSpacing.s8,
                overflowSpacing: FiloSpacing.s4,
                children: [
                  FiloSkeleton(width: 104, height: 32),
                  FiloSkeleton(width: 112, height: 48),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
