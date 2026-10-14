import 'package:filo/app.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('root route opens the Filo intro', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserIdProvider.overrideWith((ref) => Stream.value(null)),
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
