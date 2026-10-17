import '../../../data/local/app_database.dart';

enum AssignmentStatus {
  assigned('Assigned'),
  draft('Draft'),
  turnedIn('Turned in'),
  late('Late'),
  graded('Graded'),
  missing('Missing');

  const AssignmentStatus(this.label);
  final String label;
}

/// Only a returned grade outranks a confirmed turn-in. An overdue draft is
/// still missing work; allowing late submissions does not change this status.
AssignmentStatus assignmentStatus({
  DateTime? dueAt,
  CacheSubmission? submission,
  CacheGrade? grade,
  DateTime? now,
}) {
  if (grade?.returnedAt != null &&
      submission != null &&
      grade!.submissionId == submission.id) {
    return AssignmentStatus.graded;
  }
  if (submission?.status == 'turned_in') {
    return submission!.isLate
        ? AssignmentStatus.late
        : AssignmentStatus.turnedIn;
  }
  if (dueAt != null && (now ?? DateTime.now()).isAfter(dueAt)) {
    return AssignmentStatus.missing;
  }
  return submission == null
      ? AssignmentStatus.assigned
      : AssignmentStatus.draft;
}
