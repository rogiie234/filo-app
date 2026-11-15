import 'package:drift/native.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/application/ai_providers.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/ai_quiz_client.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/assessment_form_screen.dart';
import 'package:filo/features/assessments/presentation/ai_quiz_sheet.dart';
import 'package:filo/features/assessments/presentation/question_card.dart';
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
  int? savedQuestionCount;
  InstructorQuiz? stored;
  @override
  Future<InstructorQuiz> save(
    QuizDraft draft, {
    void Function(String localId, String status)? onQuestionProgress,
  }) async {
    saves++;
    if (reject) throw StateError('Draft save was not confirmed.');
    savedTitle = draft.settings['title'] as String;
    savedQuestionCount = draft.questions.length;
    final saved = InstructorQuiz({
      ...draft.settings,
      'id': 'quiz',
      'class_id': 'class',
      'status': 'draft',
    }, draft.questions);
    draft.acceptSaved(saved);
    stored = saved;
    return saved;
  }

  @override
  Future<AiDraftSaveReport> saveAiBatch(
    String classId,
    String quizId,
    List<QuizQuestion> questions,
    AiSourceContext? context,
  ) async {
    final saved = InstructorQuiz(stored!.row, [
      ...stored!.questions,
      for (var i = 0; i < questions.length; i++)
        QuizQuestion(
          localId: questions[i].localId,
          id: 'ai-$i',
          aiGenerated: true,
          payload: questions[i].payload,
        ),
    ]);
    stored = saved;
    return AiDraftSaveReport(saved, questions.length, 0, 0);
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
      expect(find.text('Back'), findsNothing);
      await tester.ensureVisible(find.text('Add question'));
      await tester.tap(find.text('Add question'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Multiple choice').last);
      await tester.pumpAndSettle();
      expect(find.text('1 question | 1 point'), findsOneWidget);
      await tester.pumpAndSettle();
      final generate = find.widgetWithText(FiloButton, 'Generate with AI');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      expect(repository.savedQuestionCount, reject ? isNull : 0);
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
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        final batch = AiGeneratedBatch(
          List.generate(
            5,
            (i) =>
                QuizQuestion.newQuestion('essay')
                  ..payload['prompt'] = 'AI question $i',
          ),
          const AiSourceContext(sources: [], difficulty: 'easy'),
          {},
          {},
        );
        Navigator.of(tester.element(find.byType(AiQuizSheet))).pop(batch);
        await tester.pumpAndSettle();
        expect(find.text('6 questions | 6 points'), findsOneWidget);
        final cards = tester
            .widgetList<QuestionCard>(find.byType(QuestionCard))
            .toList();
        expect(cards.first.question.prompt, isEmpty);
        expect(cards.first.question.type, 'multiple_choice');
        expect(
          cards.skip(1).every((card) => card.question.aiGenerated),
          isTrue,
        );
        await tester.ensureVisible(find.text('Save draft'));
        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();
        expect(repository.saves, 1);
        expect(find.text('6 questions | 6 points'), findsOneWidget);
        await tester.tap(find.text('Publish'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Question 1:'), findsWidgets);
        expect(find.text('Publish this assessment?'), findsNothing);
        expect(repository.saves, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
