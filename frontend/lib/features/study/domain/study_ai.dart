import 'study_inputs.dart';

const studyAiMessages = {
  'NOT_ALLOWED': "You can't use this study action right now.",
  'INVALID_REQUEST': 'Check your study settings and try again.',
  'NO_TEXT': 'No readable text found in this file.',
  'TOO_LARGE': 'The request is too large. Use less source text and try again.',
  'AI_IN_PROGRESS':
      'Your last request is still being processed. Try again in a minute.',
  // Screen release still requires truthful saved-work/manual-action support.
  'AI_BUSY': 'The AI assistant is busy right now. Your work is saved. Please try again in a few minutes, or create questions manually.',
  'AI_TIMEOUT': 'The AI request timed out. Please try again.',
  'AI_BAD_OUTPUT':
      'The AI could not prepare this study material. Please try again.',
  'AI_UNAVAILABLE': 'The AI assistant is unavailable. Please try again later.',
  'AI_BLOCKED': "The AI couldn't respond to this request. Try changing your question or source text.",
  'OFFLINE': "You're offline. Connect to the internet to chat or generate study material. You can still open saved study material.",
  'AUTH': 'Your session has expired. Sign in again to use AI Study.',
  'UNKNOWN': 'The request could not be confirmed. Wait before trying again.',
  // Cancellation is a distinct outcome; reuse approved uncertain-result copy.
  'CANCELLED': 'The request could not be confirmed. Wait before trying again.',
  'LOAD_FAILED': 'Your saved study material could not be opened. Try again.',
};

class StudyAiFailure implements Exception {
  const StudyAiFailure(this.code, {this.sources});
  final String code;
  final PreparedStudySources? sources;
  String get message => studyAiMessages[code] ?? studyAiMessages['UNKNOWN']!;
  @override
  String toString() => message;
}

String studyAiFriendlyError(Object error) =>
    error is StudyAiFailure ? error.message : studyAiMessages['UNKNOWN']!;

class StudyChatInput {
  const StudyChatInput({required this.role, required this.content});
  final String role, content;
}

class StudyAiSource {
  const StudyAiSource({
    required this.key,
    required this.name,
    required this.text,
  });
  final String key, name, text;
}

class StudySourceUsage {
  const StudySourceUsage({
    required this.key,
    required this.name,
    required this.originalCharacters,
    required this.retainedCharacters,
  });
  final String key, name;
  final int originalCharacters, retainedCharacters;
  bool get truncated => retainedCharacters < originalCharacters;
}

class PreparedStudySources {
  PreparedStudySources(
    List<Map<String, String>> sources,
    List<StudySourceUsage> usage,
  ) : sources = List.unmodifiable(
        sources.map((s) => Map<String, String>.unmodifiable(s)),
      ),
      usage = List.unmodifiable(usage);
  final List<Map<String, String>> sources;
  final List<StudySourceUsage> usage;
  bool get truncated => usage.any((s) => s.truncated);
}

class StudyTextAnswer {
  const StudyTextAnswer({required this.answer, required this.mode});
  final String answer, mode;
}

class StudyAiBatch<T> {
  StudyAiBatch(List<T> items, {required this.dropped, required this.missing})
    : items = List.unmodifiable(items);
  final List<T> items;
  final int dropped, missing;
}

class StudyAiResult<T> {
  const StudyAiResult(this.value, this.sources, {this.serverTruncated = false});
  final T value;
  final PreparedStudySources sources;
  final bool serverTruncated;
  bool get truncated => sources.truncated || serverTruncated;
}

List<Map<String, String>> prepareStudyMessages(List<StudyChatInput> messages) {
  final last = messages.skip(messages.length > 10 ? messages.length - 10 : 0);
  return last.map((message) {
    if (!{'user', 'assistant'}.contains(message.role)) {
      throw const StudyAiFailure('INVALID_REQUEST');
    }
    final text = String.fromCharCodes(message.content.trim().runes.take(2000));
    if (text.trim().isEmpty) throw const StudyAiFailure('INVALID_REQUEST');
    return {'role': message.role, 'content': text};
  }).toList();
}

PreparedStudySources prepareStudySources(List<StudyAiSource> sources) {
  if (sources.length > 3) throw const StudyAiFailure('TOO_LARGE');
  for (final source in sources) {
    if (source.name.trim().isEmpty) {
      throw const StudyAiFailure('INVALID_REQUEST');
    }
    if (source.name.runes.length > 255) throw const StudyAiFailure('TOO_LARGE');
    if (source.text.trim().isEmpty) throw const StudyAiFailure('NO_TEXT');
  }
  final lengths = sources.map((s) => s.text.runes.length).toList();
  final used = List.filled(sources.length, 0);
  var remaining = 40000;
  var pending = List.generate(sources.length, (i) => i);
  // Split fairly, then redistribute unused space from shorter sources.
  while (remaining > 0 && pending.isNotEmpty) {
    final share = remaining ~/ pending.length,
        extra = remaining % pending.length;
    for (var position = 0; position < pending.length; position++) {
      final i = pending[position];
      final allowance = share + (position < extra ? 1 : 0);
      final available = lengths[i] - used[i];
      final take = available < allowance ? available : allowance;
      used[i] += take;
      remaining -= take;
    }
    pending = pending.where((i) => used[i] < lengths[i]).toList();
  }
  final wire = <Map<String, String>>[], usage = <StudySourceUsage>[];
  for (var i = 0; i < sources.length; i++) {
    final source = sources[i];
    final text = String.fromCharCodes(source.text.runes.take(used[i]));
    if (text.trim().isEmpty) throw const StudyAiFailure('NO_TEXT');
    wire.add({'name': source.name, 'text': text});
    usage.add(
      StudySourceUsage(
        key: source.key,
        name: source.name,
        originalCharacters: lengths[i],
        retainedCharacters: used[i],
      ),
    );
  }
  return PreparedStudySources(wire, usage);
}

StudyAiBatch<StudyCardInput> decodeStudyCards(dynamic data, int count) {
  final items = _batchItems(data, 'cards', count);
  final cards = items.map((raw) {
    final row = _object(raw, {'front', 'back'});
    return StudyCardInput(
      front: _text(row['front'], 200),
      back: _text(row['back'], 500),
    );
  }).toList();
  return StudyAiBatch(
    cards,
    dropped: data['dropped'] as int,
    missing: data['missing'] as int,
  );
}

StudyAiBatch<StudyQuestionInput> decodeStudyQuestions(
  dynamic data,
  StudyQuizSettings settings,
) {
  final items = _batchItems(data, 'questions', settings.count);
  final questions = items.map((raw) {
    if (raw is! Map || !settings.types.contains(raw['type'])) {
      throw const StudyAiFailure('AI_BAD_OUTPUT');
    }
    final type = raw['type'] as String;
    final fields = switch (type) {
      'multiple_choice' => {'options', 'correct_index'},
      'true_false' => {'correct_boolean'},
      'identification' => {'accepted_answers'},
      _ => <String>{},
    };
    final row = _object(raw, {'type', 'prompt', 'explanation', ...fields});
    List<String>? options, accepted;
    int? index;
    bool? boolean;
    if (type == 'multiple_choice') {
      if (row['correct_index'] is! int || row['options'] is! List) {
        throw const StudyAiFailure('AI_BAD_OUTPUT');
      }
      index = row['correct_index'] as int;
      options = (row['options'] as List).map((s) => _text(s, 500)).toList();
    } else if (type == 'true_false') {
      if (row['correct_boolean'] is! bool) {
        throw const StudyAiFailure('AI_BAD_OUTPUT');
      }
      boolean = row['correct_boolean'] as bool;
    } else {
      if (row['accepted_answers'] is! List) {
        throw const StudyAiFailure('AI_BAD_OUTPUT');
      }
      accepted = (row['accepted_answers'] as List)
          .map((s) => _text(s, 200))
          .toList();
    }
    final question = StudyQuestionInput(
      type: type,
      prompt: _text(row['prompt'], 1000),
      explanation: _text(row['explanation'], 500),
      options: options,
      correctIndex: index,
      correctBoolean: boolean,
      acceptedAnswers: accepted,
    );
    try {
      question.validate();
    } catch (_) {
      throw const StudyAiFailure('AI_BAD_OUTPUT');
    }
    return question;
  }).toList();
  return StudyAiBatch(
    questions,
    dropped: data['dropped'] as int,
    missing: data['missing'] as int,
  );
}

Map _object(dynamic data, Set<String> keys) {
  if (data is! Map ||
      data.keys.toSet().difference(keys).isNotEmpty ||
      !keys.every(data.containsKey)) {
    throw const StudyAiFailure('AI_BAD_OUTPUT');
  }
  return data;
}

String _text(dynamic text, int cap) {
  if (text is! String || text.trim().isEmpty || text.runes.length > cap) {
    throw const StudyAiFailure('AI_BAD_OUTPUT');
  }
  return text.trim();
}

List _batchItems(dynamic data, String key, int count) {
  final row = _object(data, {key, 'dropped', 'missing'});
  final items = row[key], dropped = row['dropped'], missing = row['missing'];
  if (items is! List ||
      items.isEmpty ||
      items.length > count ||
      dropped is! int ||
      dropped < 0 ||
      missing is! int ||
      missing != count - items.length) {
    throw const StudyAiFailure('AI_BAD_OUTPUT');
  }
  return items;
}

(StudyTextAnswer, bool) decodeStudyText(dynamic data, bool hasSources) {
  final row = _object(data, {'answer', 'mode', 'truncated'});
  if (row['mode'] != (hasSources ? 'files' : 'general') ||
      row['truncated'] is! bool) {
    throw const StudyAiFailure('AI_BAD_OUTPUT');
  }
  return (
    StudyTextAnswer(
      answer: _text(row['answer'], 4000),
      mode: row['mode'] as String,
    ),
    row['truncated'] as bool,
  );
}
