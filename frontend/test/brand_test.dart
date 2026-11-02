import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [96.0, 160.0, 320.0]) {
      testWidgets(
        'Brand dark=$dark width=$width fits at 130 percent without clipping',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.3),
                  devicePixelRatio: 3,
                ),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, child: const Brand()),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final image = tester.widget<Image>(
            find.descendant(
              of: find.byType(Brand),
              matching: find.byType(Image),
            ),
          );
          final provider = image.image as ResizeImage;
          expect(
            (provider.imageProvider as AssetImage).assetName,
            dark
                ? 'assets/brand/logo-mark-dark.png'
                : 'assets/brand/logo-mark-light.png',
          );
          expect(provider.width, 108);
          expect(image.fit, BoxFit.contain);
          expect(image.excludeFromSemantics, isTrue);
          expect(
            find.descendant(
              of: find.byType(Brand),
              matching: find.byType(ClipRRect),
            ),
            findsNothing,
          );
          expect(find.text('filo'), findsOneWidget);
          expect(
            tester.getSize(find.byType(FittedBox)).width,
            lessThanOrEqualTo(width),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
