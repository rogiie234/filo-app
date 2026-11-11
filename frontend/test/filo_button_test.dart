import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_button.dart';
import 'package:filo/core/widgets/filo_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('label resizing bypasses zero-duration size animations', (
    tester,
  ) async {
    for (final reduced in [false, true]) {
      for (final animate in [false, true]) {
        for (final zeroDuration in [false, true]) {
          Widget screen(String label) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 160,
                  child: FiloButton(
                    label: label,
                    onPressed: () {},
                    animateLabelSize: animate,
                    labelDuration: zeroDuration
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpWidget(screen('Add'));
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            screen('Add selected questions to this assessment'),
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(FiloButton),
              matching: find.byType(AnimatedSize),
            ),
            !reduced && animate && !zeroDuration
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.text('Add selected questions to this assessment'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
  });

  testWidgets('icon-only action keeps circular shape, label and busy guard', (
    tester,
  ) async {
    var taps = 0;
    Widget screen(bool busy) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 72,
            child: FiloButton(
              label: 'Add files',
              icon: Icons.add,
              iconOnly: true,
              minHeight: 72,
              busy: busy,
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    expect(
      tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!
          .shape!
          .resolve({}),
      isA<CircleBorder>(),
    );
    expect(tester.getSize(find.byType(FiloButton)).width, 72);
    expect(find.byTooltip('Add files'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
    await tester.pumpWidget(screen(true));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'outlined destructive actions have red text and border without red fill',
    (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: FiloButton(
                label: 'Confirm',
                destructive: true,
                outlined: true,
                onPressed: () {},
              ),
            ),
          ),
        );
        final control = tester.widget<FilledButton>(find.byType(FilledButton));
        final tokens = FiloThemeTokens.of(
          tester.element(find.byType(FiloButton)),
        );
        expect(control.style!.foregroundColor!.resolve({}), tokens.destructive);
        expect(control.style!.side!.resolve({})!.color, tokens.destructive);
        expect(control.style!.backgroundColor!.resolve({}), Colors.transparent);
      }
    },
  );

  testWidgets(
    'changing class action slides its icon and honors reduced motion',
    (tester) async {
      for (final reduced in [false, true]) {
        Widget action(String label) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: FiloButton(
                label: label,
                icon: Icons.add,
                animateLabelSize: true,
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpWidget(action('Create post'));
        await tester.pumpAndSettle();
        final before = tester.getCenter(find.byType(FiloIcon)).dx;
        await tester.pumpWidget(action('New assessment'));
        await tester.pump(const Duration(milliseconds: 200));
        final halfway = tester.getCenter(find.byType(FiloIcon)).dx;
        await tester.pumpAndSettle();
        final after = tester.getCenter(find.byType(FiloIcon)).dx;
        expect(after, greaterThan(before));
        if (reduced) {
          expect(halfway, closeTo(after, .1));
        } else {
          expect(halfway, greaterThan(before));
          expect(halfway, lessThan(after));
        }
      }
    },
  );

  for (final (longLabel, shortLabel) in [
    ('New assessment', 'Create post'),
    ('Create class', 'Add files'),
    ('Join class', 'Add files'),
  ]) {
    testWidgets(
      'action holds its icon before the staged glide: $longLabel to $shortLabel',
      (tester) async {
        Widget action(String label) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: FiloButton(
                label: label,
                icon: Icons.add,
                onPressed: () {},
                animateLabelSize: true,
                labelDuration: const Duration(milliseconds: 800),
                labelSizeCurve: label == shortLabel
                    ? const Interval(.75, 1, curve: Curves.easeInOutCubic)
                    : const Interval(.5, .75, curve: Curves.easeInOutCubic),
                labelInCurve: label == shortLabel
                    ? const Interval(.5, .75, curve: Curves.easeOutCubic)
                    : const Interval(.75, 1, curve: Curves.easeOutCubic),
              ),
            ),
          ),
        );
        await tester.pumpWidget(action(shortLabel));
        await tester.pumpAndSettle();
        for (final label in [longLabel, shortLabel]) {
          final start = tester.getCenter(find.byType(FiloIcon)).dx;
          await tester.pumpWidget(action(label));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester.getCenter(find.byType(FiloIcon)).dx,
            closeTo(start, .1),
          );
          await tester.pump(const Duration(milliseconds: 400));
          final during = tester.getCenter(find.byType(FiloIcon)).dx;
          await tester.pumpAndSettle();
          final end = tester.getCenter(find.byType(FiloIcon)).dx;
          if (label == shortLabel) {
            expect(during, lessThan(start));
            expect(during, greaterThan(end));
          } else {
            expect(end, greaterThan(start));
          }
        }
      },
    );
  }

  var taps = 0;
  Widget button({
    bool enabled = true,
    bool busy = false,
    bool pulse = false,
    bool reduced = false,
  }) => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Scaffold(
      body: FiloButton(
        label: 'Continue',
        onPressed: enabled ? () => taps++ : null,
        busy: busy,
        idlePulse: pulse,
      ),
    ),
  );

  testWidgets(
    'label busy mode stays visible, larger and blocks repeat actions',
    (tester) async {
      taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: FiloButton(
                label: 'Signing in?',
                onPressed: () => taps++,
                secondary: true,
                minHeight: 64,
                busy: true,
                showBusyIndicator: false,
                leading: const Icon(Icons.login),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Signing in?'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(FiloButton)).height, 64);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Signing in?'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initially disabled and busy buttons mount without build notifications',
    (tester) async {
      for (final busy in [false, true]) {
        await tester.pumpWidget(button(enabled: false, busy: busy));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final inner = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(inner.onPressed, isNull);
        expect(inner.statesController!.value, contains(WidgetState.disabled));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('pulsing and pressed button can become unavailable and recover', (
    tester,
  ) async {
    taps = 0;
    await tester.pumpWidget(button(pulse: true));
    await tester.pump(const Duration(milliseconds: 300));
    for (final busy in [true, false]) {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(button(enabled: busy, busy: busy, pulse: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final states = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .statesController!
          .value;
      expect(states, contains(WidgetState.disabled));
      expect(states, isNot(contains(WidgetState.pressed)));
      await gesture.up();
      expect(taps, 0);
      await tester.pumpWidget(button(pulse: true));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpWidget(button(reduced: true, pulse: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
