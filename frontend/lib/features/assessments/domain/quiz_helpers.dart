/// Philippine civil time is UTC+08:00, without daylight saving time.
DateTime manilaToUtc(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
).subtract(const Duration(hours: 8));

/// A UTC-tagged container of Manila calendar components, not an instant.
/// Read its fields for display; do not serialize it as an instant.
DateTime utcToManila(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

enum QuizDisplayStatus { draft, scheduled, open, closed }

QuizDisplayStatus quizDisplayStatus({
  required String status,
  DateTime? opensAt,
  DateTime? closesAt,
  required DateTime now,
}) {
  if (status == 'draft') return QuizDisplayStatus.draft;
  final instant = now.toUtc();
  if (closesAt != null && !instant.isBefore(closesAt.toUtc())) {
    return QuizDisplayStatus.closed;
  }
  if (opensAt != null && instant.isBefore(opensAt.toUtc())) {
    return QuizDisplayStatus.scheduled;
  }
  return QuizDisplayStatus.open;
}

extension QuizDisplayLabel on QuizDisplayStatus {
  String get label => switch (this) {
    QuizDisplayStatus.draft => 'Draft',
    QuizDisplayStatus.scheduled => 'Scheduled',
    QuizDisplayStatus.open => 'Open',
    QuizDisplayStatus.closed => 'Closed',
  };
}
