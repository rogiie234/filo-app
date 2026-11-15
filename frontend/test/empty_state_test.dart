import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/features/grading/presentation/work_queue_screen.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final student in [true, false]) {
    for (final online in [true, false]) {
      testWidgets(
        'empty ${student ? 'student' : 'instructor'} online=$online workload does not claim completion',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                workQueueProvider(student).overrideWith(
                  (ref) => const WorkQueueData([], false, false, true),
                ),
                connectivityProvider.overrideWith(
                  (ref) => Stream.value(online),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                home: FiloMotionScope(
                  enabled: false,
                  child: Scaffold(
                    body: WorkQueueScreen(student: student, embedded: true),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              !online
                  ? 'No saved work'
                  : student
                  ? 'No work yet'
                  : 'No work to review',
            ),
            findsOneWidget,
          );
          expect(find.textContaining('caught up'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final variant in EmptyStateVariant.values) {
    testWidgets('$variant supports large text, actions and decorative art', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: EmptyState(
                variant: variant,
                title: 'No files yet',
                body: 'Add files to keep your study materials together on this device.',
                illustration: Semantics(
                  label: 'Decorative book',
                  child: const Icon(Icons.book),
                ),
                primaryAction: EmptyStateAction(
                  label: 'Add files',
                  onPressed: () => primary++,
                ),
                secondaryAction: EmptyStateAction(
                  label: 'Learn more',
                  onPressed: () => secondary++,
                ),
                children: const [Text('Available offline')],
              ),
            ),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Decorative book'), findsNothing);
      await tester.ensureVisible(find.text('Add files'));
      await tester.tap(find.text('Add files'));
      await tester.ensureVisible(find.text('Learn more'));
      await tester.tap(find.text('Learn more'));
      expect(primary, 1);
      expect(secondary, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  testWidgets('neutral state hides illustration and has no dead action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: EmptyState(
            title: 'No grades yet',
            body: 'Grades appear when your instructor returns them.',
            showMascot: false,
          ),
        ),
      ),
    );
    expect(find.byType(Mascot), findsNothing);
    expect(find.byType(FiloButton), findsNothing);
  });
}
