import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/filo_startup_screen.dart';
import '../supabase/auth_providers.dart';
import '../supabase/session_gate.dart';
import '../../data/local/database_providers.dart';
import '../../features/auth/presentation/session_screen.dart';
import '../../features/notifications/presentation/push_notification_host.dart';
import '../../features/settings/presentation/deletion_recovery_gate.dart';

/// Keep the account Navigator inside a Router route so system Back reaches it.
class SessionNavigationGate extends ConsumerWidget {
  const SessionNavigationGate({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DeletionRecoveryGate(
    child: Consumer(
      builder: (context, ref, _) {
        final login = ref.watch(loginSessionProvider);
        final database = ref.watch(accountDatabaseProvider);
        if (login.asData?.value != null) {
          // Keep the account stack stable across URL changes within this shell.
          return Stack(
            children: [
              Offstage(offstage: true, child: child),
              PushNotificationHost(
                key: ValueKey(login.asData!.value!.user.id),
                userId: login.asData!.value!.user.id,
                child: const SessionScreen(),
              ),
            ],
          );
        }
        // Public screens must not wait for the previous account's SQLite cleanup.
        // The database provider still closes/serializes files before another
        // account can open them; signed-in screens remain verification-gated.
        final signedOut = login.asData != null && login.asData!.value == null;
        if (!signedOut && database.isLoading) {
          return const FiloStartupScreen();
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
          child: child,
        );
      },
    ),
  );
}

/// The shell must stay mounted without building a second signed-in session.
class PublicRoutePage extends ConsumerWidget {
  const PublicRoutePage({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(loginSessionProvider).asData?.value == null
      ? child
      : const SizedBox.shrink();
}
