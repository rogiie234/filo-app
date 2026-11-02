import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/push_providers.dart';
import '../../../core/sync/background_sync.dart';
import '../../../core/supabase/auth_providers.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/presentation/classes_widgets.dart';
import '../../drive_backup/presentation/drive_backup_screen.dart';
import '../../notifications/presentation/notification_settings_screen.dart';
import '../../onboarding/data/profile_repository.dart';
import '../application/theme_settings.dart';
import '../application/profile_settings.dart';
import 'edit_profile_screen.dart';
import 'storage_screen.dart';
import 'privacy_notice_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({required this.profile, super.key});
  final AccountProfile profile;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false, _confirmingSignOut = false;
  String? _signOutError;

  Future<void> _signOut() async {
    if (_signingOut || _confirmingSignOut) return;
    final service = ref.read(pushRegistrationProvider);
    final current = service.sessionGuard();
    _confirmingSignOut = true;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Sign out?',
      message: 'Your local files will stay on this device. They will be available only to this account when you sign in again.',
      confirmLabel: 'Sign out',
      cancelLabel: 'Cancel',
      cancelIsPrimary: true,
      icon: FiloIcons.logout,
    );
    _confirmingSignOut = false;
    if (!confirmed || !mounted || _signingOut || !current()) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      try {
        await stopBackgroundSync(isCurrent: current);
      } catch (_) {
        // Sign-out must remain available when background cleanup fails.
      }
      if (!mounted || !current()) return;
      await service.leave();
      if (mounted && service.account() == null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted && current())
        setState(() => _signOutError = "Couldn't sign out. Try again.");
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Widget _entry(
    String title,
    IconData icon, {
    String? subtitle,
    VoidCallback? onTap,
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      enabled: onTap != null && !_signingOut,
      minVerticalPadding: 16,
      leading: FiloIcon(
        icon,
        color: destructive ? colors.error : colors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(color: destructive ? colors.error : colors.onSurface),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: onTap == null ? null : const FiloIcon(FiloIcons.chevronRight),
      onTap: _signingOut ? null : onTap,
    );
  }

  Widget _group(List<Widget> entries) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: FiloPanel(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i != 0) const Divider(height: 1, indent: 16, endIndent: 16),
            entries[i],
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final profile =
        ref.watch(accountProfileProvider(widget.profile.id)) ?? widget.profile;
    final account = ref.watch(authUserIdProvider);
    if (account.asData?.value != profile.id) {
      if (!account.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(authUserIdProvider).asData?.value != profile.id) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final appearance = ref.watch(themeSettingsProvider);
    final mode = appearance.asData?.value;
    return PopScope(
      canPop: !_signingOut,
      child: Scaffold(
        appBar: AppBar(title: const Text('Profile and settings')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              FiloPanel(
                child: Column(
                  children: [
                    FiloAvatar(
                      userId: profile.id,
                      name: profile.name,
                      url: profile.photoUrl,
                      path: profile.avatarPath,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (profile.school?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(profile.school!, textAlign: TextAlign.center),
                    ],
                    if (profile.email != null) ...[
                      const SizedBox(height: 8),
                      Text(profile.email!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      profile.role.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _group([
                _entry(
                  'Edit profile',
                  FiloIcons.person,
                  onTap: () => _open(EditProfileScreen(profile: profile)),
                ),
                _entry(
                  'Theme',
                  FiloIcons.settings,
                  subtitle: appearance.isLoading
                      ? 'Loading…'
                      : mode == null
                      ? 'Could not load your theme setting.'
                      : themeLabel(mode),
                  onTap: () => _open(ThemeSettingsScreen(userId: profile.id)),
                ),
                _entry(
                  'Notification settings',
                  FiloIcons.notifications,
                  onTap: () => _open(const NotificationSettingsScreen()),
                ),
              ]),
              _group([
                _entry(
                  'Drive backup',
                  FiloIcons.cloudUpload,
                  onTap: () => _open(const DriveBackupScreen()),
                ),
                _entry(
                  'Storage',
                  FiloIcons.folder,
                  onTap: () => _open(StorageScreen(userId: profile.id)),
                ),
                _entry(
                  'Privacy notice',
                  FiloIcons.shield,
                  onTap: () => _open(const PrivacyNoticeScreen()),
                ),
              ]),
              _group([
                _entry(
                  _signingOut ? 'Signing out…' : 'Sign out',
                  FiloIcons.logout,
                  onTap: _signingOut ? null : _signOut,
                ),
                if (_signOutError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_signOutError!, semanticsLabel: _signOutError),
                        TextButton(
                          onPressed: _signingOut ? null : _signOut,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                _entry(
                  'Delete account',
                  FiloIcons.delete,
                  destructive: true,
                  subtitle: 'Account deletion is not available here yet.',
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({required this.userId, super.key});
  final String userId;
  @override
  ConsumerState<ThemeSettingsScreen> createState() =>
      _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  bool _saving = false;
  ThemeMode? _failed;

  Future<void> _choose(ThemeMode mode) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = null;
    });
    final saved = await ref.read(themeSettingsProvider.notifier).choose(mode);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = saved ? null : mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authUserIdProvider);
    if (account.asData?.value != widget.userId) {
      if (!account.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              ref.read(authUserIdProvider).asData?.value != widget.userId) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final appearance = ref.watch(themeSettingsProvider);
    final selected = appearance.asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Choose how Filo looks on this device. System follows your phone’s appearance.',
            ),
            const SizedBox(height: 24),
            if (appearance.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (appearance.hasError) ...[
              const Text('Could not load your theme setting.'),
              TextButton(
                onPressed: () {
                  ref.invalidate(themeSettingsRepositoryProvider);
                  ref.invalidate(themeSettingsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
            FiloPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    Semantics(
                      selected: selected == mode,
                      child: ListTile(
                        minVerticalPadding: 16,
                        title: Text(themeLabel(mode)),
                        trailing: FiloIcon(
                          selected == mode
                              ? FiloIcons.checkCircle
                              : FiloIcons.circle,
                        ),
                        enabled:
                            !_saving &&
                            !appearance.isLoading &&
                            !appearance.hasError &&
                            selected != null,
                        onTap: () => _choose(mode),
                      ),
                    ),
                ],
              ),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Saving…', textAlign: TextAlign.center),
              ),
            if (_failed != null) ...[
              const SizedBox(height: 20),
              const Text(
                "Couldn't save your changes. Try again.",
                semanticsLabel: "Couldn't save your changes. Try again.",
              ),
              TextButton(
                onPressed: () => _choose(_failed!),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
