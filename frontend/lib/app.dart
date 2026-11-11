import 'core/widgets/filo_launch_entrance.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/notifications/push_providers.dart';
import 'core/notifications/deadline_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/filo_motion.dart';
import 'features/settings/application/theme_settings.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushLifecycleProvider);
    ref.watch(pushMessagesLifecycleProvider);
    ref.watch(deadlineLifecycleProvider);
    final appearance = ref.watch(themeSettingsProvider);
    return MaterialApp.router(
      title: 'Filo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: appearance.asData?.value ?? ThemeMode.system,
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => FiloTextScale(
        child: FiloMotionScope(
          child: _ForegroundTickers(
            child: FiloLaunchEntrance(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Suspend component and loading tickers while the application is not visible.
class _ForegroundTickers extends StatefulWidget {
  const _ForegroundTickers({required this.child});
  final Widget child;

  @override
  State<_ForegroundTickers> createState() => _ForegroundTickersState();
}

class _ForegroundTickersState extends State<_ForegroundTickers>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground != foreground) setState(() => _foreground = foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: _foreground && TickerMode.valuesOf(context).enabled,
    child: widget.child,
  );
}
