import 'quiz_draft.dart';

class BankQuestion {
  BankQuestion(Map<String, dynamic> row) : row = copyQuizJson(row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  QuizQuestion copyToQuiz() {
    final type = row['type'] as String;
    final options = (row['options'] as List? ?? []).cast<Map>();
    return QuizQuestion.newQuestion(type)
      ..payload.addAll({
        'type': type,
        'prompt': row['prompt'],
        'points': row['points'],
        'explanation': row['explanation'],
        if (type == 'multiple_choice') ...{
          'options': options.map((o) => o['text'] as String).toList(),
          'correct_option_index': options.indexWhere(
            (o) => o['is_correct'] == true,
          ),
        },
        if (type == 'true_false') 'correct_boolean': row['answer']['boolean'],
        if (type == 'identification')
          'accepted_answers': List<String>.from(
            row['answer']['accepted'] as List,
          ),
      });
  }

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
