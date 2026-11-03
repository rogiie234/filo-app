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
import '../data/class_remote.dart';
import '../domain/class_banner.dart';
import 'class_banner.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});
  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _form = GlobalKey<FormState>();
  final _course = TextEditingController();
  final _section = TextEditingController();
  final _year = TextEditingController();
  String? _banner, _error;
  bool _busy = false;
  bool _writeUnconfirmed = false;
  ClassRow? _created;
  Uint8List? _bannerImage;
  String? _imageExtension;
  String? _uploadPath;
  bool _picking = false;
  bool _bannerSaved = false;

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
          _bannerImage = bytes;
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

  @override
  void dispose() {
    _course.dispose();
    _section.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy ||
        _picking ||
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
    if (_created == null && !validateFiloForm(_form)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      _created ??= await repository.createClass(
        course: _course.text,
        section: _section.text,
        schoolYear: _year.text,
        bannerColor: _banner,
      );
      // Storage requires an existing owned class. Retain its ID across retries
      // so an upload or cache failure never creates a second class.
      if (_bannerImage != null && !_bannerSaved) {
        final client = ref.read(supabaseClientProvider);
        final id = _created!['id'] as String;
        _uploadPath ??=
            '$id/banner-${DateTime.now().microsecondsSinceEpoch}.$_imageExtension';
        await client.storage
            .from('banners')
            .uploadBinary(
              _uploadPath!,
              _bannerImage!,
              fileOptions: FileOptions(
                upsert: true,
                contentType:
                    'image/${_imageExtension == 'jpg' ? 'jpeg' : _imageExtension}',
              ),
            );
        await client
            .from('classes')
            .update({'banner_path': _uploadPath, 'banner_color': null})
            .eq('id', id);
        _bannerSaved = true;
      }
      await repository.sync();
      if (mounted) Navigator.pop(context, _created!['id'] as String);
    } catch (error) {
      if (mounted) {
        setState(() {
          _writeUnconfirmed = _created == null && error is! PostgrestException;
          _error = _created != null
              ? _bannerImage != null && !_bannerSaved
                    ? 'Your class was created, but its banner could not be saved. Retry to finish, or go back to your classes.'
                    : 'Your class was created, but we could not load its saved copy. Retry to load it.'
              : _writeUnconfirmed
              ? 'We could not confirm whether your class was created. Go back and refresh your classes before trying again.'
              : 'Could not create your class. Check your details and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final editable =
        !_busy && !_picking && _created == null && !_writeUnconfirmed;
    return PopScope(
      canPop: !_busy && !_picking,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create class'),
          leading: IconButton(
            tooltip: 'Back to classes',
            onPressed: _busy || _picking ? null : () => Navigator.pop(context),
            icon: const FiloIcon(FiloIcons.back),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(FiloSpacing.screen),
            children: [
              Text(
                'A new place to grow.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: FiloSpacing.screen),
              TextFormField(
                controller: _course,
                enabled: editable,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Course'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a course.' : null,
              ),
              const SizedBox(height: FiloSpacing.s16),
              TextFormField(
                controller: _section,
                enabled: editable,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Section'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a section.' : null,
              ),
              const SizedBox(height: FiloSpacing.s16),
              TextFormField(
                controller: _year,
                enabled: editable,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'School Year',
                  hintText: '2026–2027',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter a school year.'
                    : null,
              ),
              const SizedBox(height: FiloSpacing.screen),
              Text('Banner', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: FiloSpacing.s12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FiloAnimatedChip(
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
                    FiloAnimatedChip(
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
                icon: const FiloIcon(FiloIcons.addImage),
                label: Text(
                  _picking ? 'Opening photos…' : 'Upload banner image',
                ),
              ),
              const Text('JPG, PNG, or WebP · up to 2 MB'),
              const SizedBox(height: FiloSpacing.s16),
              ClipRRect(
                borderRadius: BorderRadius.circular(FiloRadii.large),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _section,
                  builder: (context, value, _) => ClassBanner(
                    section: value.text.trim().isEmpty
                        ? 'Your classroom'
                        : value.text.trim(),
                    instructor: 'Instructor',
                    color: classBannerColor(_banner),
                    image: _bannerImage == null
                        ? null
                        : MemoryImage(_bannerImage!),
                  ),
                ),
              ),
              const SizedBox(height: FiloSpacing.s8),
              const Text(
                'A permanent join code is generated when you create the class.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: FiloSpacing.s16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FiloSpacing.screen,
              FiloSpacing.s12,
              FiloSpacing.screen,
              FiloSpacing.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!online)
                  const Padding(
                    padding: EdgeInsets.only(bottom: FiloSpacing.s8),
                    child: Text('Connect to the internet to create a class.'),
                  ),
                FiloButton(
                  label: _busy
                      ? 'Creating…'
                      : _writeUnconfirmed
                      ? 'Back to classes'
                      : _created == null
                      ? 'Create class'
                      : _bannerImage != null && !_bannerSaved
                      ? 'Retry saving banner'
                      : 'Retry loading class',
                  icon: _busy ? null : FiloIcons.add,
                  onPressed: _busy || _picking
                      ? null
                      : _writeUnconfirmed
                      ? () => Navigator.pop(context)
                      : !online
                      ? null
                      : _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
