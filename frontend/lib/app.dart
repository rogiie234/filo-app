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
        return SessionScreen(key: ValueKey(login.asData!.value!.user.id));
      }
      // Unmount the old account's screens while switching database files.
      if (database.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (database.hasError) {
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
