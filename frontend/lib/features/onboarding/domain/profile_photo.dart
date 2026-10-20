import 'dart:typed_data';

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
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return ProfilePhotoDraft._(bytes, 'jpg', 'image/jpeg');
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((match) => match)) {
      return ProfilePhotoDraft._(bytes, 'png', 'image/png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ProfilePhotoDraft._(bytes, 'webp', 'image/webp');
    }
    throw const FormatException('Choose a JPG, PNG, or WebP profile photo.');
  }
}

/// Account creation succeeded; photo completion is still safe to retry.
class ProfilePhotoSaveException implements Exception {
  const ProfilePhotoSaveException();
}
