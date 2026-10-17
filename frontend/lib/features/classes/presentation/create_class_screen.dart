import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/class_providers.dart';
import '../data/class_remote.dart';
import '../domain/class_banner.dart';

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
    if (_created == null && !_form.currentState!.validate()) return;
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
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'A new place to grow.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _course,
                enabled: editable,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Course'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a course.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _section,
                enabled: editable,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Section'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a section.' : null,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Text('Banner', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
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
                label: Text(
                  _picking ? 'Opening photos…' : 'Upload banner image',
                ),
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
              const SizedBox(height: 16),
              FiloPanel(
                color: Color(classBannerColor(_banner)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your classroom',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A permanent join code is generated when you create the class.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: FiloColors.secondary),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!online)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
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
                  icon: _busy ? null : Icons.add_rounded,
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
