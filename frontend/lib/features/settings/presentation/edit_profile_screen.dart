import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/auth_providers.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/presentation/classes_widgets.dart';
import '../../onboarding/application/profile_photo_picker.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../onboarding/domain/profile_photo.dart';
import '../application/profile_settings.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({required this.profile, super.key});
  final AccountProfile profile;
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late AccountProfile _baseline = widget.profile;
  late final _name = TextEditingController(text: _baseline.name);
  late final _school = TextEditingController(text: _baseline.school ?? '');
  ProfilePhotoDraft? _photo;
  AccountProfile? _confirmed;
  bool _busy = false, _picking = false, _allowPop = false, _confirming = false;
  bool _accountLost = false;
  String? _error, _photoError;

  bool get _current =>
      mounted &&
      !_accountLost &&
      ref.read(authUserIdProvider).asData?.value == widget.profile.id;
  bool get _dirty =>
      _photo != null ||
      _name.text.trim() != _baseline.name ||
      _school.text.trim() != (_baseline.school ?? '');
  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _name.text.trim().length <= 80 &&
      _school.text.trim().length <= 120;

  @override
  void initState() {
    super.initState();
    final pending = ref.read(confirmedProfileProvider);
    if (pending?.profile.id == widget.profile.id && pending!.cachePending) {
      _baseline = pending.profile;
      _name.text = _baseline.name;
      _school.text = _baseline.school ?? '';
      _confirmed = pending.profile;
      _photo = pending.photo;
      _error = "Your profile was saved online, but Filo couldn't update its saved copy on this device. Try again.";
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy || _picking || _confirmed != null) return;
    final picker = ref.read(profilePhotoPickerProvider);
    setState(() {
      _picking = true;
      _photoError = null;
    });
    try {
      final photo = await picker();
      if (_current && photo != null) setState(() => _photo = photo);
    } catch (error) {
      if (_current)
        setState(
          () => _photoError = error is FormatException
              ? error.message
              : error is PlatformException &&
                    [
                      'photo_access_denied',
                      'photo_access_restricted',
                    ].contains(error.code)
              ? 'Photo access is blocked. Allow photo access in Android settings, then try again.'
              : 'Could not open this photo. Try choosing another image.',
        );
    } finally {
      if (_current) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _picking || !_current) return;
    if (_confirmed == null &&
        (!_dirty ||
            !_valid ||
            ref.read(connectivityProvider).asData?.value != true))
      return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_confirmed == null) {
        final saved = await ref
            .read(profileRepositoryProvider)
            .edit(
              userId: widget.profile.id,
              name: _name.text,
              school: _school.text,
              photo: _photo,
            );
        if (!_current) return;
        _confirmed = saved;
        ref.read(confirmedProfileProvider.notifier).publish(saved, _photo);
      }
      final cache = await ref.read(profileCacheProvider.future);
      if (!_current) return;
      if (cache == null || cache.userId != widget.profile.id)
        throw StateError('Saved data unavailable');
      await cache.save(_confirmed!);
      if (!_current) return;
      ref.read(confirmedProfileProvider.notifier).cached(_confirmed!);
      setState(() {
        _baseline = _confirmed!;
        _name.text = _baseline.name;
        _school.text = _baseline.school ?? '';
        _photo = null;
        _confirmed = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Changes saved.')));
    } catch (error) {
      if (_current)
        setState(
          () => _error = _confirmed != null
              ? "Your profile was saved online, but Filo couldn't update its saved copy on this device. Try again."
              : error is ProfileEditException && error.uncertain
              ? "We couldn't confirm whether your changes were saved. Check your settings when you're connected."
              : "Couldn't save your changes. Try again.",
        );
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy || _picking || _confirming || !_current) return;
    _confirming = true;
    final leave = await showFiloConfirmation(
      context,
      title: _confirmed == null
          ? 'Discard your changes?'
          : 'Leave profile editing?',
      message: _confirmed == null
          ? 'Your unsaved name, school, and photo changes will be lost.'
          : 'Your profile was saved online, but its saved copy on this device is not updated. Leave this screen?',
      confirmLabel: _confirmed == null ? 'Discard changes' : 'Leave',
      cancelLabel: 'Keep editing',
    );
    _confirming = false;
    if (!leave || !_current) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) Navigator.of(context).pop();
    });
  }

  Widget _locked(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const FiloIcon(FiloIcons.lock, semanticLabel: 'Read only'),
    title: Text(label),
    subtitle: Text(value),
    minVerticalPadding: 12,
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(authUserIdProvider, (_, next) {
      if (next.asData != null && next.asData!.value != widget.profile.id)
        _accountLost = true;
    });
    final account = ref.watch(authUserIdProvider);
    if (_accountLost || account.asData?.value != widget.profile.id) {
      if (!account.isLoading)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              (_accountLost ||
                  ref.read(authUserIdProvider).asData?.value !=
                      widget.profile.id))
            Navigator.of(context).popUntil((route) => route.isFirst);
        });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final locked = _busy || _picking || _confirmed != null;
    final enabled = !locked && _valid && _dirty && online;
    return PopScope(
      canPop:
          _allowPop || (!_dirty && _confirmed == null && !_busy && !_picking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: _photo == null
                      ? FiloAvatar(
                          userId: _baseline.id,
                          name: _baseline.name,
                          url: _baseline.photoUrl,
                          path: _baseline.avatarPath,
                          size: 112,
                        )
                      : ExcludeSemantics(
                          child: ClipOval(
                            child: Image.memory(
                              _photo!.bytes,
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                FiloButton(
                  label: _picking ? 'Preparing photo…' : 'Choose photo',
                  secondary: true,
                  icon: FiloIcons.edit,
                  onPressed: locked ? null : _pick,
                ),
                if (_photoError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_photoError!),
                    ),
                  ),
                const SizedBox(height: 24),
                FiloPanel(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        readOnly: locked,
                        maxLength: 80,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Name'),
                        onChanged: (_) => setState(() {}),
                        validator: (value) => value!.trim().isEmpty
                            ? 'Enter your name.'
                            : value.trim().length > 80
                            ? 'Use 80 characters or fewer.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _school,
                        readOnly: locked,
                        maxLength: 120,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'School (optional)',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) => value!.trim().length > 120
                            ? 'Use 120 characters or fewer.'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FiloPanel(
                  child: Column(
                    children: [
                      _locked('Email', _baseline.email ?? 'Not available'),
                      const Divider(height: 1),
                      _locked('Role', _baseline.role.label),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!online && _confirmed == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      "You're offline. Connect to save your changes.",
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(liveRegion: true, child: Text(_error!)),
                  ),
                FiloButton(
                  label: _busy
                      ? 'Saving…'
                      : _error == null
                      ? 'Save'
                      : 'Retry',
                  busy: _busy,
                  onPressed:
                      !_busy && !_picking && (_confirmed != null || enabled)
                      ? _save
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
