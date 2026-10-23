import 'exam.dart';

enum StudentQuizStatus {
  upcoming('Upcoming'),
  open('Open'),
  inProgress('In progress'),
  submitted('Submitted'),
  closed('Closed'),
  missed('Missed');

  const StudentQuizStatus(this.label);
  final String label;
}

class StudentQuizState {
  const StudentQuizState(this.status, {this.pending = false});
  final StudentQuizStatus status;
  final bool pending;
  String get action =>
      status == StudentQuizStatus.inProgress ? 'Continue' : 'Start';
}

StudentQuizState studentQuizState(StudentQuiz quiz, DateTime now) {
  final session = quiz.session;
  if (session?.submitted == true) {
    return const StudentQuizState(StudentQuizStatus.submitted);
  }
  if (session?.inProgress == true) {
    return StudentQuizState(
      StudentQuizStatus.inProgress,
      pending: !now.isBefore(session!.deadline) || !quiz.sessionKnown,
    );
  }
  if (quiz.closesAt != null && !now.isBefore(quiz.closesAt!)) {
    return StudentQuizState(
      quiz.sessionKnown && session == null
          ? StudentQuizStatus.missed
          : StudentQuizStatus.closed,
    );
  }
  if (quiz.opensAt != null && now.isBefore(quiz.opensAt!)) {
    return const StudentQuizState(StudentQuizStatus.upcoming);
  }
  return StudentQuizState(
    StudentQuizStatus.open,
    pending: !quiz.sessionKnown || session != null,
  );
}

String? studentQuizDisabledReason(
  StudentQuiz quiz,
  DateTime now, {
  required bool archived,
  required bool online,
}) {
  final state = studentQuizState(quiz, now);
  if (archived) return 'This class is archived.';
  if (quiz.session?.submitted == true)
    return 'You have already taken this quiz.';
  if (quiz.closesAt != null && !now.isBefore(quiz.closesAt!)) {
    return 'This quiz has closed.';
  }
  if (state.status == StudentQuizStatus.upcoming) {
    return 'This quiz opens on ${philippineQuizDate(quiz.opensAt)}.';
  }
  if (!online)
    return 'Connect to the internet to ${state.action == 'Continue' ? 'continue' : 'start'}.';
  if (state.pending || !quiz.sessionKnown)
    return 'Refresh to check your exam status.';
  return null;
}

String philippineQuizDate(DateTime? instant) {
  if (instant == null) return 'Not scheduled';
  final date = instant.toUtc().add(const Duration(hours: 8));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '${date.day} ${months[date.month - 1]} ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
}

int compareStudentWork(DateTime? a, String aId, DateTime? b, String bId) {
  final order = a == null
      ? (b == null ? 0 : 1)
      : b == null
      ? -1
      : a.compareTo(b);
  return order != 0 ? order : aId.compareTo(bId);
}

String studentQuizGroup(StudentQuiz quiz, DateTime now) {
  if (quiz.session?.submitted == true) return 'Done';
  final due = quiz.closesAt;
  if (due == null) return 'Later';
  if (due.isBefore(now)) return 'Overdue';
  final today = DateTime(now.year, now.month, now.day);
  if (due.isBefore(today.add(const Duration(days: 1)))) return 'Today';
  if (due.isBefore(today.add(Duration(days: 8 - today.weekday))))
    return 'This week';
  return 'Later';
}
