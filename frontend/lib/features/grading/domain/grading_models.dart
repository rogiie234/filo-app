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
    List<Json> quizzes = const [],
    List<Json> quizAttempts = const [],
    this.quizzesLoaded = true,
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
       grades = uniqueGradingRows(grades, 'submission_id'),
       quizzes = uniqueGradingRows(quizzes, 'id'),
       quizAttempts = uniqueGradingRows(quizAttempts, 'id');
  final String userId;
  final List<Json> members,
      assignments,
      submissions,
      grades,
      quizzes,
      quizAttempts;
  final bool quizzesLoaded;
  final bool loaded;

  factory GradingData.fromJson(Json json, String userId) => GradingData(
    userId: userId,
    loaded: true,
    members: _rows(json['members']),
    assignments: _rows(json['assignments']),
    submissions: _rows(json['submissions']),
    grades: _rows(json['grades']),
    quizzes: _rows(json['quizzes']),
    quizAttempts: _rows(json['quiz_attempts']),
    quizzesLoaded: json['quizzes_loaded'] == true,
  );
  static List<Json> _rows(dynamic value) =>
      (value as List? ?? []).map((row) => Json.from(row as Map)).toList();
  Json toJson() => {
    'members': members,
    'assignments': assignments,
    'submissions': submissions,
    'grades': grades,
    'quizzes': quizzes,
    'quiz_attempts': quizAttempts,
    'quizzes_loaded': quizzesLoaded,
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
    for (final quiz in quizzes) {
      final attempt = quizAttempt(quiz['id'] as String, studentId);
      if (attempt == null ||
          !['submitted', 'auto_submitted'].contains(attempt['status']) ||
          attempt['grading_complete'] != true ||
          attempt['total_score'] == null ||
          returnedOnly && quiz['results_released_at'] == null)
        continue;
      earned += attempt['total_score'] as int;
      possible += quiz['total_points'] as int;
      unreturned |= quiz['results_released_at'] == null;
    }
    return GradeTotal(earned, possible, unreturned);
  }

  List<Json> get items => [
    for (final a in assignments) {...a, 'is_quiz': false},
    for (final q in quizzes)
      {...q, 'is_quiz': true, 'points': q['total_points']},
  ];
  Json? quizAttempt(String quizId, String studentId) => quizAttempts
      .where(
        (a) =>
            a['quiz_id'] == quizId &&
            a['student_id'] == studentId &&
            a['status'] != 'voided',
      )
      .firstOrNull;
  String quizStatus(
    Json quiz,
    String studentId, {
    bool student = false,
    DateTime? now,
  }) {
    final attempt = quizAttempt(quiz['id'] as String, studentId);
    final closes = DateTime.tryParse('${quiz['closes_at'] ?? ''}');
    if (attempt == null &&
        closes != null &&
        !closes.isAfter((now ?? DateTime.now()).toUtc()))
      return 'Missed';
    if (student && quiz['results_released_at'] == null)
      return 'Not released yet';
    if (attempt == null) return 'Not started';
    if (attempt['status'] == 'in_progress') return 'In progress';
    return attempt['grading_complete'] == true ? 'Graded' : 'Essay to grade';
  }

  String quizCell(Json quiz, String studentId, {bool student = false}) {
    final attempt = quizAttempt(quiz['id'] as String, studentId);
    final submitted = [
      'submitted',
      'auto_submitted',
    ].contains(attempt?['status']);
    final visible = !student || quiz['results_released_at'] != null;
    if (visible && submitted && attempt?['total_score'] != null)
      return '${attempt!['total_score']}/${quiz['total_points']}';
    final status = quizStatus(quiz, studentId, student: student);
    return status == 'Missed' || student && status == 'Not released yet'
        ? status
        : '\u2014';
  }
}
