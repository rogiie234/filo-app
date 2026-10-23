import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
