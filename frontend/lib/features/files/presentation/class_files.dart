import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../posts/application/post_providers.dart';
import '../application/files_providers.dart';
import 'class_files_preview.dart';
import 'download_file_card.dart';

class ClassFiles extends ConsumerStatefulWidget {
  const ClassFiles({super.key, required this.hasSamples, this.classId});
  final bool hasSamples;
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
      return PreviewClassFiles(hasSamples: widget.hasSamples);
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
      padding: const EdgeInsets.all(24),
      children: [
        Text('Class files', style: Theme.of(context).textTheme.headlineMedium),
        if (!online)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'You\u2019re offline. Files marked Available offline can still be opened. Connect to download more files or open web links.',
            ),
          ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.9, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in ['All', 'Images', 'PDFs', 'Documents'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: filter == name,
                      onSelected: (_) => setState(() => filter = name),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (data.isLoading || sync.isLoading && rows.isEmpty) ...[
          for (var i = 0; i < 3; i++)
            const Card(
              child: SizedBox(
                height: 104,
                child: Center(child: LinearProgressIndicator()),
              ),
            ),
        ] else if (data.hasError || sync.hasError)
          TextButton(
            onPressed: () {
              ref.invalidate(classFilesProvider(id));
              ref.invalidate(postSyncProvider(id));
            },
            child: const Text("Couldn't load files. Try again."),
          ),
        if (rows.isEmpty && !data.isLoading && !sync.isLoading)
          Text(
            !online && (data.asData?.value.isEmpty ?? true)
                ? "You're offline. Connect to load class files."
                : filter != 'All'
                ? 'No matching files.'
                : sync.hasError
                ? 'Could not refresh class files.'
                : 'No files yet.',
          ),
        for (final row in rows)
          DownloadFileCard(
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
