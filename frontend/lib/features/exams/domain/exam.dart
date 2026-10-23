typedef ExamJson = Map<String, dynamic>;

class ExamAnswer {
  const ExamAnswer({
    required this.questionId,
    this.optionId,
    this.boolean,
    this.text,
  });
  final String questionId;
  final String? optionId;
  final bool? boolean;
  final String? text;
  factory ExamAnswer.fromJson(ExamJson json) => ExamAnswer(
    questionId: json['question_id'] as String,
    optionId: json['option_id'] as String?,
    boolean: json['bool_answer'] as bool?,
    text: json['text_answer'] as String?,
  );
  ExamJson params(String sessionId) => {
    'p_session': sessionId,
    'p_question': questionId,
    'p_option': optionId,
    'p_bool': boolean,
    'p_text': text,
  };
}

class ExamQuestion {
  ExamQuestion(this.json);
  final ExamJson json;
  String get id => json['id'] as String;
  String get type => json['type'] as String;
  String get prompt => json['prompt'] as String;
  int get points => json['points'] as int;
  List<ExamJson> get options => (json['options'] as List? ?? [])
      .map((e) => ExamJson.from(e as Map))
      .toList();
}

class ExamAttempt {
  ExamAttempt(this.json);
  final ExamJson json;
  String get sessionId => json['session_id'] as String;
  String get quizId => json['quiz_id'] as String;
  DateTime get startedAt =>
      DateTime.parse(json['started_at'] as String).toUtc();
  DateTime get deadline =>
      DateTime.parse(json['deadline_at'] as String).toUtc();
  DateTime get serverNow =>
      DateTime.parse(json['server_now'] as String).toUtc();
  List<ExamQuestion> get questions => (json['questions'] as List)
      .map((e) => ExamQuestion(ExamJson.from(e as Map)))
      .toList();
  List<ExamAnswer> get savedAnswers => (json['saved_answers'] as List? ?? [])
      .map((e) => ExamAnswer.fromJson(ExamJson.from(e as Map)))
      .toList();
}

class ExamSession {
  ExamSession(this.json);
  final ExamJson json;
  String get id => json['session_id'] as String;
  String get status => json['status'] as String;
  bool get inProgress => status == 'in_progress';
  bool get submitted => status == 'submitted' || status == 'auto_submitted';
  DateTime get deadline =>
      DateTime.parse(json['deadline_at'] as String).toUtc();
  DateTime get serverNow =>
      DateTime.parse(json['server_now'] as String).toUtc();
}

class StudentQuiz {
  StudentQuiz(this.json, this.session);
  final ExamJson json;
  final ExamSession? session;
  String get id => json['id'] as String;
  String get title => json['title'] as String;
  DateTime? get opensAt =>
      DateTime.tryParse(json['opens_at'] as String? ?? '')?.toUtc();
  DateTime? get closesAt =>
      DateTime.tryParse(json['closes_at'] as String? ?? '')?.toUtc();
  bool isOpen(DateTime now) =>
      (opensAt == null || !now.isBefore(opensAt!)) &&
      (closesAt == null || now.isBefore(closesAt!));
}
