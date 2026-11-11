import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/picked_image_file.dart';

Future<void> pickClassBanner(
  void Function(Uint8List bytes, String extension) onPicked, {
  ImagePicker? picker,
}) async {
  final image = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 900,
    imageQuality: 85,
    requestFullMetadata: false,
  );
  if (image == null) return;
  await usePickedImage(image, () async {
    final extension = image.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      throw const FormatException('Choose a JPG, PNG, or WebP image.');
    }
    if (await image.length() > 2097152) {
      throw const FormatException('Choose a banner image smaller than 2 MB.');
    }
    final bytes = await image.readAsBytes();
    // Apply the selection before temporary cleanup, as both screens did before.
    onPicked(bytes, extension);
  });
}
