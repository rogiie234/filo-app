import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

enum ResultsAction { load, grade, release, secondChance }

class ResultsFailure implements Exception {
  const ResultsFailure(
    this.message, {
    this.unavailable = false,
    this.uncertain = false,
  });
  final String message;
  final bool unavailable, uncertain;
  @override
  String toString() => message;
}

const resultsUnavailable = ResultsFailure(
  'This item is no longer available.',
  unavailable: true,
);
const resultsUncertain = ResultsFailure(
  "We couldn't confirm the update. Refresh to check before trying again.",
  uncertain: true,
);

String resultsOffline(ResultsAction action) => switch (action) {
  ResultsAction.load => 'Connect to the internet to load results.',
  ResultsAction.grade => 'Connect to the internet to save grades.',
  ResultsAction.release => 'Connect to the internet to release results.',
  ResultsAction.secondChance =>
    'Connect to the internet to allow another attempt.',
};

ResultsFailure resultsFailure(Object error, ResultsAction action) {
  if (error is ResultsFailure) return error;
  final connection =
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is ClientException;
  if (connection && action != ResultsAction.load) return resultsUncertain;
  if (error is PostgrestException) {
    const messages = {
      'Not signed in': 'Sign in to continue.',
      'OTP verification required': 'Verify your account to continue.',
      'Results are not available yet': 'Results will be available once everyone has finished or the quiz closes.',
      'Some students are still taking this quiz':
          'Some students are still taking this quiz.',
      'Grade all essay answers first': 'Grade all essay answers first.',
      'This quiz has not opened yet': 'This quiz has not opened yet.',
      'Results are already released. Create a new quiz instead.':
          'Results are already released. Create a new quiz instead.',
      'Extend the closing time first so the student can retake it':
          'Extend the closing time first so the student can retake it.',
      'This student has no attempt to reset':
          'This student has no attempt to reset.',
      'Please give a reason of at least 10 characters':
          'Please give a reason of at least 10 characters.',
      'This attempt is not submitted yet': 'This attempt is not submitted yet.',
      'This class is archived': 'This class is archived.',
      'Feedback must be at most 2000 characters':
          'Feedback must be at most 2,000 characters.',
    };
    if (messages.containsKey(error.message))
      return ResultsFailure(messages[error.message]!);
    if (RegExp(r'^Points must be between 0 and \d+$').hasMatch(error.message)) {
      return ResultsFailure(error.message);
    }
    if ([
          'Not allowed',
          'Class access denied',
          'Quiz not found',
          'Session not found',
          'Answer not found',
          'Question not found',
          'Class is read-only or inaccessible',
        ].contains(error.message) ||
        error.code == '42501' ||
        error.code == 'PGRST116')
      return resultsUnavailable;
    if (action != ResultsAction.load &&
        (error.code?.startsWith('08') == true ||
            error.code == '57014' ||
            error.code?.startsWith('5') == true))
      return resultsUncertain;
  } else if (action != ResultsAction.load) {
    // A transport/response decoding failure after dispatch does not prove rollback.
    return resultsUncertain;
  }
  return ResultsFailure(switch (action) {
    ResultsAction.load => "Couldn't load results. Try again.",
    ResultsAction.grade => "Couldn't save the grade. Try again.",
    ResultsAction.release => "Couldn't release results. Try again.",
    ResultsAction.secondChance => "Couldn't allow another attempt. Try again.",
  });
}
