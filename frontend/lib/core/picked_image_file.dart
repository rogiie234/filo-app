import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<T> usePickedImage<T>(
  XFile image,
  Future<T> Function() read, {
  Future<Directory> Function() directoryProvider = getTemporaryDirectory,
}) async {
  try {
    return await read();
  } finally {
    final file = File(image.path);
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.file) {
      final temporary = await directoryProvider();
      if (p.isWithin(
        await temporary.resolveSymbolicLinks(),
        await file.resolveSymbolicLinks(),
      )) {
        await file.delete();
      }
    }
  }
}
