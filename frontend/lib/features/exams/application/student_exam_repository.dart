import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/sync/sqlite_outbox.dart';
import '../data/exam_remote.dart';
import '../data/exam_store.dart';
import '../domain/exam.dart';
import '../domain/exam_clock.dart';
import 'exam_answer_saver.dart';

class StudentExamRepository {
  StudentExamRepository({
    required this.store,
    required this.remote,
    required this.isCurrent,
    required this.online,
    this.protectScreen,
    ExamClock? clock,
  }) : clock = clock ?? ExamClock();
  final ExamStore store;
  final ExamRemote remote;
  final bool Function() isCurrent, online;
  final Future<void> Function(bool)? protectScreen;
  final ExamClock clock;
  final _changes = StreamController<int>.broadcast();
  int _revision = 0;
  int _attemptEpoch = 0;
  Stream<int> get changes => _changes.stream;
  ExamAttempt? active;
  ExamAnswerSaver? saver;
  ExamFailure? error;
  String? completion;
  bool _disposed = false, _submitting = false;
  Future<void>? _submission;
  Timer? _submissionRetry;
  final _answerWrites = <Future<void>>{};
  final _failedAnswerWrites = <String>{};
  bool submissionRequested = false;
  bool completionTimedOut = false;
  Future<void>? _recovering;
  Future<void>? _loading;
  Future<void>? _starting;
  String? pendingQuizId, pendingSessionId;
  bool startUncertain = false;
  bool get starting => _starting != null;
  bool get engaged =>
      active != null || pendingSessionId != null || startUncertain;
  Future<StudentQuizCatalog>? _catalogRefresh;
  bool get current => !_disposed && isCurrent();
  bool get submitting => _submitting;
  void notify() {
    if (current) _changes.add(++_revision);
  }

  void _check() {
    if (!current) throw const ExamFailure('Sign in to continue.');
  }

  void _connected() {
    _check();
    if (!online())
      throw const ExamFailure(
        'Connect to the internet to continue.',
        retryable: true,
      );
  }

  Future<ExamSession?> status(String quizId) async {
    _connected();
    final epoch = _attemptEpoch;
    final json = await remote.session(quizId);
    _check();
    final session = json == null ? null : ExamSession(json);
    if (session != null && epoch == _attemptEpoch)
      await store.confirmSession(quizId, session);
    return session;
  }

  Future<List<StudentQuiz>> quizzes() async {
    _connected();
    final rows = await remote.quizzes();
    _check();
    final result = <StudentQuiz>[];
    for (final row in rows) {
      result.add(StudentQuiz(row, await status(row['id'] as String)));
    }
    return result;
  }

  Future<StudentQuizCatalog> cachedCatalog() async {
    _check();
    final value = await store.catalog();
    _check();
    return value;
  }

  Future<StudentQuizCatalog> refreshCatalog() => _catalogRefresh ??=
      _refreshCatalog().whenComplete(() => _catalogRefresh = null);

  Future<StudentQuizCatalog> _refreshCatalog() async {
    final epoch = _attemptEpoch;
    final cached = await cachedCatalog();
    if (!online()) return cached;
    try {
      final rows = await remote.quizzes();
      _check();
      var failed = false;
      final quizzes = <StudentQuiz>[];
      for (final row in rows) {
        final id = row['id'] as String;
        try {
          quizzes.add(StudentQuiz(row, await status(id)));
        } catch (_) {
          _check();
          failed = true;
          final previous = cached.quizzes.where((q) => q.id == id).firstOrNull;
          quizzes.add(StudentQuiz(row, previous?.session, sessionKnown: false));
        }
      }
      _check();
      if (epoch != _attemptEpoch) return cachedCatalog();
      await store.saveCatalog(quizzes);
      _check();
      final saved = await cachedCatalog();
      return StudentQuizCatalog(saved.quizzes, loaded: true, failed: failed);
    } catch (_) {
      _check();
      return StudentQuizCatalog(
        cached.quizzes,
        loaded: cached.loaded,
        failed: true,
      );
    }
  }

  void _activate(ExamAttempt attempt) {
    saver?.dispose();
    active = attempt;
    completion = null;
    completionTimedOut = false;
    saver = ExamAnswerSaver(
      store: store,
      remote: remote,
      clock: clock,
      sessionId: attempt.sessionId,
      isCurrent: () => current,
      online: online,
      onChanged: notify,
      onReconcile: () async {
        if (!_submitting) await reconcile();
      },
    );
    notify();
  }

  Future<void> load(String sessionId) =>
      _loading ??= _load(sessionId).whenComplete(() => _loading = null);
  Future<void> _load(String sessionId) async {
    _connected();
    await protectScreen?.call(true);
    _check();
    final epoch = _attemptEpoch;
    final previousSaver = saver;
    await previousSaver?.pause();
    try {
      final requestWall = clock.wallNow().toUtc();
      final requestElapsed = clock.elapsed();
      final json = await remote.exam(sessionId);
      final responseElapsed = clock.elapsed();
      _check();
      if (epoch != _attemptEpoch) return;
      final attempt = ExamAttempt(json);
      clock.synchronize(
        serverNow: attempt.serverNow,
        deadline: attempt.deadline,
        requestWall: requestWall,
        requestElapsed: requestElapsed,
        responseElapsed: responseElapsed,
      );
      final deviceAtReceipt = requestWall.add(responseElapsed - requestElapsed);
      await store.cache(attempt, clock.serverNow, deviceAtReceipt);
      _check();
      if (epoch != _attemptEpoch) return;
      error = null;
      pendingSessionId = null;
      pendingQuizId = null;
      startUncertain = false;
      _activate(attempt);
      saver!.reconnect();
    } catch (_) {
      if (current) previousSaver?.resume();
      rethrow;
    }
  }

  Future<void> start(String quizId) =>
      _starting ??= _start(quizId).whenComplete(() async {
        try {
          if (current && !engaged) await protectScreen?.call(false);
        } finally {
          _starting = null;
          notify();
        }
      });

  Future<void> _start(String quizId) async {
    await _recovering;
    _check();
    if (!online()) {
      throw const ExamFailure(
        'Connect to the internet to start.',
        retryable: true,
      );
    }
    if (active != null)
      throw const ExamFailure(
        'Resume your current exam before starting another.',
      );
    if (pendingQuizId != null && pendingQuizId != quizId) {
      throw const ExamFailure(
        'Resume your current exam before starting another.',
      );
    }
    await protectScreen?.call(true);
    _check();
    final existing = await status(quizId);
    if (existing != null) {
      startUncertain = false;
      if (existing.inProgress) {
        pendingQuizId = quizId;
        pendingSessionId = existing.id;
        notify();
        return load(existing.id);
      }
      pendingQuizId = null;
      pendingSessionId = null;
      throw const ExamFailure('You have already taken this quiz.');
    }
    // A confirmed session is never replaced when a later status read is empty.
    if (pendingSessionId != null) return load(pendingSessionId!);
    startUncertain = false;
    pendingQuizId = quizId;
    try {
      startUncertain = true;
      notify();
      final row = await remote.start(quizId);
      _check();
      pendingSessionId = row['id'] as String;
      startUncertain = false;
      // Persist the confirmed attempt even if get_exam or the process fails next.
      if (row['deadline_at'] != null && row['started_at'] != null) {
        final now = clock.wallNow().toUtc();
        await store.cache(
          ExamAttempt({
            'session_id': pendingSessionId,
            'quiz_id': quizId,
            'started_at': row['started_at'],
            'deadline_at': row['deadline_at'],
            'server_now': now.toIso8601String(),
            'questions': <ExamJson>[],
          }),
          now,
          now,
        );
        _check();
      }
      notify();
      await load(pendingSessionId!);
    } catch (e) {
      final failure = examFailure(e);
      if (pendingSessionId == null &&
          !failure.connection &&
          !failure.retryable &&
          failure.message != "We couldn't complete that request. Try again.") {
        startUncertain = false;
        pendingQuizId = null;
      }
      // Start may have committed even when its response was lost.
      if (current && online()) {
        try {
          final found = await status(quizId);
          if (found?.inProgress == true) {
            pendingQuizId = quizId;
            pendingSessionId = found!.id;
            startUncertain = false;
            notify();
            return await load(found.id);
          }
          if (found?.submitted == true) {
            completionTimedOut = found!.status == 'auto_submitted';
            await _finish(found.id, 'Your answers were submitted.');
            return;
          }
          if (found == null && pendingSessionId == null) {
            startUncertain = false;
            pendingQuizId = null;
          }
        } catch (_) {
          // Keep the original error and attempt identity if reconciliation fails.
        }
      }
      throw failure;
    }
  }

  Future<void> recover() =>
      _recovering ??= _recover().whenComplete(() => _recovering = null);
  Future<void> _recover() async {
    if (!current || starting || _submitting) return;
    try {
      error = null;
      final local = (await store.attempts())
          .where(
            (saved) =>
                (pendingQuizId == null ||
                    saved.attempt.quizId == pendingQuizId) &&
                (pendingSessionId == null ||
                    saved.attempt.sessionId == pendingSessionId),
          )
          .toList();
      _check();
      if (active == null && local.isNotEmpty) {
        pendingQuizId = local.first.attempt.quizId;
        pendingSessionId = local.first.attempt.sessionId;
        notify();
        await protectScreen?.call(true);
        _check();
        final saved = local.first;
        clock.restore(
          serverAtReceipt: saved.serverAtReceipt,
          deviceAtReceipt: saved.deviceAtReceipt,
          deadline: saved.attempt.deadline,
        );
        _activate(saved.attempt);
        pendingQuizId = null;
        pendingSessionId = null;
      }
      if (active == null && pendingQuizId != null) {
        final session = await status(pendingQuizId!);
        if (session?.inProgress == true) {
          pendingSessionId = session!.id;
          startUncertain = false;
          await load(session.id);
        } else if (session?.submitted == true) {
          completionTimedOut = session!.status == 'auto_submitted';
          await _finish(session.id, 'Your answers were submitted.');
        } else if (pendingSessionId != null) {
          await _finish(pendingSessionId!, 'This attempt has ended.');
        } else {
          startUncertain = false;
          pendingQuizId = null;
        }
        return;
      }
      if (active != null) {
        submissionRequested =
            submissionRequested ||
            await store.submissionRequested(active!.sessionId);
        if (clock.verified && (submissionRequested || clock.expired)) {
          await submit();
          return;
        }
      }
      if (!online()) {
        error = ExamFailure(
          clock.verified
              ? 'Connect to the internet to check your exam status.'
              : 'Reconnect to verify your remaining time before continuing.',
          retryable: true,
        );
        return;
      }
      if (active != null) {
        if (!clock.verified ||
            !clock.canEdit ||
            active!.questions.isEmpty ||
            saver?.error?.reconcile == true) {
          await reconcile();
          if (active != null &&
              clock.verified &&
              (submissionRequested || clock.expired)) {
            await submit();
          }
        } else {
          saver?.reconnect();
        }
        return;
      }
      final rows = await remote.quizzes();
      _check();
      for (final row in rows) {
        if (row['class_archived'] == true) continue;
        final quiz = StudentQuiz(row, null);
        final session = await status(quiz.id);
        if (session?.inProgress == true) {
          pendingQuizId = quiz.id;
          pendingSessionId = session!.id;
          notify();
          await load(session.id);
          return;
        }
      }
    } catch (e) {
      if (current) error = examFailure(e);
    } finally {
      if (current && !engaged && !starting) await protectScreen?.call(false);
      notify();
    }
  }

  Future<void> reconcile() async {
    final attempt = active;
    if (attempt == null) return;
    final session = await status(attempt.quizId);
    if (active?.sessionId != attempt.sessionId) return;
    if (session == null ||
        session.id != attempt.sessionId ||
        !session.inProgress) {
      completionTimedOut = session?.status == 'auto_submitted';
      await _finish(
        attempt.sessionId,
        session?.submitted == true
            ? 'Your answers were submitted.'
            : 'This attempt has ended.',
      );
      if (session?.inProgress == true) await load(session!.id);
      return;
    }
    await load(attempt.sessionId);
  }

  Future<List<StoredAnswer>> answers() async {
    final id = active?.sessionId;
    return id == null ? [] : store.answers(id);
  }

  Future<void> answer(ExamAnswer answer) {
    final work = _answer(answer);
    _answerWrites.add(work);
    return work.whenComplete(() => _answerWrites.remove(work));
  }

  Future<void> _answer(ExamAnswer answer) async {
    _check();
    final attempt = active;
    if (attempt == null || _submitting || submissionRequested)
      throw const ExamFailure('This attempt is no longer accepting answers.');
    final questions = attempt.questions.where((q) => q.id == answer.questionId);
    if (questions.isEmpty)
      throw const ExamFailure('This question is unavailable.');
    final question = questions.single;
    if ((question.type == 'multiple_choice' &&
            (answer.boolean != null ||
                answer.text != null ||
                answer.optionId != null &&
                    !question.options.any(
                      (o) => o['id'] == answer.optionId,
                    ))) ||
        (question.type == 'true_false' &&
            (answer.optionId != null || answer.text != null)) ||
        (!['multiple_choice', 'true_false'].contains(question.type) &&
            (answer.optionId != null || answer.boolean != null))) {
      throw const ExamFailure('This answer option is unavailable.');
    }
    try {
      final worker = saver!;
      await worker.change(answer);
      _failedAnswerWrites.remove(answer.questionId);
      if (current &&
          active?.sessionId == attempt.sessionId &&
          saver != worker) {
        notify();
        saver?.reconnect();
      }
      error = null;
    } catch (e) {
      _failedAnswerWrites.add(answer.questionId);
      error = e is ExamFailure
          ? e
          : const ExamFailure(
              "Couldn't save this answer on your phone. Try again.",
            );
      notify();
      throw error!;
    }
  }

  Future<void> submit() =>
      _submission ??= _submit().whenComplete(() => _submission = null);

  Future<void> _submit() async {
    _check();
    final attempt = active;
    if (attempt == null) return;
    if (!clock.verified) {
      throw const ExamFailure(
        'Reconnect to verify your remaining time before continuing.',
        retryable: true,
      );
    }
    submissionRequested = true;
    _submitting = true;
    _submissionRetry?.cancel();
    notify();
    try {
      await store.requestSubmission(attempt.sessionId);
      if (!online())
        throw ExamFailure(
          clock.canEdit
              ? "You're offline. Stay on this screen and reconnect to submit. The timer keeps running."
              : clock.timeoutMessage,
          retryable: true,
        );
      // A retry checks the existing attempt before sending anything again.
      final requestWall = clock.wallNow().toUtc();
      final requestElapsed = clock.elapsed();
      final session = await status(attempt.quizId);
      if (!current || active?.sessionId != attempt.sessionId) return;
      if (session == null ||
          session.id != attempt.sessionId ||
          !session.inProgress) {
        await reconcile();
        return;
      }
      clock.synchronize(
        serverNow: session.serverNow,
        deadline: session.deadline,
        requestWall: requestWall,
        requestElapsed: requestElapsed,
        responseElapsed: clock.elapsed(),
      );
      await Future.wait(_answerWrites.toList());
      if (clock.canEdit && _failedAnswerWrites.isNotEmpty) {
        throw saver?.error ??
            error ??
            const ExamFailure(
              "Couldn't save this answer on your phone. Try again.",
            );
      }
      final worker = saver!;
      if (clock.canSend) {
        final budget = attempt.deadline
            .add(const Duration(seconds: 14))
            .difference(clock.serverNow);
        try {
          await worker.drain().timeout(budget);
        } on TimeoutException {
          // The server decides whether an already dispatched batch arrived in time.
        }
      }
      _check();
      if (active?.sessionId != attempt.sessionId) return;
      if (!await worker.allSent() && clock.canSend) {
        throw worker.error ??
            const ExamFailure(
              'Some answers are still waiting to save. Reconnect and try again.',
              retryable: true,
            );
      }
      if (!clock.canSend) worker.dispose();
      final result = await remote.submit(attempt.sessionId);
      _check();
      if (active?.sessionId != attempt.sessionId) return;
      if (result['status'] == 'submitted' ||
          result['status'] == 'auto_submitted') {
        await store.confirmSession(
          attempt.quizId,
          ExamSession({
            'session_id': attempt.sessionId,
            'deadline_at': attempt.deadline.toIso8601String(),
            'server_now': clock.serverNow.toIso8601String(),
            'status': result['status'],
            'submitted_at': result['submitted_at'],
          }),
        );
        completionTimedOut = result['status'] == 'auto_submitted';
        await _finish(attempt.sessionId, 'Your answers were submitted.');
      } else {
        await reconcile();
        if (active != null)
          throw const ExamFailure(
            "We couldn't confirm your submission. Stay on this screen and reconnect to check.",
            retryable: true,
          );
      }
    } catch (e) {
      if (!current) rethrow;
      if (active != null && online()) {
        try {
          final session = await status(attempt.quizId);
          if (session?.id == attempt.sessionId && session?.submitted == true) {
            completionTimedOut = session!.status == 'auto_submitted';
            await _finish(attempt.sessionId, 'Your answers were submitted.');
          }
        } catch (_) {
          // Keep durable work until confirmation.
        }
      }
      if (active != null) {
        final failure = examFailure(e);
        error =
            failure.connection ||
                failure.message ==
                    "We couldn't complete that request. Try again."
            ? ExamFailure(
                clock.canEdit
                    ? "We couldn't confirm your submission. Stay on this screen and reconnect to check."
                    : clock.timeoutMessage,
                retryable: true,
              )
            : failure;
        // Validation errors must remain editable; transport failures keep intent.
        if (!error!.retryable && !error!.reconcile && clock.canEdit) {
          submissionRequested = false;
          await store.cancelSubmission(attempt.sessionId);
        }
        if (submissionRequested) {
          _submissionRetry = Timer(const Duration(seconds: 1), () {
            if (current && online())
              unawaited(submit().catchError((Object _) {}));
          });
        }
        throw error!;
      }
    } finally {
      _submitting = false;
      notify();
    }
  }

  Future<void> _finish(String sessionId, String message) async {
    _attemptEpoch++;
    _submissionRetry?.cancel();
    saver?.dispose();
    saver = null;
    await Future.wait(
      _answerWrites.toList().map((work) => work.catchError((Object _) {})),
    );
    await store.clear(sessionId);
    _check();
    active = null;
    _failedAnswerWrites.clear();
    pendingQuizId = null;
    pendingSessionId = null;
    startUncertain = false;
    submissionRequested = false;
    completion = message;
    error = null;
    clock.invalidate();
    await protectScreen?.call(false);
    notify();
  }

  Future<void> Function()? captureLeave() {
    final sessionId = active?.sessionId ?? pendingSessionId;
    if (!current ||
        sessionId == null ||
        clock.deadline == null ||
        !clock.canEdit)
      return null;
    final id = const Uuid().v4();
    final leftAt = clock.serverNow.toUtc().toIso8601String();
    return () async {
      if (!current) return;
      await SqliteOutbox(store.db).enqueue(id, 'leave_event', {
        'session_id': sessionId,
        'left_at': leftAt,
      });
    };
  }

  Future<void> logLeave() async => await captureLeave()?.call();

  void dispose() {
    _disposed = true;
    _submissionRetry?.cancel();
    saver?.dispose();
    clock.invalidate();
    unawaited(
      protectScreen?.call(false).catchError((Object _) {}) ??
          Future<void>.value(),
    );
    unawaited(_changes.close());
  }
}
