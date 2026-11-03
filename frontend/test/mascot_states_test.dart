import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(
    Widget child, {
    bool reduced = true,
    bool visible = true,
    ThemeData? theme,
  }) => MaterialApp(
    theme: theme ?? AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduced,
        textScaler: TextScaler.linear(1.3),
      ),
      child: TickerMode(
        enabled: visible,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );

  testWidgets(
    'all poses use contained small and hero derivatives without semantics',
    (tester) async {
      for (final pose in Mascot.poses) {
        for (final size in [120.0, 240.0]) {
          await tester.pumpWidget(app(Mascot(pose: pose, size: size)));
          final image = tester.widget<Image>(find.byType(Image));
          expect((image.image as ResizeImage).imageProvider, isA<AssetImage>());
          final asset =
              ((image.image as ResizeImage).imageProvider as AssetImage)
                  .assetName;
          expect(
            asset,
            'assets/mascots/${size == 120 ? 'empty/' : ''}$pose.png',
          );
          expect(image.fit, BoxFit.contain);
          expect(
            find.ancestor(
              of: find.byType(Image),
              matching: find.byType(ExcludeSemantics),
            ),
            findsWidgets,
          );
          expect(find.byType(MascotIdle), findsNothing);
        }
      }
    },
  );

  testWidgets(
    'empty states preserve help and actions in both themes at 130 percent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var retries = 0;
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          app(
            EmptyState(
              title: 'No files yet.',
              message: 'Add a file to get started.',
              pose: 'folder',
              action: FiloButton(label: 'Retry', onPressed: () => retries++),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Mascot>(find.byType(Mascot)).pose, 'folder');
        expect(find.text('Add a file to get started.'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(retries, 2);
      await tester.pumpWidget(
        app(const EmptyState(title: 'No grades yet.', showMascot: false)),
      );
      expect(find.byType(Mascot), findsNothing);
      expect(find.byType(MascotIdle), findsNothing);
    },
  );

  testWidgets(
    'bob stays within four dp, completes three seconds and resets when hidden',
    (tester) async {
      double y() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(MascotIdle),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[13];
      const child = MascotIdle(child: SizedBox(width: 120, height: 120));
      await tester.pumpWidget(app(child, reduced: false));
      await tester.pump();
      expect(y(), 0);
      await tester.pump(const Duration(milliseconds: 750));
      expect(y(), closeTo(-2, .01));
      await tester.pump(const Duration(milliseconds: 750));
      expect(y(), closeTo(-4, .01));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(y(), closeTo(0, .01));
      await tester.pumpWidget(app(child, reduced: false, visible: false));
      await tester.pump(const Duration(seconds: 4));
      expect(y(), 0);
      await tester.pumpWidget(app(child, reduced: true));
      await tester.pump(const Duration(seconds: 4));
      expect(y(), 0);
      await tester.pumpWidget(app(child, reduced: false));
      await tester.pump(const Duration(milliseconds: 750));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(y(), 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(y(), lessThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
}
