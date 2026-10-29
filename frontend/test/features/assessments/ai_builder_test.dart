import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/application/ai_providers.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/assessment_form_screen.dart';
import 'package:filo/features/assessments/presentation/ai_quiz_sheet.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/unused_assessment_client.dart';

class DraftGateRepository extends InstructorQuizRepository {
  DraftGateRepository(AppDatabase db, SupabaseClient client)
    : super(db, client, 'owner', () => true);
  int saves = 0;
  bool reject = false;
  String? savedTitle;
  @override
  Future<InstructorQuiz> save(
    QuizDraft draft, {
    void Function(String localId, String status)? onQuestionProgress,
  }) async {
    saves++;
    if (reject) throw StateError('Draft save was not confirmed.');
    savedTitle = draft.settings['title'] as String;
    final saved = InstructorQuiz({
      ...draft.settings,
      'id': 'quiz',
      'class_id': 'class',
      'status': 'draft',
    }, draft.questions);
    draft.acceptSaved(saved);
    return saved;
  }
}

void main() {
  for (final reject in [false, true]) {
    testWidgets('AI opens only after titled draft save: reject=$reject', (
      tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      });
      final rooms = await tester.runAsync(() async {
        await db.customStatement(
          "INSERT INTO cache_profiles(id,role,display_name) VALUES('owner','instructor','Owner')",
        );
        await db.customStatement(
          "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES('class','owner','Course','A','2026','ABC123')",
        );
        return db.select(db.cacheClasses).get();
      });
      final repository = DraftGateRepository(db, UnusedAssessmentClient())
        ..reject = reject;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            instructorQuizRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            fileTextCacheProvider.overrideWith(
              (ref) async => FileTextCache(db),
            ),
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            classesProvider.overrideWith((ref) => Stream.value(rooms!)),
            classFilesProvider('class')
                .overrideWith((ref) => Stream.value(<ClassFileEntry>[])),
          ],
          child: const MaterialApp(
            home: AssessmentFormScreen(classId: 'class'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Lesson quiz');
      await tester.tap(find.text('Next: Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: Questions'));
      await tester.pumpAndSettle();
      final generate = find.widgetWithText(OutlinedButton, 'Generate with AI');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      if (reject) {
        expect(find.byType(AiQuizSheet), findsNothing);
        expect(
          find.textContaining(
            'Could not complete this change. Your edits are still here.',
          ),
          findsOneWidget,
        );
      } else {
        expect(repository.savedTitle, 'Lesson quiz');
        expect(find.byType(AiQuizSheet), findsOneWidget);
        expect(find.text('Before using AI'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
