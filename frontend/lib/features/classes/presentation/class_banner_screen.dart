import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/class_providers.dart';
import '../domain/class_banner.dart';

class ClassBannerScreen extends ConsumerStatefulWidget {
  const ClassBannerScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<ClassBannerScreen> createState() => _ClassBannerState();
}

class _ClassBannerState extends ConsumerState<ClassBannerScreen> {
  String? _banner, _error, _imageExtension, _uploadPath;
  Uint8List? _bannerImage;
  bool _busy = false, _picking = false;
  Future<void> _pickBanner() async {
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final extension = image.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw const FormatException('Choose a JPG, PNG, or WebP image.');
      }
      if (await image.length() > 2097152) {
        throw const FormatException('Choose a banner image smaller than 2 MB.');
      }
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _uploadPath = null;
        _bannerImage = bytes;
        _imageExtension = extension;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not open this image. Try choosing another banner.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy ||
        _picking ||
        ref.read(connectivityProvider).asData?.value != true)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      String? path;
      if (_bannerImage != null) {
        _uploadPath ??=
            '${widget.classId}/banner-${DateTime.now().microsecondsSinceEpoch}.$_imageExtension';
        path = _uploadPath;
        await client.storage
            .from('banners')
            .uploadBinary(
              path!,
              _bannerImage!,
              fileOptions: FileOptions(
                upsert: true,
                contentType:
                    'image/${_imageExtension == 'jpg' ? 'jpeg' : _imageExtension}',
              ),
            );
      }
      // Select the updated row so a denied/no-longer-owned update cannot look successful.
      await client
          .from('classes')
          .update({
            'banner_path': path,
            'banner_color': path == null ? _banner : null,
          })
          .eq('id', widget.classId)
          .isFilter('deleted_at', null)
          .select('id')
          .single();
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      await repository.sync();
      if (mounted) {
        showMessage(context, 'Banner updated.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not confirm the banner change. Your selection is kept. Refresh the class before retrying.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final editable = !_busy && !_picking && online;
    return PopScope(
      canPop: !_busy && !_picking,
      child: Scaffold(
        appBar: AppBar(title: const Text('Change banner')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Choose a color or upload a new banner.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Default'),
                  selected: _banner == null && _bannerImage == null,
                  onSelected: editable
                      ? (_) => setState(() {
                          _banner = null;
                          _bannerImage = null;
                        })
                      : null,
                ),
                for (final entry in classBannerColors.entries)
                  ChoiceChip(
                    label: Text(
                      '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                    ),
                    avatar: CircleAvatar(backgroundColor: Color(entry.value)),
                    selected: _banner == entry.key && _bannerImage == null,
                    onSelected: editable
                        ? (_) => setState(() {
                            _banner = entry.key;
                            _bannerImage = null;
                          })
                        : null,
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: editable ? _pickBanner : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_picking ? 'Opening photos…' : 'Upload banner image'),
            ),
            const Text('JPG, PNG, or WebP · up to 2 MB'),
            if (_bannerImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _bannerImage!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 150,
                      child: Center(child: Text('Image preview unavailable')),
                    ),
                  ),
                ),
              ),

            if (_error != null) Text(_error!),
            if (!online)
              const Text('Connect to the internet to change the banner.'),
            FiloButton(
              label: _busy ? 'Saving...' : 'Save banner',
              onPressed: editable ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
