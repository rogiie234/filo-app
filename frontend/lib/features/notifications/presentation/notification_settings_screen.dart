import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/push_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../onboarding/application/notification_permission.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  void _refresh() {
    if (mounted) ref.invalidate(notificationAccessProvider);
  }

  Future<void> _openSettings() async {
    setState(() => _opening = true);
    try {
      await ref.read(notificationPermissionProvider).openSettings();
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not open phone settings. Try again.');
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
          CircularProgressIndicator(
            semanticsLabel: 'Checking notification access',
          ),
          SizedBox(height: 16),
          Text('Checking notification access…'),
        ],
      );
    } else if (access.hasError) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Could not check notification access. Try again.'),
          const SizedBox(height: 16),
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
              style: const TextStyle(
                color: FiloColors.ink,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FiloButton(
            label: 'Open settings',
            busy: _opening,
            onPressed: _opening ? null : _openSettings,
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FiloPanel(
            color: access.asData?.value == false
                ? FiloColors.mint
                : Colors.white,
            child: content,
          ),
        ),
      ),
    );
  }
}
