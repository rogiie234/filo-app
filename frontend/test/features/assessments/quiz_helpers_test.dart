import 'package:flutter_test/flutter_test.dart';
import 'package:filo/features/assessments/domain/quiz_helpers.dart';

void main() {
  test('Manila 11:30 PM and 12:30 AM convert independently of device zone', () {
    expect(
      manilaToUtc(2026, 10, 21, 23, 30),
      DateTime.utc(2026, 10, 21, 15, 30),
    );
    expect(
      manilaToUtc(2026, 10, 21, 0, 30),
      DateTime.utc(2026, 10, 20, 16, 30),
    );
  });
  test('month/year boundaries and round trips', () {
    for (final date in [
      DateTime.utc(2027, 1, 1, 0, 30),
      DateTime.utc(2026, 11, 1, 0, 30),
      DateTime.utc(2028, 3, 1, 0, 30),
      DateTime.utc(2026, 10, 21, 23, 30),
    ]) {
      final instant = manilaToUtc(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
      );
      expect(utcToManila(instant), date);
    }
    expect(manilaToUtc(2027, 1, 1, 0, 30), DateTime.utc(2026, 12, 31, 16, 30));
    expect(manilaToUtc(2028, 3, 1, 0, 30), DateTime.utc(2028, 2, 29, 16, 30));
  });
  final opening = DateTime.utc(2026, 10, 21, 10);
  final closing = DateTime.utc(2026, 10, 21, 11);
  QuizDisplayStatus status(
    DateTime now, {
    String value = 'published',
    DateTime? opens,
    DateTime? closes,
  }) => quizDisplayStatus(
    status: value,
    opensAt: opens,
    closesAt: closes,
    now: now,
  );
  test('draft takes precedence over elapsed window', () {
    expect(
      status(closing, value: 'draft', opens: opening, closes: closing),
      QuizDisplayStatus.draft,
    );
  });
  test('opening and closing boundaries are inclusive', () {
    expect(
      status(
        opening.subtract(const Duration(microseconds: 1)),
        opens: opening,
        closes: closing,
      ),
      QuizDisplayStatus.scheduled,
    );
    expect(
      status(opening, opens: opening, closes: closing),
      QuizDisplayStatus.open,
    );
    expect(
      status(
        closing.subtract(const Duration(microseconds: 1)),
        opens: opening,
        closes: closing,
      ),
      QuizDisplayStatus.open,
    );
    expect(
      status(closing, opens: opening, closes: closing),
      QuizDisplayStatus.closed,
    );
    expect(
      status(
        closing.add(const Duration(days: 1)),
        opens: opening,
        closes: closing,
      ),
      QuizDisplayStatus.closed,
    );
  });
  test('null dates leave boundaries unrestricted', () {
    expect(status(opening), QuizDisplayStatus.open);
    expect(status(opening, closes: closing), QuizDisplayStatus.open);
    expect(status(closing, closes: closing), QuizDisplayStatus.closed);
    expect(
      status(opening.subtract(const Duration(seconds: 1)), opens: opening),
      QuizDisplayStatus.scheduled,
    );
    expect(status(closing, opens: opening), QuizDisplayStatus.open);
    expect(QuizDisplayStatus.scheduled.label, 'Scheduled');
  });
}
