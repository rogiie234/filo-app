import 'dart:io';

import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native splash inner layers scale proportionally instead of fixed dp',
    () {
      final icon = File(
        'android/app/src/main/res/drawable/filo_splash_icon.xml',
      ).readAsStringSync();
      expect(icon, isNot(contains('android:width=')));
      expect(icon, isNot(contains('android:height=')));
      expect(icon, contains('android:insetLeft="16%"'));
      expect(icon, contains('android:insetRight="16%"'));
      expect(icon, contains('android:gravity="fill"'));
      expect(icon, contains('android:mipMap="true"'));
      expect(icon, contains('android:antialias="true"'));
      expect(icon, contains('@drawable/filo_splash_logo'));
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'startup uses matching brand and readable loading in dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const FiloStartupScreen(),
          ),
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.isAntiAlias, isTrue);
        expect(
          (image.image as AssetImage).assetName,
          dark
              ? 'assets/brand/logo-mark-dark.png'
              : 'assets/brand/logo-mark-light.png',
        );
        expect(tester.getSize(find.byType(Image)), const Size(144, 144));
        expect(find.text('filo'), findsOneWidget);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .semanticsLabel,
          'Starting Filo',
        );
        final background = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(background.backgroundColor, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
