import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/profile_photo.dart';

final profilePhotoPickerProvider =
    Provider<Future<ProfilePhotoDraft?> Function()>(
      (ref) => () async {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        return image == null
            ? null
            : await ProfilePhotoDraft.compress(await image.readAsBytes());
      },
    );
