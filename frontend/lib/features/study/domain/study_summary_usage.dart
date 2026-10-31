import 'dart:convert';

import 'study_ai.dart';

/// Local provenance of the submitted source text, not a model token count.
class StudySummaryUsage {
  StudySummaryUsage(
    Iterable<StudySourceUsage> sources, {
    this.serverTruncated = false,
  }) : sources = List.unmodifiable(sources) {
    if (this.sources.isEmpty ||
        this.sources.length > 3 ||
        this.sources.any(
          (s) =>
              s.key.isEmpty ||
              s.name.trim().isEmpty ||
              s.retainedCharacters <= 0 ||
              s.originalCharacters < s.retainedCharacters,
        ) ||
        retainedCharacters > 40000)
      throw const FormatException('Invalid summary usage');
  }

  factory StudySummaryUsage.fromResult(StudyAiResult<StudyTextAnswer> result) =>
      StudySummaryUsage(
        result.sources.usage,
        serverTruncated: result.serverTruncated,
      );

  final List<StudySourceUsage> sources;
  final bool serverTruncated;
  int get retainedCharacters =>
      sources.fold(0, (total, s) => total + s.retainedCharacters);
  bool get truncated => serverTruncated || sources.any((s) => s.truncated);

  String encode() => jsonEncode({
    'version': 1,
    'server_truncated': serverTruncated,
    'sources': [
      for (final s in sources)
        {
          'key': s.key,
          'name': s.name,
          'original': s.originalCharacters,
          'retained': s.retainedCharacters,
        },
    ],
  });

  static StudySummaryUsage? decode(String? value) {
    if (value == null) return null;
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      if (data['version'] != 1 || data['server_truncated'] is! bool)
        return null;
      return StudySummaryUsage(
        (data['sources'] as List).map(
          (entry) => StudySourceUsage(
            key: entry['key'] as String,
            name: entry['name'] as String,
            originalCharacters: entry['original'] as int,
            retainedCharacters: entry['retained'] as int,
          ),
        ),
        serverTruncated: data['server_truncated'] as bool,
      );
    } catch (_) {
      // Historical or unreadable metadata never hides a valid saved summary.
      return null;
    }
  }
}
