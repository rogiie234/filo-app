import 'dart:async';

import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign-in disables offline and enables after reconnection', (
    tester,
  ) async {
    final changes = StreamController<bool>();
    addTearDown(changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivityProvider.overrideWith((ref) => changes.stream)],
        child: MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
      ),
    );
    FiloButton button() => tester.widget<FiloButton>(
      find.byWidgetPredicate(
        (w) => w is FiloButton && w.label == 'Continue with Google',
      ),
    );
    expect(button().onPressed, isNull);
    changes.add(false);
    await tester.pumpAndSettle();
    expect(button().onPressed, isNull);
    expect(
      find.text('You’re offline. Connect to the internet to sign in.'),
      findsOneWidget,
    );
    changes.add(true);
    await tester.pumpAndSettle();
    expect(button().onPressed, isNotNull);
    expect(
      find.text('You’re offline. Connect to the internet to sign in.'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
