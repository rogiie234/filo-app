import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:uuid/uuid.dart';

/// A local preview with a stable storage identity, reused across save retries.
class ProfilePhotoDraft {
  ProfilePhotoDraft._(this.bytes, this.extension, this.contentType)
    : id = const Uuid().v4();

  static const maxBytes = 524288;
  final Uint8List bytes;
  final String extension;
  final String contentType;
  final String id;

  factory ProfilePhotoDraft.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Choose a profile photo smaller than 512 KB.',
      );
    }
    final (extension, contentType) = _format(bytes);
    return ProfilePhotoDraft._(bytes, extension, contentType);
  }

  static (String, String) _format(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return ('jpg', 'image/jpeg');
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((match) => match)) {
      return ('png', 'image/png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ('webp', 'image/webp');
    }
    throw const FormatException('Choose a JPG, PNG, or WebP profile photo.');
  }

  static Future<ProfilePhotoDraft> compress(Uint8List bytes) async {
    _format(bytes);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        for (final edge in [512, 384, 256]) {
          final width = descriptor.width;
          final height = descriptor.height;
          final longest = width > height ? width : height;
          final scale = longest > edge ? edge / longest : 1.0;
          final codec = await descriptor.instantiateCodec(
            targetWidth: (width * scale).round().clamp(1, edge).toInt(),
            targetHeight: (height * scale).round().clamp(1, edge).toInt(),
          );
          try {
            final frame = await codec.getNextFrame();
            try {
              if (bytes.length <= maxBytes && longest <= 512) {
                return ProfilePhotoDraft.fromBytes(bytes);
              }
              final encoded = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (encoded != null && encoded.lengthInBytes <= maxBytes) {
                return ProfilePhotoDraft.fromBytes(
                  encoded.buffer.asUint8List(
                    encoded.offsetInBytes,
                    encoded.lengthInBytes,
                  ),
                );
              }
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
    throw const FormatException(
      'Could not make this photo small enough. Try another image.',
    );
  }
}

/// Account creation succeeded; photo completion is still safe to retry.
class ProfilePhotoSaveException implements Exception {
  const ProfilePhotoSaveException();
}
