import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/question_card.dart';

void main() {
  QuizQuestion question(String type) =>
      QuizQuestion.newQuestion(type)..payload['prompt'] = 'Question';
  testWidgets(
    'question validation reveals and focuses the specific invalid field',
    (tester) async {
      final q = question('essay');
      final editor = QuestionEditorState(q)
        ..points = ''
        ..errors = {'points': 'Enter a whole number from 1 to 1000.'};
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 800),
                  QuestionCard(
                    key: key,
                    question: q,
                    editor: editor,
                    index: 0,
                    expanded: true,
                    enabled: true,
                    onToggle: () {},
                    onChanged: () {},
                    onAction: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final reveal = revealQuestionError(key.currentContext!, editor.errors);
      await tester.pumpAndSettle();
      await reveal;
      final points = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Points',
      );
      expect(tester.widget<TextField>(points).focusNode!.hasFocus, isTrue);
      expect(
        tester.getRect(points).overlaps(tester.getRect(find.byType(Scaffold))),
        isTrue,
      );
    },
  );
  testWidgets(
    'card edits clear saved status and disabled saves retain errors',
    (tester) async {
      final q = question('essay')..id = 'saved';
      final state = QuestionEditorState(q);
      Widget card(bool enabled) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuestionCard(
              question: q,
              editor: state,
              index: 0,
              expanded: true,
              enabled: enabled,
              onToggle: () {},
              onChanged: () {},
              onAction: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(card(true));
      expect(find.text('Saved'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Edited');
      await tester.pump();
      expect(q.prompt, 'Edited');
      expect(find.text('Unsaved changes'), findsOneWidget);
      state.status = 'Save not confirmed';
      state.errors = {'prompt': 'Review this question.'};
      await tester.pumpWidget(card(false));
      expect(find.text('Save not confirmed'), findsOneWidget);
      expect(find.text('Review this question.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
    },
  );
  test('all types validate their keys and common boundaries', () {
    final mc = question('multiple_choice');
    expect(mc.optionTexts, ['', '']);
    expect(mc.validationErrors(), contains('answer'));
    mc.payload.addAll({
      'options': ['A', 'B'],
      'correct_option_index': 0,
    });
    expect(mc.validationErrors(), isEmpty);
    mc.payload['options'] = List.filled(10, 'x' * 500);
    expect(mc.validationErrors(), isEmpty);
    mc.payload['options'] = List.filled(11, 'A');
    expect(mc.validationErrors(), contains('answer'));
    final tf = question('true_false');
    expect(tf.validationErrors(), contains('answer'));
    tf.payload['correct_boolean'] = false;
    expect(tf.validationErrors(), isEmpty);
    final identification = question('identification');
    expect(identification.validationErrors(), contains('answer'));
    identification.payload['accepted_answers'] = List.filled(10, 'Answer');
    expect(identification.validationErrors(), isEmpty);
    expect(
      identification.validationErrors(pendingAnswer: 'unfinished'),
      contains('answer'),
    );
    identification.payload['accepted_answers'] = List.filled(11, 'Answer');
    expect(identification.validationErrors(), contains('answer'));
    final essay = question('essay');
    expect(essay.answerKey, isNull);
    for (final points in ['0', '1001', '1.5', '']) {
      expect(essay.validationErrors(pointsText: points), contains('points'));
    }
    for (final points in ['1', '1000']) {
      expect(essay.validationErrors(pointsText: points), isEmpty);
    }
    essay.payload['prompt'] = 'x' * 1000;
    essay.payload['explanation'] = 'x' * 500;
    expect(essay.validationErrors(), isEmpty);
    essay.payload['prompt'] = 'x' * 1001;
    essay.payload['explanation'] = 'x' * 501;
    expect(
      essay.validationErrors().keys,
      containsAll(['prompt', 'explanation']),
    );
  });
  test('removing options shifts or clears the correct key, stops at two', () {
    final q = question('multiple_choice')
      ..payload.addAll({
        'options': ['A', 'B', 'C', 'D'],
        'correct_option_index': 2,
      });
    q.removeOption(0);
    expect(q.answerKey!.correctOptionIndex, 1);
    q.removeOption(1);
    expect(q.answerKey!.correctOptionIndex, isNull);
    q.removeOption(0);
    expect(q.optionTexts, ['B', 'D']);
  });
  test('duplicates have independent content and fresh identities', () {
    final q = QuizQuestion(
      localId: 'local',
      id: 'server',
      aiGenerated: true,
      payload: {
        'type': 'multiple_choice',
        'prompt': 'Q',
        'points': 1,
        'options': ['A', 'B'],
        'correct_option_index': 0,
      },
    );
    final copy = q.duplicate();
    expect(copy.id, isNull);
    expect(copy.localId, isNot(q.localId));
    expect(copy.aiGenerated, isTrue);
    expect(copy.options, isEmpty);
    (copy.payload['options'] as List)[0] = 'Changed';
    expect(q.optionTexts.first, 'A');
  });
  test('reorder and refreshed IDs preserve identities and clean baseline', () {
    final draft = QuizDraft.create('class');
    final a = question('essay')..id = 'a';
    final b = question('essay')..id = 'b';
    draft.questions.addAll([a, b]);
    draft.questions.insert(0, draft.questions.removeAt(1));
    final saved = InstructorQuiz(
      {'id': 'quiz', 'class_id': 'class', ...draft.settings},
      [
        QuizQuestion(localId: 'b', id: 'b', payload: b.payload),
        QuizQuestion(localId: 'a', id: 'a', payload: a.payload),
      ],
    );
    draft.reconciliationRequired = true;
    draft.acceptSaved(saved);
    expect(draft.questions.map((q) => q.localId), [b.localId, a.localId]);
    expect(draft.isDirty, isFalse);
    expect(draft.reconciliationRequired, isFalse);
  });
  test('editor state retains incomplete input outside card lifetime', () {
    final q = question('identification');
    final state = QuestionEditorState(q)
      ..points = '1.5'
      ..pendingAnswer = 'Answer'
      ..status = 'Save not confirmed';
    expect(
      q
          .validationErrors(
            pointsText: state.points,
            pendingAnswer: state.pendingAnswer,
          )
          .keys,
      containsAll(['points', 'answer']),
    );
    expect(state.status, 'Save not confirmed');
    expect(state.pendingAnswer, 'Answer');
  });
}
