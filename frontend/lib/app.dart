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
    routerConfig: ref.watch(appRouterProvider),
    builder: (context, child) {
      final login = ref.watch(loginSessionProvider);
      final database = ref.watch(accountDatabaseProvider);
      if (login.asData?.value != null) {
        // Replacing the router child here also removes its Navigator/Overlay.
        // Keep authentication screens inside a route so text editing and
        // selection can find the overlay required by EditableText.
        return Navigator(
          key: ValueKey(login.asData!.value!.user.id),
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const SessionScreen()),
        );
      }
      // Public screens must not wait for the previous account's SQLite cleanup.
      // The database provider still closes/serializes files before another
      // account can open them; signed-in screens remain verification-gated.
      final signedOut = login.asData != null && login.asData!.value == null;
      if (!signedOut && database.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  );
}
