import 'dart:async';

class AiCancelled implements Exception {
  const AiCancelled();
}

class AiCancelToken {
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get cancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void check() {
    if (isCancelled) throw const AiCancelled();
  }

  Future<T> wait<T>(Future<T> work) =>
      Future.any([work, cancelled.then<T>((_) => throw const AiCancelled())]);
}

class ExtractionProgress {
  const ExtractionProgress(this.stage, {this.completed, this.total});
  final String stage;
  final int? completed, total;
}

class LessonText {
  const LessonText({
    required this.text,
    required this.sourceKey,
    this.warnings = const [],
    this.fromCache = false,
    this.knownCharacterCount,
  });
  final String text, sourceKey;
  final List<String> warnings;
  final bool fromCache;
  final int? knownCharacterCount;
  int get characterCount => knownCharacterCount ?? text.runes.length;
}

class SourcePrefix {
  const SourcePrefix(this.key, this.name, this.characters);
  final String key, name;
  final int characters;
  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'characters': characters,
  };
  factory SourcePrefix.fromJson(Map<String, dynamic> json) => SourcePrefix(
    json['key'] as String,
    json['name'] as String,
    json['characters'] as int,
  );
}

class AiSourceContext {
  const AiSourceContext({
    required this.sources,
    required this.difficulty,
    this.topicFocus = '',
    this.revision = 2,
  });
  final List<SourcePrefix> sources;
  final String difficulty, topicFocus;
  final int revision;
  Map<String, dynamic> toJson() => {
    'sources': sources.map((s) => s.toJson()).toList(),
    'difficulty': difficulty,
    'topic_focus': topicFocus,
    'revision': revision,
  };
  factory AiSourceContext.fromJson(Map<String, dynamic> json) =>
      AiSourceContext(
        sources: (json['sources'] as List)
            .map(
              (s) => SourcePrefix.fromJson(Map<String, dynamic>.from(s as Map)),
            )
            .toList(),
        difficulty: json['difficulty'] as String,
        topicFocus: json['topic_focus'] as String? ?? '',
        revision: json['revision'] as int? ?? 2,
      );
}

class AiSourceSelection {
  AiSourceSelection({required this.id, required this.name, required this.size});
  final String id, name;
  final int? size;
  LessonText? result;
  String? error;
  ExtractionProgress? progress;
  AiCancelToken cancel = AiCancelToken();
}

class AllocatedSources {
  const AllocatedSources(this.texts, this.prefixes, this.warnings);
  final List<Map<String, String>> texts;
  final List<SourcePrefix> prefixes;
  final List<String> warnings;
}

AllocatedSources allocateAiSources(
  List<AiSourceSelection> sources, {
  int cap = 40000,
}) {
  if (sources.length > 3) throw const FormatException('Pick up to 3 files.');
  var remaining = cap;
  final texts = <Map<String, String>>[], prefixes = <SourcePrefix>[];
  final warnings = <String>[];
  for (final source in sources) {
    final result = source.result;
    if (result == null) continue;
    final used = result.characterCount < remaining
        ? result.characterCount
        : remaining;
    if (used < result.characterCount)
      warnings.add(
        'Only the first $used characters of ${source.name} were used. Pick a smaller file or section for the rest.',
      );
    if (used > 0) {
      texts.add({
        'file_name': source.name,
        'text': String.fromCharCodes(result.text.runes.take(used)),
      });
      prefixes.add(SourcePrefix(result.sourceKey, source.name, used));
    }
    remaining -= used;
  }
  return AllocatedSources(texts, prefixes, warnings);
}
