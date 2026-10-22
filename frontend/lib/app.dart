import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/auth_providers.dart';
import 'core/supabase/session_gate.dart';
import 'features/auth/presentation/session_screen.dart';
import 'data/local/database_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Filo',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    themeMode: ThemeMode.light,
    routerConfig: ref.watch(appRouterProvider),
    builder: (context, child) => _ForegroundTickers(
      child: Consumer(
        builder: (context, ref, _) {
          final login = ref.watch(loginSessionProvider);
          final database = ref.watch(accountDatabaseProvider);
          if (login.asData?.value != null) {
            // Replacing the router child here also removes its Navigator/Overlay.
            // Keep authentication screens inside a route so text editing and
            // selection can find the overlay required by EditableText.
            return Navigator(
              key: ValueKey(login.asData!.value!.user.id),
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const SessionScreen(),
              ),
            );
          }
          // Public screens must not wait for the previous account's SQLite cleanup.
          // The database provider still closes/serializes files before another
          // account can open them; signed-in screens remain verification-gated.
          final signedOut = login.asData != null && login.asData!.value == null;
          if (!signedOut && database.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!signedOut && database.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not open your saved data.'),
                    TextButton(
                      onPressed: () {
                        ref.invalidate(verifiedUserIdProvider);
                        ref.invalidate(accountDatabaseProvider);
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          return KeyedSubtree(
            key: ValueKey(ref.watch(authUserIdProvider).asData?.value),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ),
  );
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
