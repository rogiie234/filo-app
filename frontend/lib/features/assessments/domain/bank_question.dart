import 'quiz_draft.dart';

class BankQuestion {
  BankQuestion(Map<String, dynamic> row) : row = copyQuizJson(row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String? get course => row['course'] as String?;
  // shortcut: normalized names identify courses; use stable IDs if a course catalogue is introduced.
  String? get courseKey => course?.trim().toLowerCase();
  static const invalidContentMessage =
      'This saved question has invalid content. Delete it and save a new copy.';

  QuizQuestion? tryCopyToQuiz() {
    final type = row['type'];
    if (![
          'multiple_choice',
          'true_false',
          'identification',
          'essay',
        ].contains(type) ||
        row['prompt'] is! String ||
        row['points'] is! int ||
        (row['explanation'] != null && row['explanation'] is! String))
      return null;
    final payload = <String, dynamic>{
      'type': type,
      'prompt': row['prompt'],
      'points': row['points'],
      'explanation': row['explanation'],
    };
    if (type == 'multiple_choice') {
      final options = row['options'];
      if (options is! List ||
          options.any(
            (o) =>
                o is! Map || o['text'] is! String || o['is_correct'] is! bool,
          ) ||
          options.where((o) => o['is_correct'] == true).length != 1)
        return null;
      payload['options'] = options.map((o) => o['text'] as String).toList();
      payload['correct_option_index'] = options.indexWhere(
        (o) => o['is_correct'] == true,
      );
    } else if (type == 'true_false') {
      final answer = row['answer'];
      if (answer is! Map || answer['boolean'] is! bool) return null;
      payload['correct_boolean'] = answer['boolean'];
    } else if (type == 'identification') {
      final answer = row['answer'];
      if (answer is! Map || answer['accepted'] is! List) return null;
      final accepted = answer['accepted'] as List;
      if (accepted.any((a) => a is! String)) return null;
      payload['accepted_answers'] = List<String>.from(accepted);
    }
    final question = QuizQuestion.newQuestion(type as String)
      ..payload.addAll(payload);
    return question.validationErrors().isEmpty ? question : null;
  }

  QuizQuestion copyToQuiz() =>
      tryCopyToQuiz() ?? (throw StateError(invalidContentMessage));

  static Map<String, dynamic> content(QuizQuestion q) => copyQuizJson({
    'type': q.type,
    'prompt': q.prompt,
    'points': q.points,
    'explanation': q.explanation,
    'options': q.type == 'multiple_choice'
        ? [
            for (var i = 0; i < q.optionTexts.length; i++)
              {
                'text': q.optionTexts[i],
                'is_correct': i == q.answerKey?.correctOptionIndex,
              },
          ]
        : null,
    'answer': switch (q.type) {
      'true_false' => {'boolean': q.answerKey!.correctBoolean},
      'identification' => {'accepted': q.answerKey!.acceptedAnswers},
      _ => null,
    },
  });
}
