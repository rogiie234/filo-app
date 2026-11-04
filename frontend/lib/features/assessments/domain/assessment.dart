import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Philippine civil time, independent of the device's configured time zone.
/// UTC values returned by [inManila] carry wall-clock components only.
DateTime inManila(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));
DateTime manilaToUtc(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 8));

String assessmentDate(DateTime? instant) {
  if (instant == null) return 'Not set';
  final d = inManila(instant);
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.month}/${d.day}/${d.year}, $hour:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'} PHT';
}

enum AssessmentStatus {
  draft('Draft'),
  scheduled('Scheduled'),
  open('Open'),
  closed('Closed');

  const AssessmentStatus(this.label);
  final String label;
}

AssessmentStatus? assessmentStatus(Map<String, dynamic> row, DateTime now) {
  if (row['status'] == 'draft') return AssessmentStatus.draft;
  if (row['status'] != 'published') return null;
  final opens = DateTime.tryParse(row['opens_at']?.toString() ?? '');
  final closes = DateTime.tryParse(row['closes_at']?.toString() ?? '');
  if (opens == null || closes == null || !closes.isAfter(opens)) return null;
  if (!now.isBefore(closes)) return AssessmentStatus.closed;
  return now.isBefore(opens)
      ? AssessmentStatus.scheduled
      : AssessmentStatus.open;
}

const questionTypes = {
  'multiple_choice': 'Multiple choice',
  'true_false': 'True or false',
  'identification': 'Identification',
  'essay': 'Essay',
};
const questionHints = {
  'multiple_choice': 'Add answer options and pick one correct option.',
  'true_false': 'Choose whether the correct answer is True or False.',
  'identification': 'Add every spelling you accept. Capital letters and extra spaces are ignored.',
  'essay': 'You grade this by hand after the quiz.',
};

class QuestionDraft {
  QuestionDraft({
    String? localKey,
    this.id,
    this.type = 'multiple_choice',
    this.prompt = '',
    this.points = 1,
    this.explanation = '',
    this.aiGenerated = false,
    List<String>? options,
    this.correctIndex,
    this.correctBoolean,
    List<String>? accepted,
  }) : localKey = localKey ?? const Uuid().v4(),
       options = options ?? ['', ''],
       accepted = accepted ?? [];
  final String localKey;
  String? id;
  String type, prompt, explanation;
  int points;
  bool aiGenerated;
  List<String> options, accepted;
  int? correctIndex;
  bool? correctBoolean;
  String? savedFingerprint, error;
  bool expanded = true;

  factory QuestionDraft.fromRow(Map<String, dynamic> row) {
    final options =
        (row['question_options'] as List? ?? [])
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList()
          ..sort(
            (a, b) => (a['position'] as int).compareTo(b['position'] as int),
          );
    final rawKey = row['answer_keys'];
    final key = rawKey is List
        ? (rawKey.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(rawKey.first as Map))
        : rawKey is Map
        ? Map<String, dynamic>.from(rawKey)
        : <String, dynamic>{};
    final selected = options.indexWhere(
      (o) => o['id'] == key['correct_option_id'],
    );
    final q = QuestionDraft(
      id: row['id'] as String?,
      type: row['type'] as String,
      prompt: row['prompt'] as String,
      points: row['points'] as int,
      explanation: row['explanation'] as String? ?? '',
      aiGenerated: row['ai_generated'] == true,
      options: options.map((o) => o['text'] as String).toList(),
      correctIndex: selected < 0 ? null : selected,
      correctBoolean: key['correct_boolean'] as bool?,
      accepted: List<String>.from(key['accepted_answers'] as List? ?? []),
    );
    q.savedFingerprint = q.fingerprint;
    q.expanded = false;
    return q;
  }

  Map<String, dynamic> payload(int position) => {
    'id': id,
    'type': type,
    'prompt': prompt,
    'points': points,
    'position': position,
    'explanation': explanation.isEmpty ? null : explanation,
    if (type == 'multiple_choice') ...{
      'options': options,
      'correct_option_index': correctIndex,
    },
    if (type == 'true_false') 'correct_boolean': correctBoolean,
    if (type == 'identification') 'accepted_answers': accepted,
  };
  String get fingerprint {
    final p = payload(0)..remove('id');
    return jsonEncode(p);
  }

  bool get dirty => id == null || fingerprint != savedFingerprint;
  QuestionDraft duplicate() => QuestionDraft(
    type: type,
    prompt: prompt,
    points: points,
    explanation: explanation,
    aiGenerated: false,
    options: List.of(options),
    correctIndex: correctIndex,
    correctBoolean: correctBoolean,
    accepted: List.of(accepted),
  );
  List<String> validate() => [
    if (prompt.trim().isEmpty || prompt.runes.length > 1000)
      'Enter a question of 1 to 1000 characters.',
    if (points < 1 || points > 1000) 'Enter whole points from 1 to 1000.',
    if (explanation.runes.length > 500)
      'Keep the explanation within 500 characters.',
    if (type == 'multiple_choice' &&
        (options.length < 2 ||
            options.length > 10 ||
            options.any((o) => o.trim().isEmpty || o.runes.length > 500)))
      'Add 2 to 10 nonblank options, up to 500 characters each.',
    if (type == 'multiple_choice' &&
        (correctIndex == null ||
            correctIndex! < 0 ||
            correctIndex! >= options.length))
      'Pick one correct option.',
    if (type == 'true_false' && correctBoolean == null)
      'Choose the correct answer.',
    if (type == 'identification' &&
        (accepted.isEmpty ||
            accepted.length > 10 ||
            accepted.any((a) => a.trim().isEmpty)))
      'Add 1 to 10 accepted answers.',
    if (!questionTypes.containsKey(type)) 'Choose a question type.',
  ];
}

class AssessmentDraft {
  AssessmentDraft(this.classId)
    : values = {
        'type': 'quiz',
        'title': '',
        'instructions': null,
        'time_limit_minutes': 30,
        'opens_at': null,
        'closes_at': null,
        'shuffle_questions': true,
        'shuffle_options': true,
        'show_correct_answers': true,
        'passing_percent': null,
      } {
    savedSettings = jsonEncode(values);
  }
  final String classId;
  String? id;
  String status = 'draft';
  bool creationPending = false;
  DateTime? lockedAt;
  bool answerDefaultOverridden = false;
  Map<String, dynamic> values;
  late String savedSettings;
  List<QuestionDraft> questions = [];
  List<String> savedOrder = [];
  Set<String> deleted = {};
  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);
  int get questionCount => questions.length;
  bool get settingsDirty => jsonEncode(values) != savedSettings;
  bool get forbiddenLockedChanges {
    final baseline = Map<String, dynamic>.from(
      jsonDecode(savedSettings) as Map,
    );
    return values.keys.any(
      (key) =>
          key != 'title' && key != 'closes_at' && values[key] != baseline[key],
    );
  }

  bool get orderDirty =>
      jsonEncode(questions.map((q) => q.id ?? q.localKey).toList()) !=
      jsonEncode(savedOrder);
  bool get dirty =>
      settingsDirty ||
      questions.any((q) => q.dirty) ||
      deleted.isNotEmpty ||
      orderDirty;
  void chooseType(String type) {
    values['type'] = type;
    if (!answerDefaultOverridden) {
      values['show_correct_answers'] = type == 'quiz';
    }
  }

  factory AssessmentDraft.fromRow(Map<String, dynamic> row) {
    final d = AssessmentDraft(row['class_id'] as String)
      ..id = row['id'] as String
      ..status = row['status'] as String
      ..lockedAt = DateTime.tryParse(row['locked_at']?.toString() ?? '')
      ..answerDefaultOverridden = true;
    for (final key in d.values.keys.toList()) {
      d.values[key] = row[key];
    }
    for (final key in ['opens_at', 'closes_at']) {
      d.values[key] = DateTime.tryParse(row[key]?.toString() ?? '')
          ?.toUtc()
          .toIso8601String();
    }
    d.savedSettings = jsonEncode(d.values);
    d.questions = (row['questions'] as List? ?? [])
        .map((q) => QuestionDraft.fromRow(Map<String, dynamic>.from(q as Map)))
        .toList();
    final positions = {
      for (final q in row['questions'] as List? ?? []) q['id']: q['position'],
    };
    d.questions.sort(
      (a, b) => (positions[a.id] as int).compareTo(positions[b.id] as int),
    );
    d.savedOrder = d.questions.map((q) => q.id!).toList();
    return d;
  }
  List<String> validate({bool publish = false, DateTime? now}) {
    final title = values['title'] as String;
    final minutes = values['time_limit_minutes'] as int;
    final passing = values['passing_percent'] as int?;
    final opens = DateTime.tryParse(values['opens_at']?.toString() ?? '');
    final closes = DateTime.tryParse(values['closes_at']?.toString() ?? '');
    final issues = <String>[
      if (title.trim().isEmpty || title.runes.length > 120)
        'Enter a title of 1 to 120 characters.',
      if (minutes < 1 || minutes > 600) 'Enter 1 to 600 minutes.',
      if ((values['instructions'] as String? ?? '').runes.length > 5000)
        'Keep instructions within 5000 characters.',
      if (passing != null && (passing < 0 || passing > 100))
        'Enter a passing score from 0 to 100.',
      if (publish && (opens == null || closes == null))
        'Set the open and close time before publishing.',
      if (opens != null &&
          closes != null &&
          (!closes.isAfter(opens) ||
              (publish && !closes.isAfter(now ?? DateTime.now().toUtc()))))
        'Choose a closing time in the future and after the opening time.',
      if (publish && questions.isEmpty)
        'Add at least one question before publishing.',
    ];
    for (var i = 0; i < questions.length; i++) {
      final errors = questions[i].validate();
      questions[i].error = errors.isEmpty ? null : errors.join('\n');
      if (errors.isNotEmpty) {
        issues.add('Question ${i + 1}: ${errors.join(' ')}');
      }
    }
    return issues;
  }
}
