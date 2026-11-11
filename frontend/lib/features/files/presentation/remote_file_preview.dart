import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/filo_widgets.dart';

class RemoteFilePreview extends StatefulWidget {
  const RemoteFilePreview({
    super.key,
    required this.name,
    required this.mimeType,
    required this.browserOnly,
    required this.load,
  });
  final String name;
  final String? mimeType;
  final bool browserOnly;
  final Future<Uri> Function() load;

  @override
  State<RemoteFilePreview> createState() => _RemoteFilePreviewState();
}

class _RemoteFilePreviewState extends State<RemoteFilePreview> {
  late Future<Uri> _source = widget.load();

  Future<void> _browser(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Browser unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: FutureBuilder<Uri>(
      future: _source,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            title: 'Could not preview this file. Try again.',
            bob: false,
            action: TextButton(
              onPressed: () => setState(() => _source = widget.load()),
              child: const Text('Retry'),
            ),
          );
        }
        final uri = snapshot.data;
        if (uri == null) {
          return const Center(child: FiloCircularProgressIndicator());
        }
        final details = FiloFileDetails.fromName(
          widget.name,
          mimeType: widget.mimeType,
        );
        if (!widget.browserOnly && details.type.icon == FiloIcons.pdf) {
          return PdfViewer.uri(uri);
        }
        if (!widget.browserOnly && details.type.icon == FiloIcons.image) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                uri.toString(),
                errorBuilder: (_, _, _) => TextButton(
                  onPressed: () => setState(() => _source = widget.load()),
                  child: const Text('Could not preview this file. Retry'),
                ),
              ),
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(FiloSpacing.screen),
            child: FiloButton(
              label: 'Open in browser',
              onPressed: () => _browser(uri),
            ),
          ),
        );
      },
    ),
  );
}
