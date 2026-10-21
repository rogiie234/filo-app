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
}
