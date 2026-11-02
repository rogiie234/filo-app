import 'package:filo/component_gallery_main.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'brief palettes, distinct destructive colors and extension interpolation',
    () {
      expect(AppTheme.light.colorScheme.surface, Colors.white);
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF0F1A17));
      final light = AppTheme.light.extension<FiloThemeTokens>()!;
      final dark = AppTheme.dark.extension<FiloThemeTokens>()!;
      expect(light.primaryEdge, const Color(0xFF1A5444));
      expect(dark.primaryEdge, const Color(0xFF3A8F72));
      expect(light.destructive, const Color(0xFFC9372C));
      expect(light.destructive, isNot(AppTheme.light.colorScheme.error));
      expect(light.copyWith(lime: Colors.red).lime, Colors.red);
      expect(
        light.lerp(dark, .5).successTint,
        Color.lerp(light.successTint, dark.successTint, .5),
      );
      expect(AppTheme.light.textTheme.titleLarge!.fontWeight, FontWeight.w700);
      expect(AppTheme.light.textTheme.bodySmall!.fontWeight, FontWeight.w500);
      expect(AppTheme.light.textTheme.labelMedium!.height, 20 / 14);
    },
  );

  testWidgets('root scaling caps large text and preserves smaller settings', (
    tester,
  ) async {
    for (final scale in [.8, 1.0, 1.3, 2.0]) {
      double? actual;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: FiloTextScale(
              child: Builder(
                builder: (context) {
                  actual = MediaQuery.textScalerOf(context).scale(20);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(actual, 20 * (scale > 1.3 ? 1.3 : scale));
    }
  });

  testWidgets(
    'variants preserve callbacks, busy guards, tokens and pressed edge',
    (tester) async {
      var taps = 0;
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final variant in [
          'primary',
          'secondary',
          'outlined',
          'text',
          'destructive',
        ]) {
          Widget app(bool busy) => MaterialApp(
            theme: theme,
            home: Scaffold(
              body: FiloButton(
                label: 'Action',
                onPressed: () => taps++,
                busy: busy,
                secondary: variant == 'secondary',
                outlined: variant == 'outlined',
                text: variant == 'text',
                destructive: variant == 'destructive',
              ),
            ),
          );
          await tester.pumpWidget(app(false));
          await tester.pumpAndSettle();
          final filled = tester.widget<FilledButton>(find.byType(FilledButton));
          if (variant == 'destructive') {
            expect(
              filled.style!.backgroundColor!.resolve({}),
              theme.extension<FiloThemeTokens>()!.destructive,
            );
          }
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(FilledButton)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          final padding = tester.widget<AnimatedPadding>(
            find.descendant(
              of: find.byType(FiloButton),
              matching: find.byType(AnimatedPadding),
            ),
          );
          if (variant == 'primary' || variant == 'destructive') {
            expect(padding.padding, const EdgeInsets.only(top: 3, bottom: 1));
          }
          await gesture.up();
          await tester.pumpWidget(app(true));
          await tester.pump();
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          final before = taps;
          await tester.tap(find.byType(FilledButton));
          expect(taps, before);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      expect(taps, 10);
    },
  );

  testWidgets(
    'generic confirmation preserves cancel, confirm and dismissal results',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await confirmAction(
                    context,
                    title: 'Remove item?',
                    message: 'Example only.',
                    action: 'Remove',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      await open();
      final buttons = tester
          .widgetList<FiloButton>(find.byType(FiloButton))
          .toList();
      expect(buttons.first.label, 'Cancel');
      expect(buttons.first.secondary, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      await open();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      await open();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isFalse);
    },
  );

  testWidgets(
    'gallery renders all parts at 130 percent in both themes and opens overlays',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const ComponentGalleryApp());
      await tester.pump();
      await tester.tap(find.text('130%'));
      await tester.pump();
      final scroll = find.byType(SingleChildScrollView).first;
      for (final mode in ['Dark', 'Light']) {
        await tester.drag(scroll, const Offset(0, 30000));
        await tester.pump();
        await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(mode).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(FiloProgressBar), findsOneWidget);
        expect(find.byType(FiloPageIndicator), findsOneWidget);
        expect(find.byType(FiloSkeleton), findsNWidgets(2));
        expect(find.byType(FiloStatusChip), findsNWidgets(13));
        expect(find.byType(EmptyState), findsNWidgets(2));
        await tester.ensureVisible(find.text('Open confirmation'));
        await tester.pump();
        await tester.tap(find.text('Open confirmation'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(FiloConfirmationDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(find.text('Open notice'));
        await tester.tap(find.text('Open notice'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(FiloNoticeDialog), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(find.text('Open bottom sheet'));
        await tester.tap(find.text('Open bottom sheet'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Example sheet'), findsOneWidget);
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'toast replacement retains duration and does not queue stale feedback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showFiloToast(context, 'Old message');
                  showFiloToast(
                    context,
                    'New error',
                    kind: FiloToastKind.error,
                  );
                },
                child: const Text('Notify'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Notify'));
      await tester.pumpAndSettle();
      expect(find.text('Old message'), findsNothing);
      expect(find.text('New error'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 4),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'skeleton is static with reduced motion and empty state can omit mascot',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: Column(
                children: [
                  FiloSkeleton(),
                  EmptyState(
                    title: 'No results.',
                    message: 'Try later.',
                    showMascot: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Mascot), findsNothing);
      final fade = tester.widget<FadeTransition>(
        find.byType(FadeTransition).last,
      );
      expect(fade.opacity.value, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
