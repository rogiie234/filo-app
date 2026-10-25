import '../../assessments/domain/quiz_helpers.dart';
import 'results.dart';

String resultsCsv(QuizMonitoring data, List<ResultJson> students) {
  final quiz = data.quiz;
  final threshold = quiz['passing_percent'] as int?;
  final total = quiz['total_points'] as int;
  final rows = <List<Object?>>[
    [
      'Student name',
      'Status',
      'Score',
      'Total points',
      'Percentage',
      if (threshold != null) 'Passed',
      'Essays graded',
      'Leave count',
    ],
    for (final student in students)
      (() {
        final id = student['student_id'] as String;
        final attempt = data.attemptFor(id);
        final score = attempt?.submitted == true ? attempt?.score : null;
        final percent = score == null ? null : resultPercent(score, total);
        final graded = attempt?.submitted == true && attempt!.gradingComplete;
        return <Object?>[
          (student['profile'] as Map?)?['display_name'] ?? id,
          quizResultStatus(attempt, hasEssay: quiz['has_essay'] == true).label,
          score,
          total,
          percent,
          if (threshold != null)
            graded && percent != null
                ? (resultPassed(percent, threshold)! ? 'Yes' : 'No')
                : null,
          graded ? 'Yes' : 'No',
          attempt?.leaves ?? 0,
        ];
      })(),
  ];
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (value is String && RegExp(r'^\s*[=+@-]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  return '\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
}

String resultsCsvFilename(String title, DateTime now) {
  final safe = title
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final name = safe.isEmpty
      ? 'quiz'
      : safe.length > 80
      ? safe.substring(0, 80)
      : safe;
  final date = utcToManila(now).toIso8601String().split('T').first;
  return '${name}_results_$date.csv';
}
