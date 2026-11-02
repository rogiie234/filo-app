import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:filo/app.dart';
import 'package:filo/core/notifications/push_providers.dart';
import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('root route opens the Filo intro', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushLifecycleProvider.overrideWith((ref) {}),
          pushMessagesLifecycleProvider.overrideWith((ref) {}),
          deadlineLifecycleProvider.overrideWith((ref) {}),
          authUserIdProvider.overrideWith((ref) => Stream.value(null)),
          loginSessionProvider.overrideWith((ref) => Stream.value(null)),
          verifiedUserIdProvider.overrideWith((ref) async => null),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning,\ntogether.'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
