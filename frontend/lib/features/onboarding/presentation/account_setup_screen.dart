import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../data/local/database_providers.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../auth/presentation/session_loading_view.dart';
import 'role_selection_view.dart';
import 'account_details_view.dart';
import 'notification_prompt_view.dart';
import '../../home/presentation/home_screen.dart';
import '../application/notification_permission.dart';
import '../data/profile_repository.dart';
import '../domain/profile_photo.dart';

class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});
  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  final _name = TextEditingController();
  final _school = TextEditingController();
  AccountRole? _role;
  AccountProfile? _profile;
  String _stage = 'loading';
  String? _error, _photoError;
  ProfilePhotoDraft? _photo;
  bool _pickingPhoto = false, _useGooglePhoto = false;
  bool _consent = false, _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(onboardingUserProvider);
    _name.text =
        (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '')
            as String;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _stage = 'loading';
      _error = null;
    });
    try {
      final online = await ref.read(connectivityProvider.future);
      AccountProfile? profile;
      if (online) {
        profile = await ref
            .read(profileRepositoryProvider)
            .fetch()
            .timeout(const Duration(seconds: 20));
      } else {
        final db = await ref.read(accountDatabaseProvider.future);
        final user = ref.read(supabaseClientProvider).auth.currentUser;
        final cached = user == null ? null : await db?.readProfile(user.id);
        if (cached == null) throw StateError('No offline profile');
        profile = AccountProfile.fromJson({
          'id': cached.id,
          'role': cached.role,
          'display_name': cached.displayName,
          'email': cached.email,
          'school': cached.school,
          'google_photo_url': cached.googlePhotoUrl,
          'avatar_path': cached.avatarPath,
        });
      }
      if (!mounted) return;
      if (profile == null) {
        setState(() => _stage = 'role');
        GoRouter.maybeOf(context)?.go('/onboarding');
      } else {
        await _afterSave(profile);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = 'lookupError';
          _error = 'Could not load your profile. Please try again.';
        });
      }
    }
  }

  Future<void> _afterSave(AccountProfile profile) async {
    _profile = profile;
    // If local storage fails, let the user handle the prompt again.
    var handled = false;
    try {
      handled = await ref
          .read(notificationPermissionProvider)
          .handled(profile.id);
    } catch (_) {
      /* Retry through prompt. */
    }
    if (mounted) {
      setState(() {
        _stage = handled ? 'home' : 'notifications';
        _error = null;
      });
      GoRouter.maybeOf(context)?.go(handled ? '/home' : '/onboarding');
    }
  }

  Future<void> _confirmRole() async {
    final role = _role;
    if (role == null) return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Continue as ${role.label}?',
      message:
          'Your account will use the ${role.label} role. You cannot change your role after your profile is created.',
      confirmLabel: 'Confirm role',
      icon: role == AccountRole.student ? FiloIcons.student : FiloIcons.book,
    );
    if (confirmed == true && mounted) setState(() => _stage = 'details');
  }

  Future<void> _pickPhoto() async {
    if (_busy || _pickingPhoto) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pickingPhoto = true;
      _photoError = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (image == null) return;
      if (await image.length() > ProfilePhotoDraft.maxBytes) {
        throw const FormatException(
          'Choose a profile photo smaller than 512 KB.',
        );
      }
      final draft = ProfilePhotoDraft.fromBytes(await image.readAsBytes());
      // Reject unreadable image data before replacing the existing preview.
      final codec = await ui.instantiateImageCodec(
        draft.bytes,
        targetWidth: 256,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (mounted) {
        setState(() {
          _photo = draft;
          _useGooglePhoto = false;
        });
      }
    } catch (error) {
      if (mounted) {
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
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _pickingPhoto || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .create(
            role: _role!,
            name: _name.text,
            school: _school.text,
            consent: _consent,
            photo: _photo,
            useGooglePhoto: _useGooglePhoto,
          );
      if (mounted) await _afterSave(profile);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ProfilePhotoSaveException
              ? 'Your account was created, but we couldn\u2019t save your photo. Retry, or use your Google photo to continue.'
              : 'We couldn\u2019t finish setting up your account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _valid =>
      _consent &&
      _name.text.trim().isNotEmpty &&
      _name.text.trim().length <= 80 &&
      _school.text.trim().length <= 120;

  Future<void> _finishNotifications(bool enable) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (enable) {
      try {
        await ref.read(notificationPermissionProvider).request();
      } catch (_) {
        /* Permission must never block Home. */
      }
    }
    try {
      await ref.read(notificationPermissionProvider).markHandled(_profile!.id);
    } catch (_) {
      /* Home remains available if storage fails. */
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _stage = 'home';
      });
      GoRouter.maybeOf(context)?.go('/home');
    }
  }

  void _privacy() => showDialog<void>(
    context: context,
    builder: (context) => const FiloNoticeDialog(
      title: 'Privacy Notice',
      sections: [
        FiloNoticeSection(
          heading: 'Your information',
          body: 'Filo collects your name, email address, profile photo, school, and selected role to set up your account. It stores your class activity, including submissions, grades, and counts of leaving the app during exams, to provide learning and assessment features. Filo also records device and login verification information to protect account access.',
        ),
        FiloNoticeSection(
          heading: 'AI processing',
          body: 'When you use AI features, Filo sends your requests and the text needed for those features, including text from learning materials you select, to Google for processing with Gemini. Avoid including passwords or sensitive personal information in AI requests.',
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_stage == 'home') return HomeScreen(profile: _profile!);
    if (_stage == 'loading') {
      return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(title: const Brand(), toolbarHeight: 76),
          body: const SessionLoadingView(
            statusText: 'Getting your account ready.',
          ),
        ),
      );
    }
    if (_stage == 'role') {
      return RoleSelectionView(
        selectedRole: _role,
        onSelected: (role) => setState(() => _role = role),
        onContinue: _confirmRole,
      );
    }
    if (_stage == 'notifications') {
      return NotificationPromptView(
        busy: _busy,
        onEnable: () => _finishNotifications(true),
        onSkip: () => _finishNotifications(false),
      );
    }
    final user = ref.watch(onboardingUserProvider);
    final photo =
        user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
    if (_stage == 'details') {
      return AccountDetailsView(
        name: _name,
        school: _school,
        email: user.email ?? '',
        role: _role!.label,
        photoUrl: photo is String ? photo : null,
        photoBytes: _photo?.bytes,
        photoBusy: _pickingPhoto,
        photoError: _photoError,
        onChangePhoto: _pickPhoto,
        onResetPhoto: () {
          if (_busy || _pickingPhoto) return;
          setState(() {
            _photo = null;
            _useGooglePhoto = true;
            _photoError = null;
          });
        },
        consent: _consent,
        valid: _valid && !_pickingPhoto,
        busy: _busy,
        error: _error,
        onEdited: () => setState(() {}),
        onConsentChanged: (value) => setState(() => _consent = value),
        onPrivacy: _privacy,
        onSave: _save,
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: _stage == 'role'
                ? Alignment.topCenter
                : Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  if (_stage == 'lookupError') ...[
                    Text(_error!),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
