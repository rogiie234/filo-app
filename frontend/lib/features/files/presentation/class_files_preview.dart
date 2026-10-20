import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/domain/prototype_models.dart';

class PreviewClassFiles extends StatefulWidget {
  const PreviewClassFiles({super.key, required this.hasSamples});
  final bool hasSamples;
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
      padding: const EdgeInsets.all(24),
      children: [
        Text('Class files', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Good ideas, kept together.',
          style: TextStyle(color: FiloColors.secondary),
        ),
        const SizedBox(height: 24),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Find a file',
            prefixIcon: FiloIcon(FiloIcons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in ['All', 'Images', 'PDFs', 'Documents'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (files.isEmpty)
          const EmptyState(
            title: 'No files here yet.',
            message: 'Class materials will have a home right here.',
          ),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FileCard(file: file),
          ),
        if (files.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Sample file previews. Downloads are not connected yet.',
              style: TextStyle(color: FiloColors.secondary),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: file.type == 'PDFs'
                    ? const Color(0xFFFBE4E0)
                    : FiloColors.selected,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FiloIcon(
                file.type == 'PDFs'
                    ? FiloIcons.pdf
                    : file.type == 'Images'
                    ? FiloIcons.image
                    : FiloIcons.document,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${file.size} · Class material',
                    style: const TextStyle(color: FiloColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Chip(label: Text('Sample preview')),
              const SizedBox(height: 12),
              Text(file.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Text(
                file.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
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
