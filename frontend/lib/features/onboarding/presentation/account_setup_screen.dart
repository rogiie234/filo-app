import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../home/presentation/home_screen.dart';
import '../application/notification_permission.dart';
import '../data/profile_repository.dart';

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
  String? _error;
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
      final profile = await ref.read(profileRepositoryProvider).fetch();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Continue as ${role.label}?'),
        content: Text(
          'Your account will use the ${role.label} role. You cannot change your role after your profile is created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm role'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) setState(() => _stage = 'details');
  }

  Future<void> _save() async {
    if (_busy || !_valid) return;
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
          );
      if (mounted) await _afterSave(profile);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'We couldn’t finish setting up your account. Please try again.',
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
    builder: (context) => AlertDialog(
      title: const Text('Privacy Notice'),
      content: const SingleChildScrollView(
        child: Text(
          'Filo collects your name, email address, profile photo, school, and selected role to set up your account. It stores your class activity, including submissions, grades, and counts of leaving the app during exams, to provide learning and assessment features. Filo also records device and login verification information to protect account access.\n\n'
          'When you use AI features, Filo sends your requests and the text needed for those features, including text from learning materials you select, to Google for processing with Gemini. Avoid including passwords or sensitive personal information in AI requests.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_stage == 'home') return HomeScreen(profile: _profile!);
    final user = ref.watch(onboardingUserProvider);
    final photo =
        user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Set up your account',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await ref.read(supabaseClientProvider).auth.signOut();
                    },
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  if (_stage == 'loading')
                    const Center(child: CircularProgressIndicator()),
                  if (_stage == 'lookupError') ...[
                    Text(_error!),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                  if (_stage == 'role') ...[
                    Text(
                      'Choose your role',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose carefully. You cannot change your role later.',
                    ),
                    const SizedBox(height: 16),
                    for (final role in AccountRole.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _role = role),
                          child: Row(
                            children: [
                              Icon(
                                _role == role
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(role.label)),
                            ],
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: _role == null ? null : _confirmRole,
                      child: const Text('Continue'),
                    ),
                  ],
                  if (_stage == 'details') ...[
                    Text(
                      'Your details',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ClipOval(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: photo is String
                              ? Image.network(
                                  photo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const Icon(Icons.person, size: 64),
                                )
                              : const Icon(Icons.person, size: 64),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Name'),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: _school,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'School (optional)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Email'),
                      subtitle: Text(user.email ?? ''),
                      trailing: const Icon(Icons.lock_outline),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Role'),
                      subtitle: Text(_role!.label),
                      trailing: const Icon(Icons.lock_outline),
                    ),
                    TextButton(
                      onPressed: _privacy,
                      child: const Text('Read Privacy Notice'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consent,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _consent = value ?? false),
                      title: const Text(
                        'I have read and agree to the Privacy Notice. I understand that using AI features sends my requests and relevant text to Google for processing.',
                      ),
                    ),
                    if (_error != null)
                      Semantics(liveRegion: true, child: Text(_error!)),
                    FilledButton(
                      onPressed: _valid && !_busy ? _save : null,
                      child: Text(
                        _busy
                            ? 'Creating account…'
                            : _error != null
                            ? 'Retry'
                            : 'Create account',
                      ),
                    ),
                  ],
                  if (_stage == 'notifications') ...[
                    Text(
                      'Stay up to date',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enable notifications for class updates, deadlines, and grades. You can change notification access in Android settings.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _finishNotifications(true),
                      child: Text(
                        _busy ? 'Continuing…' : 'Enable notifications',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _finishNotifications(false),
                      child: const Text('Not now'),
                    ),
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
