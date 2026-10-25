typedef ResultJson = Map<String, dynamic>;

ResultJson resultJson(Object? value) => Map<String, dynamic>.from(value as Map);
List<ResultJson> resultRows(Object? value) =>
    (value as List).map(resultJson).toList();

enum QuizResultStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  submitted('Submitted'),
  essayToGrade('Essay to grade'),
  graded('Graded');

  const QuizResultStatus(this.label);
  final String label;
}

class ResultSession {
  ResultSession(this.json) {
    if ((json['session_id'] ?? json['id']) is! String ||
        ![
          'in_progress',
          'submitted',
          'auto_submitted',
          'voided',
        ].contains(json['status'])) {
      throw const FormatException('Invalid attempt');
    }
    if (json.containsKey('student_id') &&
        (json['student_id'] is! String ||
            json['attempt_no'] is! int ||
            json['leave_count'] is! int ||
            (json['total_score'] != null && json['total_score'] is! int) ||
            json['grading_complete'] is! bool)) {
      throw const FormatException('Incomplete monitoring attempt');
    }
  }
  final ResultJson json;
  String get id => (json['session_id'] ?? json['id']) as String;
  String get status => json['status'] as String;
  String get studentId => json['student_id'] as String;
  int get attempt => json['attempt_no'] as int;
  bool get voided => status == 'voided';
  bool get submitted => status == 'submitted' || status == 'auto_submitted';
  bool get gradingComplete => json['grading_complete'] == true;
  bool get released => json['results_released'] == true;
  int? get score => (json['total_score'] ?? json['score']) as int?;
  int get leaves => json['leave_count'] as int;
  String get studentName =>
      (json['profile'] as Map?)?['display_name'] as String? ?? studentId;
}

QuizResultStatus quizResultStatus(
  ResultSession? session, {
  required bool hasEssay,
}) {
  if (session == null || session.voided) return QuizResultStatus.notStarted;
  if (session.status == 'in_progress') return QuizResultStatus.inProgress;
  if (session.gradingComplete) return QuizResultStatus.graded;
  return hasEssay ? QuizResultStatus.essayToGrade : QuizResultStatus.submitted;
}

int resultPercent(int score, int totalPoints) =>
    totalPoints > 0 ? (100 * score / totalPoints).round() : 0;

bool? resultPassed(int percent, int? passingPercent) =>
    passingPercent == null ? null : percent >= passingPercent;

int mostLeavesFirst(ResultSession a, ResultSession b) {
  final leaves = b.leaves.compareTo(a.leaves);
  if (leaves != 0) return leaves;
  final name = a.studentName.compareTo(b.studentName);
  return name != 0 ? name : a.studentId.compareTo(b.studentId);
}

class SubmittedAverage {
  const SubmittedAverage(this.points, {required this.provisional});
  final double? points;
  final bool provisional;
}

SubmittedAverage submittedAverage(Iterable<ResultSession> sessions) {
  final current = sessions.where((s) => !s.voided && s.submitted).toList();
  if (current.isEmpty) return const SubmittedAverage(null, provisional: false);
  // An unavailable score is not a zero or a partially calculated average.
  if (current.any((s) => s.score == null)) {
    return SubmittedAverage(
      null,
      provisional: current.any((s) => !s.gradingComplete),
    );
  }
  return SubmittedAverage(
    current.fold<int>(0, (sum, s) => sum + s.score!) / current.length,
    provisional: current.any((s) => !s.gradingComplete),
  );
}

class ReleasedResult {
  ReleasedResult({
    required this.score,
    required this.totalPoints,
    required this.percent,
    required this.passed,
    required this.review,
  });
  factory ReleasedResult.fromJson(ResultJson json) => ReleasedResult(
    score: json['score'] as int,
    totalPoints: json['total_points'] as int,
    percent: json['percent'] as int,
    passed: json['passed'] as bool?,
    review: json['review'] == null ? null : resultRows(json['review']),
  );
  final int score, totalPoints, percent;
  final bool? passed;
  final List<ResultJson>? review;
}

class StudentResultData {
  const StudentResultData(this.quiz, this.session, this.result);
  final ResultJson quiz;
  final ResultSession? session;
  final ReleasedResult? result;
}

class QuizMonitoring {
  QuizMonitoring(this.json);
  final ResultJson json;
  ResultJson get quiz => resultJson(json['quiz']);
  List<ResultSession> get sessions =>
      resultRows(json['sessions']).map(ResultSession.new).toList();
  List<ResultSession> get current => sessions.where((s) => !s.voided).toList();
  List<ResultSession> get history => sessions.where((s) => s.voided).toList();
  List<ResultJson> get members => resultRows(json['members']);
  List<ResultJson> get secondChances => resultRows(json['second_chances']);
  List<ResultJson> get notStarted {
    final started = current.map((s) => s.studentId).toSet();
    return members.where((m) => !started.contains(m['student_id'])).toList();
  }

  List<ResultSession> get rosterAttempts {
    final ids = members.map((m) => m['student_id']).toSet();
    return current.where((s) => ids.contains(s.studentId)).toList();
  }

  int get submittedCount => rosterAttempts.where((s) => s.submitted).length;
  SubmittedAverage get average => submittedAverage(rosterAttempts);
  int get inProgressCount =>
      rosterAttempts.where((s) => s.status == 'in_progress').length;
  int? get pendingEssays => json['essay_answers'] == null
      ? null
      : resultRows(json['essay_answers'])
            .where(
              (a) =>
                  rosterAttempts.any(
                    (s) => s.id == a['session_id'] && s.submitted,
                  ) &&
                  essayNeedsGrade(a),
            )
            .length;
  String? releaseBlocked(DateTime now) {
    if (quiz['results_released_at'] != null)
      return 'Results are already released.';
    final opens = DateTime.tryParse('${quiz['opens_at'] ?? ''}');
    if (opens == null || opens.isAfter(now.toUtc()))
      return 'This quiz has not opened yet.';
    if (current.any((s) => s.status == 'in_progress'))
      return 'Some students are still taking this quiz.';
    if (current.any((s) => s.submitted && !s.gradingComplete))
      return 'Grade all essay answers first.';
    return null;
  }

  ResultSession? attemptFor(String studentId) =>
      current.where((s) => s.studentId == studentId).firstOrNull;
  bool hasHistory(String studentId) =>
      history.any((s) => s.studentId == studentId) ||
      secondChances.any((c) => c['student_id'] == studentId);
}

class AttemptDetail {
  AttemptDetail(this.json);
  final ResultJson json;
  ResultSession get session => ResultSession(resultJson(json['session']));
  ResultJson get quiz => resultJson(json['quiz']);
  List<ResultJson> get questions => resultRows(json['questions']);
  bool get readOnly => session.voided;
  int get pendingEssays => session.submitted && !session.gradingComplete
      ? questions
            .where(
              (q) =>
                  q['type'] == 'essay' && essayNeedsGrade(q['answer'] as Map?),
            )
            .length
      : 0;
}

class ResultsState<T> {
  const ResultsState({
    this.data,
    this.cached = false,
    this.refreshing = false,
    this.readOnly = true,
    this.error,
  });
  final T? data;
  final bool cached, refreshing, readOnly;
  final String? error;
  bool get loaded => data != null;
}

// PostgreSQL btrim(text) removes spaces; preserve the server's definition of blank.
bool blankEssay(Object? text) =>
    text == null || text.toString().replaceAll(RegExp(r'^ +| +$'), '').isEmpty;
bool essayNeedsGrade(Map? answer) =>
    answer != null &&
    !blankEssay(answer['text_answer']) &&
    answer['points_awarded'] == null;
bool overriddenMark(Map? answer) =>
    answer?['graded_by'] != null && answer?['is_correct'] is bool;

String resultAnswer(Object? value) {
  if (value == null || value is String && value.isEmpty) return 'No answer';
  if (value is bool) return value ? 'True' : 'False';
  if (value is List) return value.map(resultAnswer).join(', ');
  return value.toString();
}

List<ResultJson> monitoringStudents(
  QuizMonitoring data, {
  String search = '',
  String filter = 'All',
  String sort = 'Name',
}) {
  final rows = data.members.where((m) {
    final id = m['student_id'] as String;
    final name = ((m['profile'] as Map?)?['display_name'] ?? id).toString();
    if (!name.toLowerCase().contains(search.trim().toLowerCase())) return false;
    final s = data.attemptFor(id);
    final status = quizResultStatus(
      s,
      hasEssay: data.quiz['has_essay'] == true,
    );
    return switch (filter) {
      'To grade' => status == QuizResultStatus.essayToGrade,
      'In progress' => status == QuizResultStatus.inProgress,
      'Not started' => status == QuizResultStatus.notStarted,
      'Submitted' => s?.submitted == true,
      _ => true,
    };
  }).toList();
  String name(ResultJson m) =>
      ((m['profile'] as Map?)?['display_name'] ?? m['student_id']).toString();
  rows.sort((a, b) {
    final x = data.attemptFor(a['student_id'] as String),
        y = data.attemptFor(b['student_id'] as String);
    var order = 0;
    if (sort == 'Most leaves first')
      order = (y?.leaves ?? 0).compareTo(x?.leaves ?? 0);
    if (sort == 'Score') {
      final xs = x?.submitted == true ? x?.score : null,
          ys = y?.submitted == true ? y?.score : null;
      order = xs == null
          ? (ys == null ? 0 : 1)
          : ys == null
          ? -1
          : ys.compareTo(xs);
    }
    if (order == 0)
      order = name(a).toLowerCase().compareTo(name(b).toLowerCase());
    return order != 0
        ? order
        : (a['student_id'] as String).compareTo(b['student_id'] as String);
  });
  return rows;
}
