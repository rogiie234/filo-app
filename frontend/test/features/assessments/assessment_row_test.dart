import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/assessment_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 5, 4);
  for (final state in ['draft', 'scheduled', 'open', 'closed']) {
    testWidgets('$state card separates primary results from menu editing', (
      tester,
    ) async {
      var results = 0, edits = 0;
      final draft = state == 'draft';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentRow(
                quiz: InstructorQuizSummary({
                  'id': 'quiz',
                  'class_id': 'class',
                  'title': 'Assessment title',
                  'type': state == 'closed' ? 'exam' : 'quiz',
                  'status': draft ? 'draft' : 'published',
                  'total_points': 12,
                  'question_count': 3,
                  'opens_at': now
                      .add(Duration(hours: state == 'scheduled' ? 1 : -2))
                      .toIso8601String(),
                  'closes_at': now
                      .add(Duration(hours: state == 'closed' ? -1 : 2))
                      .toIso8601String(),
                }),
                now: now,
                onOpen: draft ? null : () => results++,
                onEdit: () => edits++,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Assessment title'));
      await tester.pump();
      expect(results, draft ? 0 : 1);
      expect(edits, 0);
      expect(find.byType(Image), findsOneWidget);
      final artwork = tester.widget<Image>(find.byType(Image));
      expect((artwork.image as ResizeImage).image, isA<AssetImage>());
      expect(
        ((artwork.image as ResizeImage).image as AssetImage).assetName,
        'assets/illustrations/classwork-${state == 'closed' ? 'exam' : 'quiz'}.png',
      );
      final statusBounds = tester.getRect(find.byType(FiloStatusChip));
      final metadataBounds = tester.getRect(find.textContaining('3 questions'));
      expect(statusBounds.top, greaterThanOrEqualTo(metadataBounds.bottom));
      final opens = tester.getRect(find.text('Opens'));
      final closes = tester.getRect(find.text('Closes'));
      expect(opens.top, closes.top);
      expect(closes.left, greaterThan(opens.right));
      final closeColumn = tester.getRect(
        find
            .ancestor(of: find.text('Closes'), matching: find.byType(Column))
            .first,
      );
      expect(closes.left, closeColumn.left + 24);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FiloIcon && widget.icon == FiloIcons.calendar,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is FiloIcon && widget.icon == FiloIcons.clock,
        ),
        findsWidgets,
      );
      if (draft) {
        expect(find.text('Draft. Use the menu to edit.'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Assessment options'));
      await tester.pumpAndSettle();
      expect(find.text('Results'), findsNothing);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(edits, 1);
      expect(results, draft ? 0 : 1);
    });
  }
  testWidgets(
    'long title and unavailable count fit narrow enlarged-text cards',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentRow(
                  quiz: InstructorQuizSummary({
                    'id': 'quiz',
                    'class_id': 'class',
                    'title': 'A longer assessment title that should wrap without hiding the options menu',
                    'type': 'exam',
                    'status': 'draft',
                    'total_points': 0,
                  }),
                  now: now,
                  onOpen: null,
                  onEdit: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Question count unavailable'),
          findsOneWidget,
        );
        expect(find.byTooltip('Assessment options'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
