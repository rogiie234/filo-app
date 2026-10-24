import 'dart:async';

import 'package:filo/features/exams/data/exam_remote.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/exams/domain/exam_clock.dart';

final examEpoch = DateTime.utc(2026, 10, 23, 8);
ExamJson examPayload({List<ExamJson> saved = const []}) => {
  'session_id': 'session',
  'quiz_id': 'quiz',
  'started_at': examEpoch.toIso8601String(),
  'deadline_at': examEpoch.add(const Duration(minutes: 10)).toIso8601String(),
  'server_now': examEpoch.toIso8601String(),
  'questions': [
    {
      'id': 'q',
      'type': 'identification',
      'prompt': 'Name',
      'points': 1,
      'options': null,
    },
    {
      'id': 'bool',
      'type': 'true_false',
      'prompt': 'True?',
      'points': 1,
      'options': null,
    },
    {
      'id': 'choice',
      'type': 'multiple_choice',
      'prompt': 'Choose',
      'points': 1,
      'options': [
        {'id': 'option', 'text': 'One'},
        {'id': 'other', 'text': 'Two'},
      ],
    },
    {
      'id': 'essay',
      'type': 'essay',
      'prompt': 'Explain',
      'points': 1,
      'options': null,
    },
  ],
  'saved_answers': saved,
};
ExamJson sessionPayload([String status = 'in_progress']) => {
  'session_id': 'session',
  'status': status,
  'deadline_at': examEpoch.add(const Duration(minutes: 10)).toIso8601String(),
  'server_now': examEpoch.toIso8601String(),
};

class FakeExamTime {
  DateTime wall = examEpoch;
  Duration elapsed = Duration.zero;
  late final clock = ExamClock(wallNow: () => wall, elapsed: () => elapsed);
  void synchronize() => clock.synchronize(
    serverNow: examEpoch,
    deadline: examEpoch.add(const Duration(minutes: 10)),
    requestWall: wall,
    requestElapsed: elapsed,
    responseElapsed: elapsed,
  );
}

class FakeExamRemote implements ExamRemote {
  final calls = <String>[];
  final saves = <ExamAnswer>[];
  final batches = <List<StoredAnswer>>[];
  final itemErrors = <String, ExamFailure>{};
  Future<List<ExamSaveReceipt>> Function(List<StoredAnswer>)? onBatch;
  List<ExamJson> rows = [
    {
      'id': 'quiz',
      'title': 'Quiz',
      'opens_at': examEpoch
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'closes_at': examEpoch.add(const Duration(hours: 1)).toIso8601String(),
    },
  ];
  ExamJson? currentSession = sessionPayload();
  ExamJson payload = examPayload();
  Object? sessionError, saveError, quizError;
  Future<void> Function(ExamAnswer)? onSave;
  Future<ExamJson> Function()? onExam;
  Future<ExamJson> Function()? onSubmit;
  Future<ExamJson> Function()? onStart;
  @override
  Future<List<ExamJson>> quizzes() async {
    calls.add('quizzes');
    if (quizError != null) throw quizError!;
    return rows;
  }

  @override
  Future<ExamJson?> session(String quizId) async {
    calls.add('session:$quizId');
    if (sessionError != null) throw sessionError!;
    return currentSession;
  }

  @override
  Future<ExamJson> exam(String sessionId) async {
    calls.add('exam:$sessionId');
    return onExam == null ? payload : onExam!();
  }

  @override
  Future<ExamJson> start(String quizId) async {
    calls.add('start:$quizId');
    if (onStart != null) return onStart!();
    currentSession = sessionPayload();
    return {
      'id': 'session',
      'started_at': examEpoch.toIso8601String(),
      'deadline_at': examEpoch
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    };
  }

  @override
  Future<void> save(String sessionId, ExamAnswer answer) async {
    calls.add('save:${answer.questionId}');
    saves.add(answer);
    if (saveError != null) throw saveError!;
    await onSave?.call(answer);
  }

  @override
  Future<List<ExamSaveReceipt>> saveBatch(
    String sessionId,
    List<StoredAnswer> answers,
  ) async {
    batches.add(List.of(answers));
    if (onBatch != null) return onBatch!(answers);
    final receipts = <ExamSaveReceipt>[];
    for (final stored in answers) {
      final failure = itemErrors[stored.answer.questionId];
      if (failure == null) await save(sessionId, stored.answer);
      receipts.add(
        ExamSaveReceipt(
          questionId: stored.answer.questionId,
          revision: stored.revision,
          savedAt: failure == null ? examEpoch : null,
          failure: failure,
        ),
      );
    }
    return receipts;
  }

  @override
  Future<ExamJson> submit(String sessionId) async {
    calls.add('submit:$sessionId');
    if (onSubmit != null) return onSubmit!();
    currentSession = sessionPayload('submitted');
    return {'status': 'submitted'};
  }
}
