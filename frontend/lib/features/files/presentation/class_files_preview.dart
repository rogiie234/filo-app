import 'package:flutter/material.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../classes/domain/prototype_models.dart';

class PreviewClassFiles extends StatefulWidget {
  const PreviewClassFiles({
    super.key,
    required this.hasSamples,
    this.showHeading = true,
  });
  final bool hasSamples;
  final bool showHeading;
  @override
  State<PreviewClassFiles> createState() => _PreviewClassFilesState();
}

class _PreviewClassFilesState extends State<PreviewClassFiles> {
  String _filter = 'All';
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final files = (widget.hasSamples ? sampleFiles : <PreviewFile>[]).where(
      (file) =>
          (_filter == 'All' || file.type == _filter) &&
          file.name.toLowerCase().contains(_query.toLowerCase()),
    );
    return ListView(
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
          'Good ideas, kept together.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: FiloSpacing.screen),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Find a file',
            prefixIcon: FiloIcon(FiloIcons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: FiloSpacing.s16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in ['All', 'Images', 'PDFs', 'Documents'])
                Padding(
                  padding: const EdgeInsets.only(right: FiloSpacing.s8),
                  child: FiloAnimatedChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FiloSpacing.screen),
        if (files.isEmpty)
          FiloIllustratedEmptyState(
            asset: 'assets/illustrations/library-empty-folder.png',
            title: 'No files here yet.',
            message: 'Class materials will have a home right here.',
          ),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
            child: FileCard(file: file),
          ),
        if (files.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: FiloSpacing.s12),
            child: Text(
              'Sample file previews. Downloads are not connected yet.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.file});
  final PreviewFile file;
  @override
  Widget build(BuildContext context) => FiloPanel(
    padding: const EdgeInsets.all(FiloSpacing.s12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FiloFileTypeTile(details: FiloFileDetails.fromName(file.name)),
            const SizedBox(width: FiloSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: FiloSpacing.s4),
                  FiloFileTypeLabel(
                    details: FiloFileDetails.fromName(file.name),
                  ),
                  Text(
                    '${file.size} · Class material',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: FiloSpacing.s4),
        const Divider(height: 1),
        const SizedBox(height: FiloSpacing.s4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
            onPressed: () => showFilePreview(context, file),
            icon: const FiloIcon(FiloIcons.visible, size: 20),
            label: const Text('Preview file'),
          ),
        ),
      ],
    ),
  );
}

Future<void> showFilePreview(BuildContext context, PreviewFile file) =>
    showFiloBottomSheet<void>(
      title: 'File preview',
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Chip(label: Text('Sample preview')),
              const SizedBox(height: FiloSpacing.s12),
              Text(file.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: FiloSpacing.s20),
              Text(
                file.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: FiloSpacing.screen),
              FiloButton(
                label: 'Back to files',
                secondary: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
