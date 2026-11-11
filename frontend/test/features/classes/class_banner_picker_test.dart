import 'dart:typed_data';

import 'package:filo/features/classes/application/class_banner_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _Picker extends ImagePicker {
  _Picker(this.image);
  final XFile? image;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    expect(maxWidth, 1600);
    expect(maxHeight, 900);
    expect(imageQuality, 85);
    expect(requestFullMetadata, false);
    return image;
  }
}

class _Image extends XFile {
  _Image(this.name, {this.size = 1, this.readError}) : super('');
  @override
  final String name;
  final int size;
  final Object? readError;
  final bytes = Uint8List.fromList([1, 2, 3]);

  @override
  Future<int> length() async => size;

  @override
  Future<Uint8List> readAsBytes() async {
    if (readError != null) throw readError!;
    return bytes;
  }
}

void main() {
  test('cancel keeps the current selection untouched', () async {
    await pickClassBanner(
      (_, _) => fail('Cancelled picker must not apply a selection.'),
      picker: _Picker(null),
    );
  });

  test(
    'supported extensions accept exactly 2 MiB and preserve bytes',
    () async {
      for (final extension in ['JPG', 'jpeg', 'png', 'webp']) {
        final image = _Image('banner.$extension', size: 2097152);
        var calls = 0;
        await pickClassBanner((bytes, selectedExtension) {
          calls++;
          expect(bytes, same(image.bytes));
          expect(selectedExtension, extension.toLowerCase());
        }, picker: _Picker(image));
        expect(calls, 1);
      }
    },
  );

  test('unsupported format retains the original validation message', () async {
    await expectLater(
      pickClassBanner(
        (_, _) => fail('Invalid image must not replace the selection.'),
        picker: _Picker(_Image('banner.gif')),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Choose a JPG, PNG, or WebP image.',
        ),
      ),
    );
  });

  test('one byte above 2 MiB retains the original size message', () async {
    await expectLater(
      pickClassBanner(
        (_, _) => fail('Oversized image must not replace the selection.'),
        picker: _Picker(_Image('banner.png', size: 2097153)),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Choose a banner image smaller than 2 MB.',
        ),
      ),
    );
  });

  test('read failure propagates without applying a selection', () async {
    final error = StateError('Read failed');
    await expectLater(
      pickClassBanner(
        (_, _) => fail('Unreadable image must not replace the selection.'),
        picker: _Picker(_Image('banner.png', readError: error)),
      ),
      throwsA(same(error)),
    );
  });
}
