import '../../../core/picked_image_file.dart';

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
import 'class_banner.dart';
import 'classes_widgets.dart' show classImageProvider;

class ClassBannerScreen extends ConsumerStatefulWidget {
  const ClassBannerScreen({
    super.key,
    required this.classId,
    this.embedded = false,
  });
  final bool embedded;
  final String classId;
  @override
  ConsumerState<ClassBannerScreen> createState() => _ClassBannerState();
}

class _ClassBannerState extends ConsumerState<ClassBannerScreen> {
  String? _banner, _error, _imageExtension, _uploadPath;
  Uint8List? _bannerImage;
  bool _busy = false, _picking = false, _changed = false;
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
      await usePickedImage(image, () async {
        final extension = image.name.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
          throw const FormatException('Choose a JPG, PNG, or WebP image.');
        }
        if (await image.length() > 2097152) {
          throw const FormatException(
            'Choose a banner image smaller than 2 MB.',
          );
        }
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _uploadPath = null;
          _bannerImage = bytes;
          _changed = true;
          _imageExtension = extension;
          _error = null;
        });
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
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
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
      if (mounted) {
        setState(
          () => _error = 'Could not confirm the banner change. Your selection is kept. Refresh the class before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final editable = !_busy && !_picking && online;
    final rooms = ref.watch(classCardsProvider).asData?.value;
    final room = rooms?.where((r) => r.id == widget.classId).firstOrNull;
    final selectedBanner = _changed
        ? _banner
        : classBannerColors.entries
              .where((entry) => entry.value == room?.color)
              .firstOrNull
              ?.key;
    final originalPath = !_changed ? room?.bannerPath : null;
    final originalUrl = originalPath == null || originalPath.isEmpty
        ? null
        : ref
              .watch(classImageProvider(('banners', originalPath)))
              .asData
              ?.value;
    final hasPhoto = _bannerImage != null || originalPath != null;
    final content = ListView(
      padding: const EdgeInsets.all(FiloSpacing.screen),
      children: [
        Text(
          'Class card preview',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: FiloSpacing.s12),
        ClipRRect(
          borderRadius: BorderRadius.circular(FiloRadii.large),
          child: ClassBanner(
            section: room?.section ?? 'Your classroom',
            instructor: room?.instructor ?? 'Instructor',
            compact: true,
            color: _changed
                ? classBannerColor(_banner)
                : room?.color ?? classBannerColor(null),
            image: _bannerImage != null
                ? MemoryImage(_bannerImage!)
                : originalUrl == null
                ? null
                : NetworkImage(originalUrl),
          ),
        ),
        if (room != null)
          Padding(
            padding: const EdgeInsets.all(FiloSpacing.s12),
            child: Text(room.course),
          ),
        const SizedBox(height: FiloSpacing.s20),
        Text('Banner color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FiloSpacing.s8),
        const Text('Choose a color or upload a new banner.'),
        const SizedBox(height: FiloSpacing.s12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in <String?>[null, ...classBannerColors.keys])
                SizedBox(
                  width: (constraints.maxWidth - 16) / 3,
                  child: Semantics(
                    selected: selectedBanner == key && !hasPhoto,
                    inMutuallyExclusiveGroup: true,
                    child: OutlinedButton(
                      onPressed: editable
                          ? () => setState(() {
                              _banner = key;
                              _bannerImage = null;
                              _changed = true;
                            })
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 88),
                        padding: const EdgeInsets.all(8),
                        backgroundColor: selectedBanner == key && !hasPhoto
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surface,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(classBannerColor(key)),
                            child: selectedBanner == key && !hasPhoto
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: ClassBanner.foreground(
                                      classBannerColor(key),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            key == null
                                ? 'Default'
                                : '${key[0].toUpperCase()}${key.substring(1)}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FiloSpacing.s16),
        FiloButton(
          outlined: true,
          minHeight: 48,
          label: _picking ? 'Opening photos\u2026' : 'Upload banner image',
          leading: const FiloIcon(FiloIcons.addImage),
          onPressed: editable ? _pickBanner : null,
        ),
        const SizedBox(height: FiloSpacing.s8),
        Text(
          'JPG, PNG or WebP \u00b7 Max 2 MB',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: FiloSpacing.s20),
        if (_error != null)
          Semantics(liveRegion: true, child: FiloPanel(child: Text(_error!))),
        if (!online)
          const Text('Connect to the internet to change the banner.'),
        FiloButton(
          label: _busy ? 'Saving...' : 'Save banner',
          busy: _busy,
          minHeight: 64,
          onPressed: editable && _changed ? _save : null,
        ),
      ],
    );
    return PopScope(
      canPop: !_busy && !_picking,
      child: widget.embedded
          ? content
          : Scaffold(
              appBar: AppBar(title: const Text('Change banner')),
              body: content,
            ),
    );
  }
}
