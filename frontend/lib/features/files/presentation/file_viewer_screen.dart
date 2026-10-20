import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../data/local/app_database.dart';
import '../application/files_providers.dart';
import '../data/files_repository.dart';

String? _fileMime(LocalFileRecord row) =>
    {
      '.pdf': 'application/pdf',
      '.txt': 'text/plain',
      '.csv': 'text/csv',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    }[p.extension(row.relativePath).toLowerCase()] ??
    (row.mimeType == 'application/octet-stream' ? null : row.mimeType);

Future<void> openExternal(
  BuildContext context,
  FilesRepository repository,
  LocalFileRecord row,
) async {
  final result = await OpenFilex.open(
    repository.storage.file(row.relativePath).path,
    type: _fileMime(row),
  );
  if (result.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.type == ResultType.noAppToOpen
              ? 'No app on your phone can open this file. Install a compatible app, then try again.'
              : 'This file is no longer on your device.',
        ),
      ),
    );
  }
}

Future<void> exportFile(
  BuildContext context,
  FilesRepository repository,
  LocalFileRecord row,
) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          repository.storage.file(row.relativePath).path,
          mimeType: _fileMime(row),
        ),
      ],
      fileNameOverrides: [row.name],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

class FileViewerScreen extends ConsumerStatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.file,
    required this.repository,
  });
  final LocalFileRecord file;
  final FilesRepository repository;
  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  late LocalFileRecord _row = widget.file;
  late Future<bool> _exists = _local.exists();
  File get _local => widget.repository.storage.file(_row.relativePath);
  final _imageTransform = TransformationController();
  int _page = 1, _pages = 0, _textPart = 0;
  bool _downloading = false;

  Future<void> _again() async {
    setState(() => _downloading = true);
    try {
      final db = widget.repository.db;
      final a = await (db.select(
        db.cachePostAttachments,
      )..where((a) => a.id.equals(_row.sourceAttachmentId!))).getSingleOrNull();
      if (a == null) {
        throw StateError('unavailable');
      }
      if (!mounted) {
        return;
      }
      final manager = await ref.read(downloadManagerProvider.future);
      final result = await manager?.download(
        a,
        _row.classId!,
        _row.sourcePostId!,
      );
      if (result == null) {
        throw StateError('download failed');
      }
      if (mounted) {
        setState(() {
          _row = result;
          _exists = _local.exists();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This item is no longer available, or the download failed. Connect and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<String> _text() async {
    const chunk = 65536;
    final nominalStart = _textPart * chunk;
    final start = math.max(0, nominalStart - 3);
    final nominalEnd = math.min(nominalStart + chunk, _row.size);
    final end = math.min(nominalEnd + 3, _row.size);
    final bytes = await _local.openRead(start, end).expand((b) => b).toList();
    var first = nominalStart - start, last = nominalEnd - start;
    while (first < bytes.length && (bytes[first] & 0xc0) == 0x80) {
      first++;
    }
    while (last < bytes.length && (bytes[last] & 0xc0) == 0x80) {
      last++;
    }
    return utf8.decode(bytes.sublist(first, last), allowMalformed: true);
  }

  @override
  void dispose() {
    _imageTransform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(_row.relativePath).toLowerCase();
    final image =
        _row.mimeType?.startsWith('image/') == true ||
        ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'].contains(ext);
    final pdf = ext == '.pdf' || _row.mimeType == 'application/pdf';
    final text =
        ['.txt', '.md', '.csv', '.log'].contains(ext) ||
        _row.mimeType?.startsWith('text/plain') == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(_row.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              try {
                if (action == 'external') {
                  await openExternal(context, widget.repository, _row);
                } else {
                  await exportFile(context, widget.repository, _row);
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not open or export this file. Try again.',
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'external',
                child: Text('Open in another app'),
              ),
              PopupMenuItem(value: 'export', child: Text('Export a copy')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _exists,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('This file is no longer on your device.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This file is no longer on your device.'),
                  if (_row.sourceAttachmentId != null &&
                      _row.classId != null &&
                      _row.sourcePostId != null)
                    TextButton(
                      onPressed: _downloading ? null : _again,
                      child: Text(
                        _downloading ? 'Downloading…' : 'Download again',
                      ),
                    ),
                ],
              ),
            );
          }
          if (pdf) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Page $_page${_pages == 0 ? '' : ' of $_pages'}'),
                ),
                Expanded(
                  child: PdfViewer.file(
                    _local.path,
                    params: PdfViewerParams(
                      onViewerReady: (document, controller) {
                        if (mounted) {
                          setState(() => _pages = document.pages.length);
                        }
                      },
                      onPageChanged: (page) {
                        if (mounted) {
                          setState(() => _page = page ?? 1);
                        }
                      },
                    ),
                  ),
                ),
              ],
            );
          }
          if (image) {
            return GestureDetector(
              onDoubleTap: () => _imageTransform.value =
                  _imageTransform.value.getMaxScaleOnAxis() > 1.1
                  ? Matrix4.identity()
                  : Matrix4.diagonal3Values(2.5, 2.5, 1),
              child: InteractiveViewer(
                transformationController: _imageTransform,
                minScale: 0.5,
                maxScale: 8,
                child: Center(
                  child: Image.file(
                    _local,
                    errorBuilder: (_, _, _) =>
                        const Text('Could not open this image.'),
                  ),
                ),
              ),
            );
          }
          if (text) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _textPart > 0
                          ? () => setState(() => _textPart--)
                          : null,
                      icon: const FiloIcon(FiloIcons.chevronLeft),
                    ),
                    Text('Text part ${_textPart + 1}'),
                    IconButton(
                      onPressed: (_textPart + 1) * 65536 < _row.size
                          ? () => setState(() => _textPart++)
                          : null,
                      icon: const FiloIcon(FiloIcons.chevronRight),
                    ),
                  ],
                ),
                Expanded(
                  child: FutureBuilder<String>(
                    future: _text(),
                    builder: (context, data) => data.hasError
                        ? const Center(child: Text('Could not read this file.'))
                        : !data.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(data.data!),
                          ),
                  ),
                ),
              ],
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FiloIcon(FiloIcons.document, size: 64),
                  Text(_row.name),
                  Text(
                    '${_row.size} bytes · ${ext.isEmpty ? 'File' : ext.substring(1).toUpperCase()}',
                  ),
                  const SizedBox(height: 16),
                  const Text('Open this file in another app on your phone.'),
                  FilledButton(
                    onPressed: () =>
                        openExternal(context, widget.repository, _row),
                    child: const Text('Open in another app'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
