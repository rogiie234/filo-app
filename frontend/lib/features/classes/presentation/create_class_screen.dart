import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_provider.dart';
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

  @override
  void dispose() {
    _course.dispose();
    _section.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || ref.read(connectivityProvider).asData?.value != true) return;
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
      await repository.sync();
      if (mounted) Navigator.pop(context, _created!['id'] as String);
    } catch (error) {
      if (mounted) {
        setState(() {
          _writeUnconfirmed = _created == null && error is! PostgrestException;
          _error = _created != null
              ? 'Your class was created, but we could not load its saved copy. Retry to load it.'
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
    final editable = !_busy && _created == null && !_writeUnconfirmed;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create class'),
          leading: IconButton(
            tooltip: 'Back to classes',
            onPressed: _busy ? null : () => Navigator.pop(context),
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
              Text(
                'Banner color',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Default'),
                    selected: _banner == null,
                    onSelected: editable
                        ? (_) => setState(() => _banner = null)
                        : null,
                  ),
                  for (final entry in classBannerColors.entries)
                    ChoiceChip(
                      label: Text(
                        '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                      ),
                      avatar: CircleAvatar(backgroundColor: Color(entry.value)),
                      selected: _banner == entry.key,
                      onSelected: editable
                          ? (_) => setState(() => _banner = entry.key)
                          : null,
                    ),
                ],
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
                      : 'Retry loading class',
                  icon: _busy ? null : Icons.add_rounded,
                  onPressed: _busy
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
