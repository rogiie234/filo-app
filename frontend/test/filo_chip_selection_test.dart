import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'chip has no empty check slot and animates selection, reduced=$reduced',
      (tester) async {
        var selected = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, update) => FiloAnimatedChip(
                    label: const Text('Images'),
                    selected: selected,
                    onSelected: (value) => update(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.widget<ChoiceChip>(find.byType(ChoiceChip)).avatar,
          isNull,
        );
        final idleWidth = tester.getSize(find.byType(ChoiceChip)).width;
        await tester.tap(find.text('Images'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.widget<ChoiceChip>(find.byType(ChoiceChip)).avatar,
          isNotNull,
        );
        expect(
          tester.getSize(find.byType(ChoiceChip)).width,
          greaterThan(idleWidth),
        );
        final opacity = tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byType(FiloMotionTween),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        if (reduced) {
          expect(opacity, 1);
        } else {
          expect(opacity, greaterThan(0));
          expect(opacity, lessThan(1));
        }
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Images'));
        await tester.pump();
        expect(
          tester.widget<ChoiceChip>(find.byType(ChoiceChip)).avatar,
          isNull,
        );
      },
    );
  }
}
