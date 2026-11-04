import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/entry_artwork.dart';
import 'package:filo/core/widgets/entry_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entry circle follows theme while retaining each pose', (
    tester,
  ) async {
    BoxDecoration? lightCircle;
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      for (final pose in ['waving', 'cheerful', 'curious']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(child: EntryMascot(pose: pose)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
          'assets/mascots/entry/$pose.png',
        );
        final circle =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(EntryMascot),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(circle.shape, BoxShape.circle);
        if (theme.brightness == Brightness.light) {
          lightCircle = circle;
        } else {
          expect(circle.gradient, isNot(lightCircle!.gradient));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('entry decoration does not intercept controls', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Continue'),
                ),
              ),
              const Positioned.fill(child: EntryBackground()),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
