import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/assessment_form_screen.dart';
import 'package:filo/features/classes/application/class_providers.dart';

import 'support/unused_assessment_client.dart';

class StepRepository extends InstructorQuizRepository {
  StepRepository(AppDatabase database, SupabaseClient client)
    : super(database, client, 'owner', () => true);
  int saves = 0;
  @override
  Future<InstructorQuiz> save(
    QuizDraft draft, {
    void Function(String, String)? onQuestionProgress,
  }) async {
    saves++;
    final saved = InstructorQuiz({
      'id': 'quiz',
      'class_id': 'class',
      ...draft.settings,
    }, draft.questions);
    draft.acceptSaved(saved);
    return saved;
  }
}

void main() {
  testWidgets(
    'steps validate, retain unfinished input and save zero questions only on final page',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      });
      final room = await tester.runAsync(() async {
        await db.customStatement(
          "INSERT INTO cache_profiles(id,role,display_name) VALUES ('owner','instructor','Owner')",
        );
        await db.customStatement(
          "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','owner','Course','A','2026','ABC123')",
        );
        return (await db.select(db.cacheClasses).get()).single;
      });
      final repo = StepRepository(db, UnusedAssessmentClient());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            instructorQuizRepositoryProvider.overrideWith((ref) async => repo),
            classesProvider.overrideWith((ref) => Stream.value([room!])),
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AssessmentFormScreen(classId: 'class'),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Save draft'), findsNothing);
      await tester.tap(find.text('Next: Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Give your assessment a title.'), findsOneWidget);
      final titleInput = find.descendant(
        of: find.byKey(const ValueKey('title-0')),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(titleInput).focusNode.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('title-0')), 'My quiz');
      await tester.tap(find.text('Next: Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      final passing = find.byKey(const ValueKey('passing-0'));
      await tester.ensureVisible(passing);
      await tester.enterText(passing, '1.5');
      await tester.tap(find.text('Next: Questions'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      final passingInput = find.descendant(
        of: passing,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(passingInput).focusNode.hasFocus,
        isTrue,
      );
      expect(
        tester.getRect(passing).overlaps(tester.getRect(find.byType(Scaffold))),
        isTrue,
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('title-0')))
            .initialValue,
        'My quiz',
      );
      await tester.tap(find.text('Next: Settings'));
      await tester.pumpAndSettle();
      final passingField = tester.widget<TextFormField>(passing);
      expect(passingField.initialValue, '1.5');
      await tester.ensureVisible(passing);
      await tester.enterText(passing, '50');
      await tester.tap(find.text('Next: Questions'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('No questions yet.'), findsOneWidget);
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(
        find.text('Set the open and close time before publishing.'),
        findsWidgets,
      );
      expect(
        find.text('Add at least one question before publishing.'),
        findsWidgets,
      );
      expect(repo.saves, 0);
      expect(find.text('Publish this assessment?'), findsNothing);
      await tester.tap(find.byTooltip('Back to classwork'));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3'), findsOneWidget);
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(find.text('Step 3 of 3'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Save draft'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
