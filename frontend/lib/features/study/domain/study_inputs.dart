class StudyLimitExceeded implements Exception {
  const StudyLimitExceeded(this.resource, this.limit);
  final String resource;
  final int limit;
  @override
  String toString() => 'StudyLimitExceeded($resource, $limit)';
}

void requireStudyText(String value, String field, {int? max}) {
  if (value.trim().isEmpty || (max != null && value.runes.length > max)) {
    throw ArgumentError.value(value, field, 'Invalid study text');
  }
}

const studyQuestionTypes = {'multiple_choice', 'true_false', 'identification'};

class StudyDeckSettings {
  const StudyDeckSettings({required this.count, this.topicFocus = ''});
  final int count;
  final String topicFocus;
  void validate() {
    if (count < 5 || count > 30 || topicFocus.runes.length > 200) {
      throw ArgumentError('Invalid deck settings');
    }
  }

  Map<String, Object> toJson() => {'count': count, 'topic_focus': topicFocus};
}

class StudyQuizSettings {
  const StudyQuizSettings({
    required this.count,
    required this.types,
    this.topicFocus = '',
  });
  final int count;
  final List<String> types;
  final String topicFocus;
  void validate() {
    if (![5, 10, 15, 20].contains(count) ||
        types.isEmpty ||
        types.toSet().length != types.length ||
        !types.every(studyQuestionTypes.contains) ||
        topicFocus.runes.length > 200) {
      throw ArgumentError('Invalid quiz settings');
    }
  }

  Map<String, Object> toJson() => {
    'count': count,
    'types': types,
    'topic_focus': topicFocus,
  };
}

class StudyCardInput {
  const StudyCardInput({required this.front, required this.back});
  final String front, back;
  void validate() {
    requireStudyText(front, 'front', max: 200);
    requireStudyText(back, 'back', max: 500);
  }
}

class StudyQuestionInput {
  const StudyQuestionInput({
    required this.type,
    required this.prompt,
    required this.explanation,
    this.options,
    this.correctIndex,
    this.correctBoolean,
    this.acceptedAnswers,
  });
  final String type, prompt, explanation;
  final List<String>? options, acceptedAnswers;
  final int? correctIndex;
  final bool? correctBoolean;

  void validate() {
    requireStudyText(prompt, 'prompt', max: 1000);
    requireStudyText(explanation, 'explanation', max: 500);
    switch (type) {
      case 'multiple_choice':
        if (options?.length != 4 ||
            correctIndex == null ||
            correctIndex! < 0 ||
            correctIndex! > 3 ||
            correctBoolean != null ||
            acceptedAnswers != null) {
          throw ArgumentError('Invalid multiple-choice answer');
        }
        for (final option in options!) {
          requireStudyText(option, 'option', max: 500);
        }
        if (options!.map((s) => s.trim().toLowerCase()).toSet().length != 4) {
          throw ArgumentError('Options must be distinct');
        }
      case 'true_false':
        if (correctBoolean == null ||
            options != null ||
            correctIndex != null ||
            acceptedAnswers != null) {
          throw ArgumentError('Invalid true/false answer');
        }
      case 'identification':
        if (acceptedAnswers == null ||
            acceptedAnswers!.isEmpty ||
            acceptedAnswers!.length > 10 ||
            options != null ||
            correctIndex != null ||
            correctBoolean != null) {
          throw ArgumentError('Invalid identification answer');
        }
        for (final answer in acceptedAnswers!) {
          requireStudyText(answer, 'accepted answer', max: 200);
        }
      default:
        throw ArgumentError.value(type, 'type');
    }
  }
}

/// The study player supplies confirmed per-question outcomes; storage does not grade.
class StudyQuestionResult {
  const StudyQuestionResult({
    required this.questionId,
    required this.answer,
    required this.correct,
  });
  final String questionId;
  final Object answer;
  final bool correct;
  Map<String, Object> toJson() => {
    'question_id': questionId,
    'answer': answer,
    'correct': correct,
  };
}
