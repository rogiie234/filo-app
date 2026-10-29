import 'package:uuid/uuid.dart';

import '../domain/quiz_draft.dart';

const aiQuestionTypes = [
  'multiple_choice',
  'true_false',
  'identification',
  'essay',
];

/// Converts provider-facing keys into the existing assessment save contract.
List<QuizQuestion> decodeAiQuestions(
  dynamic value,
  Map<String, int> requested,
) {
  if (value is! Map || value['questions'] is! List)
    throw const FormatException();
  final questions = <QuizQuestion>[];
  final counts = {for (final type in aiQuestionTypes) type: 0};
  for (final item in value['questions'] as List) {
    if (item is! Map || !aiQuestionTypes.contains(item['type'])) {
      throw const FormatException();
    }
    final type = item['type'] as String;
    counts[type] = counts[type]! + 1;
    if (counts[type]! > (requested[type] ?? 0) ||
        item['prompt'] is! String ||
        item['points'] is! int ||
        item['explanation'] is! String ||
        item['evidence'] is! String ||
        (item['explanation'] as String).trim().isEmpty ||
        (item['evidence'] as String).trim().isEmpty) {
      throw const FormatException();
    }
    final question = QuizQuestion(
      localId: const Uuid().v4(),
      aiGenerated: true,
      payload: {
        'type': type,
        'prompt': item['prompt'],
        'points': item['points'],
        'explanation': item['explanation'],
        if (type == 'multiple_choice') ...{
          'options': item['options'],
          'correct_option_index': item['correct_index'],
        },
        if (type == 'true_false') 'correct_boolean': item['correct_boolean'],
        if (type == 'identification')
          'accepted_answers': item['accepted_answers'],
      },
    );
    if (question.validationErrors().isNotEmpty ||
        (type == 'multiple_choice' && question.optionTexts.length != 4)) {
      throw const FormatException();
    }
    if (type == 'essay') {
      final rubric = item['rubric'];
      if (item['sample_answer'] is! String ||
          (item['sample_answer'] as String).trim().isEmpty ||
          rubric is! List ||
          rubric.isEmpty ||
          rubric.any(
            (r) =>
                r is! Map ||
                r['key_point'] is! String ||
                (r['key_point'] as String).trim().isEmpty ||
                r['points'] is! int ||
                (r['points'] as int) < 1,
          ) ||
          rubric.fold<int>(0, (n, r) => n + (r['points'] as int)) !=
              item['points']) {
        throw const FormatException();
      }
    }
    questions.add(question);
  }
  if (questions.isEmpty) throw const FormatException();
  for (final field in ['missing_by_type', 'dropped_by_type']) {
    if (value[field] is! Map) throw const FormatException();
    for (final type in aiQuestionTypes) {
      final count = value[field][type];
      if (count is! int ||
          count < 0 ||
          (field == 'missing_by_type' &&
              count != requested[type]! - counts[type]!)) {
        throw const FormatException();
      }
    }
  }
  return questions;
}
