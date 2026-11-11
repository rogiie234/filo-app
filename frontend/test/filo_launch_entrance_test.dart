import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_launch_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('launch preserves child and releases input, reduced=$reduced', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: FiloLaunchEntrance(
            child: Scaffold(
              body: TextButton(
                onPressed: () => taps++,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(
        find.text('Learning, together.'),
        reduced ? findsNothing : findsOneWidget,
      );
      if (!reduced) {
        expect(
          tester
              .widget<IgnorePointer>(find.byType(IgnorePointer).first)
              .ignoring,
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 2300));
      }
      expect(find.text('Learning, together.'), findsNothing);
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Learning, together.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
