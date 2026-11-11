import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/push_providers.dart';
import '../../../core/notifications/deadline_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../onboarding/application/notification_permission.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../classes/application/class_providers.dart';
import '../application/notification_providers.dart';
import '../data/notification_settings_repository.dart';
import 'phone_limits_guide_screen.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    this.initialClassId,
    this.focusPhoneSetup = false,
    this.embedded = false,
  });
  final String? initialClassId;
  final bool focusPhoneSetup;
  final bool embedded;

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _opening = false;
  final _phoneSetup = GlobalKey();
  bool _phoneFocused = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  void _refresh() {
    if (mounted) {
      ref.invalidate(notificationAccessProvider);
      ref.invalidate(notificationPreferencesRefreshProvider);
      ref.invalidate(deadlineStatusProvider);
    }
  }

  Future<void> _openSettings() async {
    setState(() => _opening = true);
    try {
      await ref.read(notificationPermissionProvider).openSettings();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not open phone settings. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        _refresh();
      }
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.focusPhoneSetup && !_phoneFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _phoneSetup.currentContext != null) {
          _phoneFocused = true;
          Scrollable.ensureVisible(
            _phoneSetup.currentContext!,
            alignment: 0.1,
            duration: Duration.zero,
          );
        }
      });
    }
    final access = ref.watch(notificationAccessProvider);
    ref.listen(notificationAccessProvider, (_, next) {
      if (next.asData?.value == true) {
        unawaited(ref.read(pushRegistrationProvider).sync());
      }
    });
    final Widget content;
    if (access.isLoading) {
      content = const Column(
        children: [
          FiloCircularProgressIndicator(
            semanticsLabel: 'Checking notification access',
          ),
          SizedBox(height: FiloSpacing.s16),
          Text('Checking notification access…'),
        ],
      );
    } else if (access.hasError) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Could not check notification access. Try again.'),
          const SizedBox(height: FiloSpacing.s16),
          FiloButton(label: 'Retry', onPressed: _refresh),
        ],
      );
    } else {
      final enabled = access.requireValue;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              enabled ? 'Notifications are on for Filo.' : 'Notifications are off for Filo. Turn them on in your phone settings.',
              style: Theme.of(context).textTheme.bodyLarge!
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: FiloSpacing.s16),
          FiloButton(
            label: 'Open settings',
            busy: _opening,
            onPressed: _opening ? null : _openSettings,
          ),
        ],
      );
    }
    final body = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FiloSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FiloPanel(
              color: access.asData?.value == false
                  ? FiloThemeTokens.of(context).mint
                  : Theme.of(context).colorScheme.surface,
              child: content,
            ),
            const SizedBox(height: FiloSpacing.screen),
            NotificationPreferenceControls(
              initialClassId: widget.initialClassId,
            ),
            if (ref.watch(deadlineBridgeProvider).supported) ...[
              const SizedBox(height: FiloSpacing.screen),
              KeyedSubtree(
                key: _phoneSetup,
                child: const DeadlineReminderSetup(),
              ),
            ],
          ],
        ),
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Notification settings')),
            body: body,
          );
  }
}

class DeadlineReminderSetup extends ConsumerStatefulWidget {
  const DeadlineReminderSetup({super.key});
  @override
  ConsumerState<DeadlineReminderSetup> createState() =>
      _DeadlineReminderSetupState();
}

class _DeadlineReminderSetupState extends ConsumerState<DeadlineReminderSetup> {
  bool _busy = false;
  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      ref.invalidate(deadlineSessionProvider);
      await (await ref.read(deadlineSessionProvider.future))?.reconcile();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not update deadline reminders. Retry.');
      }
    } finally {
      if (mounted) {
        ref.invalidate(deadlineStatusProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(deadlineStatusProvider);
    final data = status.asData?.value;
    return FiloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Deadline reminders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: FiloSpacing.s12),
          if (status.isLoading)
            const Text('Checking deadline reminders…')
          else
            Text(
              status.hasError || data?['error'] == true
                  ? 'Could not update deadline reminders. Retry.'
                  : data?['enabled'] != true
                  ? 'Notifications are off. Enable notifications in your phone settings to see deadline reminders.'
                  : data?['exact'] == true
                  ? 'Deadline reminders are ready.'
                  : 'Deadline reminders are approximate and may arrive late. Allow Alarms & reminders for more precise timing.',
            ),
          const SizedBox(height: FiloSpacing.s12),
          const Text('Reminders use saved due dates and work offline.'),
          TextButton(
            onPressed: _busy ? null : _retry,
            child: const Text('Retry reminders'),
          ),
          FiloButton(
            label: 'Alarm setup',
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PhoneLimitsGuideScreen(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class NotificationPreferenceControls extends ConsumerStatefulWidget {
  const NotificationPreferenceControls({super.key, this.initialClassId});
  final String? initialClassId;
  @override
  ConsumerState<NotificationPreferenceControls> createState() =>
      _NotificationPreferenceControlsState();
}

class _PreferenceRetry {
  const _PreferenceRetry(this.classId, this.enabled, this.types);
  final String? classId;
  final bool enabled;
  final Set<String> types;
}

class _NotificationPreferenceControlsState
    extends ConsumerState<NotificationPreferenceControls> {
  final _saving = <String, bool>{};
  final _failures = <String, _PreferenceRetry>{};
  final _focusedClass = GlobalKey();
  bool _focused = false;

  Future<void> _refresh() async {
    try {
      await ref.refresh(notificationPreferencesRefreshProvider.future);
    } catch (_) {
      /* Cached preferences remain visible. */
    }
  }

  Future<void> _save(
    String key,
    String? classId,
    bool enabled,
    Set<String> types,
  ) async {
    if (_saving.containsKey(key) ||
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
    final repo = ref.read(notificationSettingsRepositoryProvider).asData?.value;
    if (repo == null || !repo.isCurrent()) return;
    setState(() {
      _saving[key] = enabled;
      _failures.remove(key);
    });
    Set<String> failed = {};
    try {
      if (classId == null) {
        await repo.set(types.single, null, enabled);
      } else {
        failed = await repo.setClass(classId, enabled, types: types);
      }
    } catch (_) {
      failed = types;
    }
    if (!mounted) return;
    if (!repo.isCurrent()) {
      setState(() => _saving.remove(key));
      return;
    }
    setState(() {
      _saving.remove(key);
      if (failed.isNotEmpty) {
        _failures[key] = _PreferenceRetry(classId, enabled, failed);
      }
    });
  }

  Widget _failure(String key) {
    final retry = _failures[key];
    if (retry == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FiloSpacing.s16,
        0,
        FiloSpacing.s16,
        FiloSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            retry.classId == null
                ? 'Could not save notification setting. Try again.'
                : 'Some notification settings could not be saved',
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(
                FiloControlSize.compact,
                FiloControlSize.compact,
              ),
            ),
            onPressed:
                ref.read(connectivityProvider).asData?.value == true &&
                    !_saving.containsKey(key)
                ? () => _save(key, retry.classId, retry.enabled, retry.types)
                : null,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final refreshing = ref.watch(notificationPreferencesRefreshProvider);
    final repository = ref.watch(notificationSettingsRepositoryProvider);
    final classes = ref.watch(classCardsProvider);
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final repo = repository.asData?.value;
    final current = repo != null && repo.isCurrent();
    final saved = current ? preferences.asData?.value : null;
    final rooms = classes.asData?.value.where((room) => !room.pending).toList();
    final theme = Theme.of(context);
    void focusClass() {
      if (_focused ||
          widget.initialClassId == null ||
          rooms == null ||
          saved == null) {
        return;
      }
      if (!rooms.any((room) => room.id == widget.initialClassId)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusedClass.currentContext == null) return;
        _focused = true;
        Scrollable.ensureVisible(
          _focusedClass.currentContext!,
          duration: Duration.zero,
          alignment: 0.1,
        );
      });
    }

    focusClass();
    Widget retryLoad(
      String text, {
      bool storage = false,
      bool reloadClasses = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        TextButton(
          onPressed: () {
            if (storage) {
              setState(() {
                _saving.clear();
                _failures.clear();
              });
              ref.invalidate(notificationSettingsRepositoryProvider);
              ref.invalidate(notificationPreferencesProvider);
            }
            if (reloadClasses) ref.invalidate(classCardsProvider);
            unawaited(_refresh());
          },
          child: const Text('Retry'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Push preferences', style: theme.textTheme.titleLarge),
        const SizedBox(height: FiloSpacing.s8),
        const Text(
          'These settings control pushes. Notifications still arrive in your inbox. Global type mutes also apply to every class.',
        ),
        const SizedBox(height: FiloSpacing.s16),
        if (!online)
          const Padding(
            padding: EdgeInsets.only(bottom: FiloSpacing.s16),
            child: Text(
              'You’re offline. Showing saved preferences. Connect to change them.',
            ),
          ),
        if (refreshing.hasError)
          retryLoad(
            'Could not refresh notification settings. Saved preferences are unchanged.',
          ),
        if (repository.hasError || preferences.hasError)
          retryLoad(
            'Could not load saved notification settings. Try again.',
            storage: true,
          )
        else if (saved == null) ...[
          if (repository.isLoading ||
              preferences.isLoading ||
              (online && refreshing.isLoading))
            const Padding(
              padding: EdgeInsets.all(FiloSpacing.screen),
              child: Center(
                child: FiloCircularProgressIndicator(
                  semanticsLabel: 'Loading notification preferences',
                ),
              ),
            )
          else
            Text(
              online
                  ? 'Notification preferences are unavailable. Retry to load them.'
                  : 'No saved notification preferences. Connect to load them.',
            ),
        ] else ...[
          const SizedBox(height: FiloSpacing.s16),
          Text('Notification types', style: theme.textTheme.titleMedium),
          const SizedBox(height: FiloSpacing.s8),
          FiloPanel(
            child: Column(
              children: [
                for (final entry in notificationTypes.entries) ...[
                  FiloSwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    subtitle: _saving.containsKey('type:${entry.key}')
                        ? const Text('Saving…')
                        : null,
                    value:
                        _saving['type:${entry.key}'] ??
                        saved.enabled(entry.key),
                    onChanged:
                        online && !_saving.containsKey('type:${entry.key}')
                        ? (enabled) => _save(
                            'type:${entry.key}',
                            null,
                            enabled,
                            {entry.key},
                          )
                        : null,
                  ),
                  _failure('type:${entry.key}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: FiloSpacing.screen),
          Text('Classes', style: theme.textTheme.titleMedium),
          const SizedBox(height: FiloSpacing.s8),
          if (classes.hasError)
            retryLoad('Could not load classes. Try again.', reloadClasses: true)
          else if (rooms == null)
            const Center(
              child: FiloCircularProgressIndicator(
                semanticsLabel: 'Loading classes',
              ),
            )
          else ...[
            if (rooms.isEmpty) const Text('No classes available.'),
            if (widget.initialClassId != null &&
                !rooms.any((room) => room.id == widget.initialClassId))
              const Text('This class is no longer available.'),
            for (final room in rooms)
              Padding(
                key: room.id == widget.initialClassId
                    ? _focusedClass
                    : ValueKey(room.id),
                padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
                child: FiloPanel(
                  child: Column(
                    children: [
                      FiloSwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${room.section} · ${room.course}'),
                        subtitle: Text(
                          [
                            if (room.id == widget.initialClassId)
                              'Selected class',
                            if (room.archived) 'Archived',
                            if (_saving.containsKey('class:${room.id}'))
                              'Saving…'
                            else if (saved.classMixed(room.id))
                              'Some types are muted',
                          ].join(' · '),
                        ),
                        value:
                            _saving['class:${room.id}'] ??
                            saved.classEnabled(room.id),
                        onChanged:
                            online && !_saving.containsKey('class:${room.id}')
                            ? (enabled) => _save(
                                'class:${room.id}',
                                room.id,
                                enabled,
                                notificationTypes.keys.toSet(),
                              )
                            : null,
                      ),
                      _failure('class:${room.id}'),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
