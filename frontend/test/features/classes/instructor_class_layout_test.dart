import 'package:filo/features/classes/presentation/classes_widgets.dart';
import 'package:filo/features/classes/presentation/classes_empty_state.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/presentation/class_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'instructor skeleton uses the compact banner and course-row layout',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ClassCardSkeleton()),
          ),
        ),
      );
      final regular = tester.getSize(find.byType(ClassCardSkeleton)).height;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClassCardSkeleton(compact: true),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ClassCardSkeleton)).height,
        lessThan(regular),
      );
      expect(find.byType(CircleAvatar), findsNWidgets(2));
    },
  );
  testWidgets('empty panel keeps one usable create action with its message', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClassesEmptyState(
              title: 'No classes yet.',
              message: 'Create your first class to get started.',
              bob: false,
              action: FiloButton(
                label: 'Create class',
                minHeight: 64,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Create class'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClassesEmptyState),
        matching: find.byType(FiloPanel),
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            ((widget.image as ResizeImage).imageProvider as AssetImage)
                    .assetName ==
                'assets/illustrations/classes-empty.png',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Create class'));
    await tester.tap(find.text('Create class'));
    expect(taps, 1);
  });

  testWidgets(
    'compact list banner saves space without removing class identity',
    (tester) async {
      Future<void> show(bool compact) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClassBanner(
                section: 'BSIT-3A',
                instructor: 'Andrea',
                compact: compact,
              ),
            ),
          ),
        ),
      );
      await show(false);
      final regular = tester.getSize(find.byType(ClassBanner)).height;
      await show(true);
      expect(
        tester.getSize(find.byType(ClassBanner)).height,
        lessThan(regular),
      );
      expect(find.text('BSIT-3A'), findsOneWidget);
      expect(find.text('Andrea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
