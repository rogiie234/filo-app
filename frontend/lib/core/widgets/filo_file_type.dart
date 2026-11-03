import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_icon.dart';

enum FiloFileType {
  pdf('PDF', FiloIcons.pdf),
  image('Image', FiloIcons.image),
  doc('DOC', FiloIcons.document),
  ppt('PPT', FiloIcons.slides),
  xls('XLS', FiloIcons.spreadsheet),
  link('Link', FiloIcons.link),
  text('Text', FiloIcons.notes),
  other('File', FiloIcons.document);

  const FiloFileType(this.label, this.icon);
  final String label;
  final IconData icon;

  (Color ink, Color fill) colors(ThemeData theme) {
    final c = theme.colorScheme;
    final t =
        theme.extension<FiloThemeTokens>() ??
        (theme.brightness == Brightness.dark
            ? FiloThemeTokens.dark
            : FiloThemeTokens.light);
    return switch (this) {
      pdf => (c.error, c.errorContainer),
      image => (c.primary, c.primaryContainer),
      doc => (t.info, t.infoTint),
      ppt => (t.warning, t.warningTint),
      xls => (t.success, t.successTint),
      link => (c.onSurfaceVariant, c.surfaceContainerHighest),
      text || other => (c.onSurface, c.surfaceContainerHighest),
    };
  }
}

/// Presentation only; classification does not grant permission to open a file.
class FiloFileDetails {
  const FiloFileDetails(this.type, {this.extension, this.isFile = true});
  final FiloFileType type;
  final String? extension;
  final bool isFile;

  factory FiloFileDetails.fromName(
    String name, {
    String? mimeType,
    String? kind,
  }) {
    if (kind == 'link')
      return const FiloFileDetails(FiloFileType.link, isFile: false);
    if (kind == 'text')
      return const FiloFileDetails(FiloFileType.text, isFile: false);
    final basename = name.replaceAll(r'\', '/').split('/').last;
    final dot = basename.lastIndexOf('.');
    final extension = dot > 0 && dot < basename.length - 1
        ? basename.substring(dot + 1).toLowerCase()
        : null;
    final type = switch (extension) {
      'pdf' => FiloFileType.pdf,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'bmp' ||
      'heic' ||
      'avif' ||
      'svg' => FiloFileType.image,
      'doc' || 'docx' || 'odt' => FiloFileType.doc,
      'ppt' || 'pptx' || 'odp' => FiloFileType.ppt,
      'xls' || 'xlsx' || 'csv' || 'ods' => FiloFileType.xls,
      'txt' || 'md' || 'log' => FiloFileType.text,
      _ => extension == null ? _fromMime(mimeType) : FiloFileType.other,
    };
    return FiloFileDetails(type, extension: extension?.toUpperCase());
  }

  static FiloFileType _fromMime(String? value) {
    final mime = value?.split(';').first.trim().toLowerCase() ?? '';
    if (mime.startsWith('image/')) return FiloFileType.image;
    if (mime == 'application/pdf') return FiloFileType.pdf;
    if (mime == 'application/msword' ||
        mime == 'application/vnd.oasis.opendocument.text' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
      return FiloFileType.doc;
    if (mime == 'application/vnd.ms-powerpoint' ||
        mime == 'application/vnd.oasis.opendocument.presentation' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.presentationml.presentation')
      return FiloFileType.ppt;
    if (mime == 'application/vnd.ms-excel' ||
        mime == 'application/vnd.oasis.opendocument.spreadsheet' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        mime == 'text/csv')
      return FiloFileType.xls;
    if (mime.startsWith('text/')) return FiloFileType.text;
    return FiloFileType.other;
  }

  String get label => !isFile
      ? type.label
      : extension ??
            (type == FiloFileType.other
                ? 'No extension'
                : '${type.label} - No extension');
}

/// Pair with FiloFileTypeLabel beside the tile, outside filename truncation.
class FiloFileTypeTile extends StatelessWidget {
  const FiloFileTypeTile({super.key, required this.details});
  final FiloFileDetails details;
  @override
  Widget build(BuildContext context) {
    final (ink, fill) = details.type.colors(Theme.of(context));
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: FiloIcon(details.type.icon, size: 24, color: ink),
      ),
    );
  }
}

class FiloFileTypeLabel extends StatelessWidget {
  const FiloFileTypeLabel({super.key, required this.details});
  final FiloFileDetails details;
  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    // Source ActionChips may truncate filenames, never the type label.
    style: (Theme.of(context).textTheme.labelMedium ?? const TextStyle())
        .copyWith(color: Theme.of(context).colorScheme.onSurface),
    softWrap: true,
    overflow: TextOverflow.visible,
    child: Text(details.label),
  );
}
