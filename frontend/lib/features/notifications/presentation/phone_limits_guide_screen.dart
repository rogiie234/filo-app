import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/deadline_providers.dart';
import '../../../core/notifications/deadline_reminders.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../onboarding/application/notification_permission.dart';
import '../application/notification_providers.dart';
import '../data/alarm_repository.dart';

const phoneGuideHeading = 'Help study alarms reach you';
const phoneGuideIntroduction =
    'Check these phone settings to help Filo deliver study alarms. Settings names may vary by phone. These changes may use more battery and do not guarantee delivery.';
const phoneGuideFallback =
    "Open your phone's Settings and search for Alarms & reminders, Autostart or Filo's battery settings. Select Filo and follow the step above. Then return here.";

final phoneGuideCapabilitiesProvider =
    FutureProvider.autoDispose<PhoneGuideCapabilities>(
      (ref) => ref.watch(deadlineBridgeProvider).guideCapabilities(),
    );

class PhoneLimitsGuideScreen extends ConsumerStatefulWidget {
  const PhoneLimitsGuideScreen({super.key, this.expectedUserId});
  final String? expectedUserId;
  @override
  ConsumerState<PhoneLimitsGuideScreen> createState() =>
      _PhoneLimitsGuideState();
}

class _PhoneLimitsGuideState extends ConsumerState<PhoneLimitsGuideScreen> {
  late final AppLifecycleListener _lifecycle;
  AlarmRepository? _account;
  bool _shown = false, _closing = false, _opening = false;
  String? _retrySection;
  bool _manual = false;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    ref.invalidate(deadlineStatusProvider);
    ref.invalidate(notificationAccessProvider);
    // App's existing alarm lifecycle reconciles on resume, independently of this guide.
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    final account = _account;
    try {
      if (_shown && account != null && account.isCurrent())
        await account.dismissPhoneGuide();
    } catch (_) {
      /* A failed seen-marker write allows the guide to appear next save. */
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _open(String section) async {
    if (_opening || _closing || _account?.isCurrent() != true) return;
    setState(() => {_opening = true, _manual = false, _retrySection = null});
    try {
      final result = await ref
          .read(deadlineBridgeProvider)
          .guideOpenSettings(section);
      if (!mounted || _account?.isCurrent() != true) return;
      setState(
        () => {
          _manual = result != 'direct',
          _retrySection = result == 'failed' ? section : null,
        },
      );
    } catch (_) {
      if (mounted) setState(() => {_manual = true, _retrySection = section});
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _step(
    String title,
    List<String> lines,
    String label,
    String section, {
    bool? allowed,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: FiloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (allowed == true)
            const Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.check_circle_outline,
                semanticLabel: 'Exact-alarm access allowed',
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${i + 1}. ${lines[i]}'),
            ),
          FiloButton(
            label: label,
            onPressed: _opening || _closing ? null : () => _open(section),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(alarmRepositoryProvider);
    final capability = ref.watch(phoneGuideCapabilitiesProvider);
    final status = ref.watch(deadlineStatusProvider);
    final access = ref.watch(notificationAccessProvider);
    final available =
        !repository.isLoading && !repository.hasError && repository.hasValue;
    if (available &&
        (_account == null ||
            _account!.userId == repository.requireValue.userId))
      _account = repository.requireValue;
    final current =
        available &&
        _account?.isCurrent() == true &&
        repository.requireValue.db == _account?.db &&
        (widget.expectedUserId == null ||
            repository.requireValue.userId == widget.expectedUserId);
    if (current)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _account?.isCurrent() == true) _shown = true;
      });
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Alarm setup')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!current) ...[
                if (repository.isLoading)
                  const Center(
                    child: FiloCircularProgressIndicator(
                      semanticsLabel: 'Loading alarm setup',
                    ),
                  )
                else ...[
                  const Text('Account unavailable. Reopen alarm setup.'),
                  TextButton(
                    onPressed: () => ref.invalidate(alarmRepositoryProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ] else ...[
                Text(
                  phoneGuideHeading,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(phoneGuideIntroduction),
                if (!access.isLoading &&
                    !access.hasError &&
                    access.asData?.value == false) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Notifications are off for Filo. Turn them on in your phone settings.',
                  ),
                  TextButton(
                    onPressed: _opening || _closing
                        ? null
                        : () async {
                            setState(() => _opening = true);
                            try {
                              await ref
                                  .read(notificationPermissionProvider)
                                  .openSettings();
                            } catch (_) {
                              if (mounted) setState(() => _manual = true);
                            } finally {
                              if (mounted) setState(() => _opening = false);
                            }
                          },
                    child: const Text('Open settings'),
                  ),
                ],
                if (capability.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: FiloCircularProgressIndicator(
                        semanticsLabel: 'Checking phone setup steps',
                      ),
                    ),
                  )
                else if (capability.hasError) ...[
                  const Text('Could not check phone setup steps. Try again.'),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(phoneGuideCapabilitiesProvider),
                    child: const Text('Try again'),
                  ),
                ] else ...[
                  if (capability.requireValue.exactStep)
                    _step(
                      'Exact-alarm access',
                      const [
                        'Tap Open alarm settings.',
                        'Select Filo if a list of apps appears.',
                        'Allow Filo under Alarms & reminders.',
                        'Return to Filo.',
                      ],
                      'Open alarm settings',
                      'alarm',
                      allowed:
                          !status.isLoading &&
                          !status.hasError &&
                          status.asData?.value['exact'] == true,
                    ),
                  if (capability.requireValue.xiaomi) ...[
                    _step(
                      'Autostart — Xiaomi, Redmi and POCO',
                      const [
                        'Tap Open autostart settings.',
                        'Find Filo under Autostart or Background autostart.',
                        'Turn on the switch for Filo.',
                        'Return to Filo.',
                      ],
                      'Open autostart settings',
                      'autostart',
                    ),
                    _step(
                      'Battery — Xiaomi, Redmi and POCO',
                      const [
                        'Tap Open battery settings.',
                        'Select Filo if a list of apps appears.',
                        'Open its battery settings and choose No restrictions.',
                        'Return to Filo.',
                      ],
                      'Open battery settings',
                      'battery',
                    ),
                  ],
                ],
                if (status.hasError || access.hasError)
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                if (_manual) ...[
                  const SizedBox(height: 16),
                  const Text(phoneGuideFallback),
                  if (_retrySection != null)
                    TextButton(
                      onPressed: _opening ? null : () => _open(_retrySection!),
                      child: const Text('Try again'),
                    ),
                ],
              ],
              const SizedBox(height: 24),
              FiloButton(label: 'Done', onPressed: _closing ? null : _close),
              TextButton(
                onPressed: _closing ? null : _close,
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
