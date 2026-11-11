import 'package:filo/core/widgets/entry_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page compositions repaint only when their inputs change', (
    tester,
  ) async {
    Future<CustomPainter> paint(int variation) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: EntryBackground(variation: variation)),
          ),
        ),
      );
      return tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(EntryBackground),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
    }

    final original = await paint(0);
    final same = await paint(0);
    expect(same.shouldRepaint(original), isFalse);
    for (final variation in [1, 2]) {
      final changed = await paint(variation);
      expect(changed.shouldRepaint(original), isTrue);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'full-page decoration covers header without moving or blocking content',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EntryBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: const Text('Header'),
              ),
              body: TextButton(
                onPressed: () => taps++,
                child: const Text('Action'),
              ),
            ),
          ),
        ),
      );
      final background = find
          .descendant(
            of: find.byType(EntryBackground),
            matching: find.byType(CustomPaint),
          )
          .first;
      final bounds = tester.getRect(background);
      expect(bounds, tester.getRect(find.byType(Scaffold)));
      expect(bounds.contains(tester.getCenter(find.text('Header'))), isTrue);
      expect(
        tester.getTopLeft(find.text('Action')).dy,
        greaterThan(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      await tester.tap(find.text('Action'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('embedded pages reuse the parent decoration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EntryBackground(
          variation: 0,
          child: EntryBackground(enabled: false, child: Text('Embedded page')),
        ),
      ),
    );
    final outer = find.byType(EntryBackground).first;
    expect(
      find.descendant(of: outer, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(find.text('Embedded page'), findsOneWidget);
  });
}
