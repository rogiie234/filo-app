import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm, BooleanExpressionOperators;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ai/ai_cancellation.dart';
import '../../../data/local/app_database.dart';
import '../data/student_ai_client.dart';
import '../data/study_repositories.dart';
import '../domain/study_ai.dart';
import '../domain/study_inputs.dart';

const studyQuizBusyMessage =
    'The AI assistant is busy right now. Please try again in a few minutes.';
const studyQuizLimitMessage =
    'You can have up to 10 quizzes in a notebook. Delete a quiz to add another.';
const studyQuizSaveError =
    'Could not confirm this quiz was saved. Keep this screen open and try saving again.';

class StudyQuizGeneration extends ChangeNotifier {
  StudyQuizGeneration({
    required this.notebookId,
    required this.repository,
    required this.client,
    required this.isCurrent,
    required this.isOnline,
  });
  final String notebookId;
  final StudyQuizRepository repository;
  final StudentAiClient client;
  final bool Function() isCurrent, isOnline;
  StudyAiResult<StudyAiBatch<StudyQuestionInput>>? result;
  StudyQuizSettings? _settings;
  String? error, savedId, _pendingId;
  bool working = false, saving = false, _disposed = false;
  int _epoch = 0;
  AiCancelToken? _cancel;
  bool get current => !_disposed && isCurrent();
  bool get hasUnsaved => result != null && savedId == null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> generate(StudyQuizSettings settings) async {
    if (!current || working || result != null) return;
    try {
      settings.validate();
    } catch (_) {
      error = studyAiMessages['INVALID_REQUEST'];
      _changed();
      return;
    }
    if (!isOnline() || client.guard.isBusy) {
      error = studyAiMessages[isOnline() ? 'AI_IN_PROGRESS' : 'OFFLINE'];
      _changed();
      return;
    }
    final epoch = ++_epoch, token = AiCancelToken();
    _cancel = token;
    working = true;
    error = null;
    _changed();
    bool valid() => current && epoch == _epoch && !token.isCancelled;
    try {
      final answer = await client.practiceQuiz(
        notebookId: notebookId,
        settings: settings,
        cancel: token,
      );
      if (!valid()) return;
      result = answer;
      _settings = settings;
      _pendingId = const Uuid().v4();
      await _save(valid);
    } catch (failure) {
      if (valid()) {
        error = failure is StudyAiFailure && failure.code == 'AI_BUSY'
            ? studyQuizBusyMessage
            : studyAiFriendlyError(failure);
      }
    } finally {
      token.cancel();
      if (current && epoch == _epoch) {
        _cancel = null;
        working = false;
        saving = false;
        _changed();
      }
    }
  }

  Future<void> _save(bool Function() valid) async {
    saving = true;
    _changed();
    try {
      final title = _settings!.topicFocus.trim();
      final id = await repository.create(
        notebookId: notebookId,
        title: title.isEmpty ? 'Practice quiz' : title,
        settings: _settings!,
        questions: result!.value.items,
        quizId: _pendingId,
        canCommit: valid,
      );
      if (valid()) {
        savedId = id;
        error = null;
      }
    } on StudyLimitExceeded {
      if (valid()) error = studyQuizLimitMessage;
    } catch (_) {
      if (valid()) error = studyQuizSaveError;
    }
  }

  Future<void> retrySave() async {
    if (!current || working || !hasUnsaved) return;
    final epoch = ++_epoch;
    working = true;
    error = null;
    _changed();
    await _save(() => current && epoch == _epoch);
    if (current && epoch == _epoch) {
      working = false;
      saving = false;
      _changed();
    }
  }

  void cancel() {
    if (!working || saving) return;
    _cancel?.cancel();
    ++_epoch;
    working = false;
    error = studyAiMessages['CANCELLED'];
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _cancel?.cancel();
    super.dispose();
  }
}

String normalizeStudyAnswer(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
List<String> quizOptions(StudyQuestion question) => question.options == null
    ? []
    : List<String>.from(jsonDecode(question.options!) as List);
String quizCorrectAnswer(StudyQuestion question) => switch (question.type) {
  'multiple_choice' => quizOptions(question)[question.correctIndex!],
  'true_false' => question.correctBoolean! ? 'True' : 'False',
  _ => (jsonDecode(question.acceptedAnswers!) as List).join(' / '),
};
String quizAnswerText(StudyQuestion question, Object answer) =>
    switch (question.type) {
      'multiple_choice' => quizOptions(question)[answer as int],
      'true_false' => answer == true ? 'True' : 'False',
      _ => answer.toString(),
    };
bool gradeStudyAnswer(StudyQuestion question, Object answer) =>
    switch (question.type) {
      'multiple_choice' => answer is int && answer == question.correctIndex,
      'true_false' => answer is bool && answer == question.correctBoolean,
      'identification' =>
        answer is String &&
            normalizeStudyAnswer(answer).isNotEmpty &&
            (jsonDecode(question.acceptedAnswers!) as List).cast<String>().any(
              (accepted) =>
                  normalizeStudyAnswer(accepted) ==
                  normalizeStudyAnswer(answer),
            ),
      _ => false,
    };

class StudyQuizSession extends ChangeNotifier {
  StudyQuizSession({
    required this.notebookId,
    required this.quizId,
    required this.repository,
    required this.isCurrent,
    Random? random,
  }) : _random = random ?? Random();
  final String notebookId, quizId;
  final StudyAttemptRepository repository;
  final bool Function() isCurrent;
  final Random _random;
  List<StudyQuestion> questions = [];
  final List<StudyQuestionResult> results = [];
  final Map<String, List<int>> optionOrder = {};
  Object? answer;
  String? error, savedId;
  String _attemptId = const Uuid().v4();
  int index = 0;
  bool loading = true,
      saving = false,
      checked = false,
      complete = false,
      _disposed = false;
  bool get current => !_disposed && isCurrent();
  StudyQuestion? get question =>
      questions.isEmpty || complete ? null : questions[index];
  int get score => results.where((r) => r.correct).length;
  bool get canCheck =>
      answer != null &&
      (answer is! String || (answer as String).trim().isNotEmpty) &&
      !checked &&
      !saving;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open() async {
    if (!current || saving) return;
    loading = true;
    error = null;
    _changed();
    try {
      final db = repository.db;
      final quiz =
          await (db.select(db.practiceQuizzes)..where(
                (q) => q.id.equals(quizId) & q.notebookId.equals(notebookId),
              ))
              .getSingleOrNull();
      if (quiz == null) throw StateError('Quiz unavailable');
      final saved =
          await (db.select(db.practiceQuestions)
                ..where((q) => q.quizId.equals(quizId))
                ..orderBy([(q) => OrderingTerm.asc(q.position)]))
              .get();
      if (!current) return;
      questions = saved;
      _reset(shuffle: false);
    } catch (_) {
      if (current) error = studyAiMessages['LOAD_FAILED'];
    } finally {
      if (current) {
        loading = false;
        _changed();
      }
    }
  }

  void _reset({required bool shuffle}) {
    results.clear();
    index = 0;
    checked = complete = saving = false;
    answer = null;
    savedId = error = null;
    _attemptId = const Uuid().v4();
    optionOrder.clear();
    for (final q in questions.where((q) => q.type == 'multiple_choice')) {
      final order = List.generate(quizOptions(q).length, (i) => i);
      if (shuffle) order.shuffle(_random);
      optionOrder[q.id] = order;
    }
  }

  void select(Object value) {
    if (!current || checked || saving || complete) return;
    answer = value;
    _changed();
  }

  void check() {
    if (!current || !canCheck || question == null) return;
    final q = question!;
    results.add(
      StudyQuestionResult(
        questionId: q.id,
        answer: answer!,
        correct: gradeStudyAnswer(q, answer!),
      ),
    );
    checked = true;
    _changed();
  }

  Future<void> next() async {
    if (!current || !checked || saving || complete) return;
    if (index + 1 < questions.length) {
      index++;
      answer = null;
      checked = false;
      _changed();
    } else {
      complete = true;
      _changed();
      await save();
    }
  }

  Future<void> save() async {
    if (!current || !complete || saving || savedId != null) return;
    saving = true;
    error = null;
    _changed();
    try {
      final id = await repository.save(
        quizId,
        List.of(results),
        attemptId: _attemptId,
        canCommit: () => current,
      );
      if (current) savedId = id;
    } catch (_) {
      if (current) error = 'Could not confirm this attempt was saved. Keep this screen open and try saving again.';
    } finally {
      if (current) {
        saving = false;
        _changed();
      }
    }
  }

  void retake() {
    if (!current || !complete || savedId == null || saving) return;
    _reset(shuffle: true);
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
