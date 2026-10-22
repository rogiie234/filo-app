import 'package:flutter_test/flutter_test.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/domain/quiz_publish.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22);
  test('publish reports missing schedule and questions together', () {
    final draft = QuizDraft.create('class');
    expect(quizPublishProblems(draft, now).map((p) => p.page), [1, 2]);
  });
  test('close is exclusive, future, and strictly after opening', () {
    final draft = QuizDraft.create('class');
    draft.questions.add(
      QuizQuestion.newQuestion('essay')..payload['prompt'] = 'Explain',
    );
    draft.settings['opens_at'] = now
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    draft.settings['closes_at'] = now.toIso8601String();
    expect(quizPublishProblems(draft, now), hasLength(1));
    draft.settings['closes_at'] = now
        .add(const Duration(hours: 1))
        .toIso8601String();
    expect(quizPublishProblems(draft, now), isEmpty);
    draft.settings['opens_at'] = draft.settings['closes_at'];
    expect(quizPublishProblems(draft, now), hasLength(1));
  });
  test('essay needs no key and false is a valid answer', () {
    final essay = QuizQuestion.newQuestion('essay')
      ..payload['prompt'] = 'Explain';
    final tf = QuizQuestion.newQuestion('true_false')
      ..payload['prompt'] = 'Statement'
      ..payload['correct_boolean'] = false;
    expect(essay.validationErrors(), isEmpty);
    expect(tf.validationErrors(), isEmpty);
    tf.payload.remove('correct_boolean');
    expect(tf.validationErrors(), contains('answer'));
  });
  test('summary independently pluralizes counts', () {
    final draft = QuizDraft.create('class');
    draft.settings['time_limit_minutes'] = 1;
    draft.questions.add(QuizQuestion.newQuestion('essay'));
    expect(
      quizPublishSummary(draft),
      '1 question, 1 point, 1 minute. Students will be notified.',
    );
    draft.questions.add(QuizQuestion.newQuestion('essay'));
    expect(
      quizPublishSummary(draft),
      startsWith('2 questions, 2 points, 1 minute.'),
    );
  });
  test('server validation and lock errors use friendly copy', () {
    expect(
      quizFriendlyError('1 question(s) are missing a valid answer key'),
      startsWith('1 question is'),
    );
    expect(
      quizFriendlyError('3 question(s) are missing a valid answer key'),
      startsWith('3 questions are'),
    );
    expect(
      quizFriendlyError('constraint quiz_window'),
      contains('future and after'),
    );
    expect(
      quizFriendlyError('This quiz has already been started by a student'),
      contains('Only the title'),
    );
    expect(
      quizFriendlyError('A started quiz cannot be deleted'),
      contains('cannot be deleted'),
    );
    expect(quizFriendlyError('This class is archived'), contains('read-only'));
    expect(quizFriendlyError('Not allowed'), contains('permission'));
    expect(
      quizFriendlyError('raw internal exception'),
      isNot(contains('raw internal')),
    );
  });
}
