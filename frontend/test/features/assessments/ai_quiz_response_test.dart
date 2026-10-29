import 'package:filo/features/assessments/data/ai_quiz_response.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> response() => {
  'questions': [
    {
      'type': 'multiple_choice',
      'prompt': 'Choose',
      'points': 1,
      'explanation': 'Reason',
      'evidence': 'Source',
      'options': ['A', 'B', 'C', 'D'],
      'correct_index': 2,
    },
    {
      'type': 'true_false',
      'prompt': 'Statement',
      'points': 1,
      'explanation': 'Reason',
      'evidence': 'Source',
      'correct_boolean': false,
    },
    {
      'type': 'identification',
      'prompt': 'Name',
      'points': 1,
      'explanation': 'Reason',
      'evidence': 'Source',
      'accepted_answers': ['Name'],
    },
    {
      'type': 'essay',
      'prompt': 'Explain',
      'points': 2,
      'explanation': 'Reason',
      'evidence': 'Source',
      'sample_answer': 'Example',
      'rubric': [
        {'key_point': 'Criterion', 'points': 2},
      ],
    },
  ],
  'missing_by_type': {for (final t in aiQuestionTypes) t: 0},
  'dropped_by_type': {for (final t in aiQuestionTypes) t: 0},
};

void main() {
  final counts = {for (final t in aiQuestionTypes) t: 1};
  test('all formats map to save contract with independent local IDs', () {
    final questions = decodeAiQuestions(response(), counts);
    expect(questions.length, 4);
    expect(questions.map((q) => q.localId).toSet().length, 4);
    expect(questions.every((q) => q.aiGenerated), true);
    expect(questions.first.payload['correct_option_index'], 2);
    expect(questions.first.payload.containsKey('correct_index'), false);
    expect(questions.first.payload.containsKey('evidence'), false);
    expect(questions[1].answerKey!.correctBoolean, false);
  });
  test('partial counts remain honest', () {
    final data = response();
    (data['questions'] as List).removeLast();
    data['missing_by_type']['essay'] = 1;
    data['dropped_by_type']['essay'] = 1;
    expect(decodeAiQuestions(data, counts).length, 3);
  });
  test('bad rubric and mismatched missing counts reject entire addition', () {
    final data = response();
    data['questions'][3]['points'] = 3;
    expect(() => decodeAiQuestions(data, counts), throwsFormatException);
    final wrongCounts = response();
    wrongCounts['missing_by_type']['essay'] = 1;
    expect(() => decodeAiQuestions(wrongCounts, counts), throwsFormatException);
  });
  test('malformed MC and empty results are rejected', () {
    final data = response();
    data['questions'][0]['options'] = ['A'];
    expect(() => decodeAiQuestions(data, counts), throwsFormatException);
    expect(
      () => decodeAiQuestions({'questions': []}, counts),
      throwsFormatException,
    );
  });
}
