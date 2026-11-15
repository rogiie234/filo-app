import 'package:flutter_test/flutter_test.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';

void main() {
  InstructorQuiz saved() => InstructorQuiz(
    {'id': 'quiz', 'class_id': 'class', 'title': 'Original'},
    [
      QuizQuestion(
        localId: 'a',
        id: 'a',
        payload: {
          'type': 'multiple_choice',
          'prompt': 'A',
          'points': 2,
          'options': ['One', 'Two'],
          'correct_option_index': 0,
        },
      ),
      QuizQuestion(
        localId: 'b',
        id: 'b',
        payload: {'type': 'essay', 'prompt': 'B', 'points': 3},
      ),
    ],
  );
  test(
    'settings and nested options revert to clean without changing saved data',
    () {
      final source = saved();
      final draft = QuizDraft(source);
      draft.settings['title'] = 'Edited';
      expect(draft.changes.settings, contains('title'));
      draft.settings['title'] = 'Original';
      expect(draft.isDirty, false);
      (draft.questions.first.payload['options'] as List)[0] = 'Changed';
      expect(draft.changes.edited, {'a'});
      expect((source.questions.first.payload['options'] as List).first, 'One');
      (draft.questions.first.payload['options'] as List)[0] = 'One';
      expect(draft.isDirty, false);
      draft.questions.first.payload['correct_option_index'] = 1;
      expect(draft.isDirty, true);
      draft.questions.first.payload['correct_option_index'] = 0;
      expect(draft.isDirty, false);
    },
  );
  test('ordering, additions, deletion and totals reflect current draft', () {
    final draft = QuizDraft(saved());
    expect(draft.totalPoints, 5);
    expect(draft.questionCount, 2);
    final first = draft.questions.removeAt(0);
    draft.questions.add(first);
    expect(draft.changes.ordering, true);
    draft.questions.removeWhere((q) => q.id == 'a');
    expect(draft.deletedQuestionIds, ['a']);
    final q = QuizQuestion.newQuestion('true_false');
    q.payload['correct_boolean'] = false;
    draft.questions.add(q);
    expect(draft.changes.added, {q.localId});
    expect(draft.totalPoints, 4);
    draft.acceptSaved(saved());
    expect(draft.isDirty, false);
  });
  test('new untouched draft is clean; save guard survives edits', () {
    final draft = QuizDraft.create('class');
    expect(draft.isDirty, false);
    draft.reconciliationRequired = true;
    draft.settings['title'] = 'New';
    expect(draft.reconciliationRequired, true);
    expect(draft.isDirty, true);
  });
  test('five confirmed AI questions append after unfinished manual question without losing it', () {
    final draft = QuizDraft.create('class');
    draft.settings['title'] = 'Lesson quiz';
    final manual = QuizQuestion.newQuestion('multiple_choice');
    draft.questions.add(manual);
    final row = {...draft.settings, 'id': 'quiz', 'class_id': 'class'};
    draft.mergeAiSaved(InstructorQuiz(row, []));
    final generated = List.generate(
      5,
      (index) => QuizQuestion(
        localId: 'ai-$index',
        id: 'ai-$index',
        aiGenerated: true,
        payload: {'type': 'essay', 'prompt': 'Generated $index', 'points': 1},
      ),
    );
    draft.mergeAiSaved(InstructorQuiz(row, generated));
    expect(draft.questionCount, 6);
    expect(identical(draft.questions.first, manual), isTrue);
    expect(
      draft.questions.skip(1).map((q) => q.id),
      generated.map((q) => q.id),
    );
    expect(manual.validationErrors(), isNotEmpty);
    expect(draft.isDirty, isTrue);
    draft.mergeAiSaved(InstructorQuiz(row, generated));
    expect(draft.questionCount, 6);
  });
  test(
    'AI reconciliation retains local settings, edits, deletions and order',
    () {
      final source = saved();
      final draft = QuizDraft(source);
      draft.settings['title'] = 'Unsaved title';
      draft.questions.removeAt(0);
      draft.questions.first.payload['prompt'] = '';
      final ai = QuizQuestion(
        localId: 'ai',
        id: 'ai',
        aiGenerated: true,
        payload: {'type': 'essay', 'prompt': 'AI draft', 'points': 1},
      );
      draft.mergeAiSaved(InstructorQuiz(source.row, [...source.questions, ai]));
      expect(draft.settings['title'], 'Unsaved title');
      expect(draft.questions.map((q) => q.id), ['b', 'ai']);
      expect(draft.questions.first.prompt, isEmpty);
      expect(draft.deletedQuestionIds, ['a']);
      expect(draft.isDirty, isTrue);
    },
  );
}
