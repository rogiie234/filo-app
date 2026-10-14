import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/domain/prototype_models.dart';

class ClassFiles extends StatefulWidget {
  const ClassFiles({super.key, required this.hasSamples});
  final bool hasSamples;
  @override
  State<ClassFiles> createState() => _ClassFilesState();
}

class _ClassFilesState extends State<ClassFiles> {
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
            prefixIcon: Icon(Icons.search_rounded),
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
              child: Icon(
                file.type == 'PDFs'
                    ? Icons.picture_as_pdf_outlined
                    : file.type == 'Images'
                    ? Icons.image_outlined
                    : Icons.description_outlined,
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
            icon: const Icon(Icons.visibility_outlined, size: 20),
            label: const Text('Preview file'),
          ),
        ),
      ],
    ),
  );
}

Future<void> showFilePreview(BuildContext context, PreviewFile file) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
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
