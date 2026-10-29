import 'quiz_draft.dart';

class QuizPublishProblem {
  const QuizPublishProblem(this.message, this.page, {this.questionId});
  final String message;
  final int page;
  final String? questionId;
}

List<QuizPublishProblem> quizPublishProblems(QuizDraft draft, DateTime now) {
  final problems = <QuizPublishProblem>[];
  final opens = DateTime.tryParse(draft.settings['opens_at'] as String? ?? '');
  final closes = DateTime.tryParse(
    draft.settings['closes_at'] as String? ?? '',
  );
  if (opens == null || closes == null) {
    problems.add(
      const QuizPublishProblem(
        'Set the open and close time before publishing.',
        1,
      ),
    );
  }
  if (closes != null &&
      (!closes.isAfter(now) || (opens != null && !closes.isAfter(opens)))) {
    problems.add(
      const QuizPublishProblem(
        'Choose a closing time in the future and after the opening time.',
        1,
      ),
    );
  }
  if (draft.questions.isEmpty) {
    problems.add(
      const QuizPublishProblem(
        'Add at least one question before publishing.',
        2,
      ),
    );
  }
  return problems;
}

String quizPublishSummary(QuizDraft draft) {
  String count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
  final aiCount = aiQuestionCount(draft.questions);
  final reminder = aiCount == 1
      ? '1 question was written by AI. Have you checked it?'
      : '$aiCount questions were written by AI. Have you checked them?';
  return '${count(draft.questionCount, 'question')}, ${count(draft.totalPoints, 'point')}, ${count(draft.settings['time_limit_minutes'] as int, 'minute')}. Students will be notified.${aiCount > 0 ? '\n\n$reminder' : ''}';
}

int aiQuestionCount(Iterable<QuizQuestion> questions) =>
    questions.where((q) => q.aiGenerated).length;

String quizFriendlyError(Object error) {
  final text = error.toString();
  if (text.contains('Set the opening and closing time')) {
    return 'Set the open and close time before publishing.';
  }
  if (text.contains('The closing time must') || text.contains('quiz_window')) {
    return 'Choose a closing time in the future and after the opening time.';
  }
  if (text.contains('Add at least one question')) {
    return 'Add at least one question before publishing.';
  }
  final count = RegExp(r'(\d+) question\(s\) are missing a valid answer key')
      .firstMatch(text)
      ?.group(1);
  if (count != null) {
    return count == '1'
        ? '1 question is missing a correct answer. Check its answer settings.'
        : '$count questions are missing a correct answer. Check their answer settings.';
  }
  if (text.contains('started quiz cannot be deleted') ||
      text.contains('It cannot be deleted.')) {
    return 'A student has already started this assessment. It cannot be deleted.';
  }
  if (text.contains('already been started')) {
    return 'This quiz has already been started. Only the title and closing time can change.';
  }
  if (text.contains('archived')) {
    return 'This class is archived. Assessments are read-only.';
  }
  if (text.contains('offline') || text.contains('Connect to')) {
    return 'Connect to the internet to save, publish, or delete.';
  }
  if (text.contains('Not allowed') ||
      text.contains('42501') ||
      text.contains('OTP') ||
      text.contains('account changed') ||
      text.contains('not available')) {
    return 'This assessment is unavailable or you no longer have permission to change it. Sign in again or refresh Classwork.';
  }
  if (text.contains('Reload and reconcile')) {
    return 'The change could not be confirmed. Refresh Classwork or reload the saved version before trying again.';
  }
  return 'Could not complete this change. Your edits are still here. Check your connection and try again.';
}
