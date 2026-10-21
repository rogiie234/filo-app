import 'dart:convert';

import 'package:uuid/uuid.dart';

Map<String, dynamic> copyQuizJson(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

// Compare maps independent of insertion order, preserving list order and nulls.
String _canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canonical(value[k])}').join(',')}}';
  }
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  return jsonEncode(value);
}

bool quizValuesEqual(dynamic a, dynamic b) => _canonical(a) == _canonical(b);

const quizSettingFields = [
  'title',
  'instructions',
  'type',
  'time_limit_minutes',
  'opens_at',
  'closes_at',
  'shuffle_questions',
  'shuffle_options',
  'show_correct_answers',
  'passing_percent',
];

class QuizOption {
  const QuizOption(this.id, this.text);
  final String id;
  final String text;
}

class QuizAnswerKey {
  const QuizAnswerKey({
    this.correctOptionIndex,
    this.correctBoolean,
    this.acceptedAnswers = const [],
  });
  final int? correctOptionIndex;
  final bool? correctBoolean;
  final List<String> acceptedAnswers;
}

class QuizQuestion {
  QuizQuestion({
    required this.localId,
    required Map<String, dynamic> payload,
    this.id,
    this.aiGenerated = false,
    this.options = const [],
  }) : payload = copyQuizJson(payload);
  final String localId;
  String? id;
  final bool aiGenerated;
  final List<QuizOption> options;

  /// Editable RPC-shaped content; MC keys are indexes, never stale option IDs.
  final Map<String, dynamic> payload;
  String get type => payload['type'] as String;
  String get prompt => payload['prompt'] as String;
  int get points => payload['points'] as int;
  String? get explanation => payload['explanation'] as String?;
  List<String> get optionTexts =>
      List<String>.unmodifiable(payload['options'] as List? ?? []);
  QuizAnswerKey? get answerKey => type == 'essay'
      ? null
      : QuizAnswerKey(
          correctOptionIndex: payload['correct_option_index'] as int?,
          correctBoolean: payload['correct_boolean'] as bool?,
          acceptedAnswers: List<String>.unmodifiable(
            payload['accepted_answers'] as List? ?? [],
          ),
        );
  factory QuizQuestion.newQuestion(String type) => QuizQuestion(
    localId: const Uuid().v4(),
    payload: {'type': type, 'prompt': '', 'points': 1},
  );
  QuizQuestion copy() => QuizQuestion(
    localId: localId,
    id: id,
    payload: payload,
    aiGenerated: aiGenerated,
    options: List.unmodifiable(options),
  );
  Map<String, dynamic> toJson() => {
    'local_id': localId,
    'id': id,
    'payload': payload,
    'ai_generated': aiGenerated,
    'options': options.map((o) => {'id': o.id, 'text': o.text}).toList(),
  };
  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    localId: json['local_id'] as String,
    id: json['id'] as String?,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    aiGenerated: json['ai_generated'] == true,
    options: (json['options'] as List? ?? [])
        .map((o) => QuizOption(o['id'] as String, o['text'] as String))
        .toList(),
  );
}

/// Typed metadata used by the instructor class list (contains no answer keys).
class InstructorQuizSummary {
  InstructorQuizSummary(Map<String, dynamic> row)
    : row = Map.unmodifiable(copyQuizJson(row));
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String get classId => row['class_id'] as String;
  String get title => row['title'] as String;
  String get type => row['type'] as String;
  String get status => row['status'] as String;
  int get totalPoints => row['total_points'] as int;
  int? get questionCount => row['question_count'] as int?;
  DateTime? get createdAt => _instant(row['created_at']);
  bool get locked => row['locked_at'] != null;
  DateTime? get opensAt => _instant(row['opens_at']);
  DateTime? get closesAt => _instant(row['closes_at']);
}

DateTime? _instant(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

class QuizSettings {
  QuizSettings(Map<String, dynamic> value)
    : value = Map.unmodifiable(copyQuizJson(value));
  final Map<String, dynamic> value;
  String get title => value['title'] as String;
  String? get instructions => value['instructions'] as String?;
  String get type => value['type'] as String;
  int get timeLimitMinutes => value['time_limit_minutes'] as int;
  bool get shuffleQuestions => value['shuffle_questions'] as bool;
  bool get shuffleOptions => value['shuffle_options'] as bool;
  bool get showCorrectAnswers => value['show_correct_answers'] as bool;
  int? get passingPercent => value['passing_percent'] as int?;
  DateTime? get opensAt => _instant(value['opens_at']);
  DateTime? get closesAt => _instant(value['closes_at']);
}

class InstructorQuiz {
  InstructorQuiz(Map<String, dynamic> row, List<QuizQuestion> questions)
    : row = Map.unmodifiable(copyQuizJson(row)),
      questions = List.unmodifiable(questions.map((q) => q.copy()));
  final Map<String, dynamic> row;
  final List<QuizQuestion> questions;
  String get id => row['id'] as String;
  String get classId => row['class_id'] as String;
  bool get locked => row['locked_at'] != null;
  QuizSettings get settings => QuizSettings(row);
  int get questionCount => questions.length;
  int get totalPoints =>
      questions.fold(0, (sum, q) => sum + (q.payload['points'] as int));
  Map<String, dynamic> toJson() => {
    'row': row,
    'questions': questions.map((q) => q.toJson()).toList(),
  };
  factory InstructorQuiz.fromJson(Map<String, dynamic> json) => InstructorQuiz(
    Map<String, dynamic>.from(json['row'] as Map),
    (json['questions'] as List)
        .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
        .toList(),
  );
}

class QuizChanges {
  const QuizChanges(
    this.settings,
    this.added,
    this.edited,
    this.deleted,
    this.ordering,
  );
  final Set<String> settings, added, edited, deleted;
  final bool ordering;
  bool get isDirty =>
      settings.isNotEmpty ||
      added.isNotEmpty ||
      edited.isNotEmpty ||
      deleted.isNotEmpty ||
      ordering;
}

class QuizDraft {
  QuizDraft(InstructorQuiz saved)
    : _baseline = InstructorQuiz.fromJson(saved.toJson()),
      id = saved.id,
      classId = saved.classId,
      settings = {
        for (final k in quizSettingFields) k: copyQuizJson(saved.row)[k],
      },
      questions = saved.questions.map((q) => q.copy()).toList(),
      locked = saved.locked;
  QuizDraft.create(this.classId)
    : id = null,
      _baseline = null,
      locked = false,
      settings = {
        'title': '',
        'instructions': null,
        'type': 'quiz',
        'time_limit_minutes': 30,
        'opens_at': null,
        'closes_at': null,
        'shuffle_questions': true,
        'shuffle_options': true,
        'show_correct_answers': true,
        'passing_percent': null,
      },
      questions = [] {
    _newSettings = copyQuizJson(settings);
  }
  InstructorQuiz? _baseline;
  Map<String, dynamic>? _newSettings;
  String? id;
  final String classId;
  bool locked;
  bool reconciliationRequired = false;

  /// Changes while a request is in flight must never be silently discarded.
  Map<String, dynamic> get editSnapshot => {
    'settings': copyQuizJson(settings),
    'questions': [
      for (final q in questions)
        {'local_id': q.localId, 'payload': copyQuizJson(q.payload)},
    ],
  };
  final Map<String, dynamic> settings;
  final List<QuizQuestion> questions;
  int get questionCount => questions.length;
  int get totalPoints =>
      questions.fold(0, (sum, q) => sum + (q.payload['points'] as int? ?? 0));
  QuizChanges get changes {
    final previous = {
      for (final q in _baseline?.questions ?? <QuizQuestion>[]) q.localId: q,
    };
    final current = {for (final q in questions) q.localId: q};
    final baseSettings = _baseline?.row ?? _newSettings!;
    return QuizChanges(
      {
        for (final k in quizSettingFields)
          if (!quizValuesEqual(settings[k], baseSettings[k])) k,
      },
      current.keys.toSet().difference(previous.keys.toSet()),
      {
        for (final k in current.keys)
          if (previous.containsKey(k) &&
              !quizValuesEqual(current[k]!.payload, previous[k]!.payload))
            k,
      },
      previous.keys.toSet().difference(current.keys.toSet()),
      !quizValuesEqual(previous.keys.toList(), current.keys.toList()),
    );
  }

  bool get isDirty => changes.isDirty;
  List<String> get deletedQuestionIds => [
    for (final q in _baseline?.questions ?? <QuizQuestion>[])
      if (!questions.any((current) => current.localId == q.localId) &&
          q.id != null)
        q.id!,
  ];
  void acceptSaved(InstructorQuiz saved) {
    _baseline = InstructorQuiz.fromJson(saved.toJson());
    id = saved.id;
    locked = saved.locked;
    settings
      ..clear()
      ..addAll({
        for (final k in quizSettingFields) k: copyQuizJson(saved.row)[k],
      });
    questions
      ..clear()
      ..addAll(saved.questions.map((q) => q.copy()));
    reconciliationRequired = false;
  }
}
