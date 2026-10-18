typedef Json = Map<String, dynamic>;

/// A repeated transport/cache row is the same record, not another student's
/// work. Keep distinct IDs even when names or answer text happen to match.
List<Json> uniqueGradingRows(Iterable<Json> rows, String key) =>
    {for (final row in rows) row[key] as String: row}.values.toList();

class GradeTotal {
  const GradeTotal(this.earned, this.possible, this.hasUnreturned);
  final int earned, possible;
  final bool hasUnreturned;
  int? get percent => possible == 0 ? null : (100 * earned / possible).round();
}

/// A complete class snapshot. Student snapshots are built solely from the
/// existing own-submission cache and returned grades, never instructor rows.
class GradingData {
  GradingData({
    required this.userId,
    List<Json> members = const [],
    List<Json> assignments = const [],
    List<Json> submissions = const [],
    List<Json> grades = const [],
    this.loaded = false,
  }) : members = uniqueGradingRows(members, 'student_id'),
       assignments = uniqueGradingRows(assignments, 'id'),
       submissions = uniqueGradingRows(submissions, 'id')
           .map(
             (row) => <String, dynamic>{
               ...row,
               'items': uniqueGradingRows(_rows(row['items']), 'id'),
             },
           )
           .toList(),
       grades = uniqueGradingRows(grades, 'submission_id');
  final String userId;
  final List<Json> members, assignments, submissions, grades;
  final bool loaded;

  factory GradingData.fromJson(Json json, String userId) => GradingData(
    userId: userId,
    loaded: true,
    members: _rows(json['members']),
    assignments: _rows(json['assignments']),
    submissions: _rows(json['submissions']),
    grades: _rows(json['grades']),
  );
  static List<Json> _rows(dynamic value) =>
      (value as List? ?? []).map((row) => Json.from(row as Map)).toList();
  Json toJson() => {
    'members': members,
    'assignments': assignments,
    'submissions': submissions,
    'grades': grades,
  };
  // Build indexes once per snapshot, so sideways scrolling does not scan the
  // whole class's work for every visible cell.
  late final _assignmentIndex = {for (final p in assignments) p['id']: p};
  late final _submissionIndex = {
    for (final s in submissions) (s['post_id'], s['student_id']): s,
  };
  late final _gradeIndex = {
    for (final g in grades)
      if (g['score'] != null) g['submission_id']: g,
  };
  Json? assignment(String id) => _assignmentIndex[id];
  Json? submission(String postId, String studentId) =>
      _submissionIndex[(postId, studentId)];
  Json? grade(String? submissionId) => _gradeIndex[submissionId];

  String status(
    String postId,
    String studentId, {
    bool student = false,
    DateTime? now,
  }) {
    final work = submission(postId, studentId);
    final saved = grade(work?['id'] as String?);
    if (saved != null && (!student || saved['returned_at'] != null)) {
      return student
          ? 'Graded'
          : saved['returned_at'] == null
          ? 'Graded (not returned)'
          : 'Graded (returned)';
    }
    if (work?['status'] == 'turned_in' && work?['submitted_at'] != null) {
      return work?['is_late'] == true ? 'Late' : 'Turned in';
    }
    final due = DateTime.tryParse('${assignment(postId)?['due_at'] ?? ''}');
    return due != null && (now ?? DateTime.now()).isAfter(due)
        ? 'Missing'
        : 'Not due yet';
  }

  GradeTotal total(String studentId, {bool returnedOnly = false}) {
    var earned = 0, possible = 0;
    var unreturned = false;
    for (final post in assignments) {
      final work = submission(post['id'] as String, studentId);
      final saved = grade(work?['id'] as String?);
      if (saved == null || (returnedOnly && saved['returned_at'] == null)) {
        continue;
      }
      earned += (saved['score'] as num).toInt();
      possible += (post['points'] as num? ?? 0).toInt();
      unreturned |= saved['returned_at'] == null;
    }
    return GradeTotal(earned, possible, unreturned);
  }
}
