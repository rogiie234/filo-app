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
    final json = await remote.session(quizId);
    _check();
    return json == null ? null : ExamSession(json);
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
    saver = ExamAnswerSaver(
      store: store,
      remote: remote,
      clock: clock,
      sessionId: attempt.sessionId,
      isCurrent: () => current,
      online: online,
      onChanged: notify,
      onReconcile: () => reconcile(),
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
      _starting ??= _start(quizId).whenComplete(() {
        _starting = null;
        notify();
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
            await _finish(found!.id, 'Your answers were submitted.');
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
    if (!current || starting) return;
    try {
      error = null;
      if (active == null && pendingQuizId != null) {
        final session = await status(pendingQuizId!);
        if (session?.inProgress == true) {
          pendingSessionId = session!.id;
          startUncertain = false;
          await load(session.id);
        } else if (session?.submitted == true) {
          await _finish(session!.id, 'Your answers were submitted.');
        } else if (pendingSessionId != null) {
          await _finish(pendingSessionId!, 'This attempt has ended.');
        } else {
          startUncertain = false;
          pendingQuizId = null;
        }
        return;
      }
      final local = await store.attempts();
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
      if (!online()) {
        error = const ExamFailure(
          'Connect to the internet to check your exam status.',
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

  Future<void> answer(ExamAnswer answer) async {
    _check();
    final attempt = active;
    if (attempt == null || _submitting)
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
      if (current &&
          active?.sessionId == attempt.sessionId &&
          saver != worker) {
        notify();
        saver?.reconnect();
      }
      error = null;
    } catch (e) {
      error = e is ExamFailure
          ? e
          : const ExamFailure(
              "Couldn't save this answer on your phone. Try again.",
            );
      notify();
      throw error!;
    }
  }

  Future<void> submit() async {
    _check();
    if (!online())
      throw const ExamFailure(
        "You're offline. Stay on this screen and reconnect to submit. The timer keeps running.",
        retryable: true,
      );
    if (_submitting || active == null) return;
    _submitting = true;
    final attempt = active!;
    notify();
    try {
      if (!clock.verified) await reconcile();
      if (active == null) return;
      final worker = saver!;
      await worker.flush();
      _check();
      if (active == null) return;
      if (!await worker.allSent() && clock.canSend) {
        throw const ExamFailure(
          'Some answers are still waiting to save. Reconnect and try again.',
          retryable: true,
        );
      }
      _check();
      if (active?.sessionId != attempt.sessionId) return;
      await remote.submit(attempt.sessionId);
      _check();
      await reconcile();
      if (active != null)
        throw const ExamFailure(
          "We couldn't confirm your submission. Stay on this screen and reconnect to check.",
        );
    } catch (e) {
      if (current && active != null) {
        try {
          await reconcile();
        } catch (_) {
          /* Keep durable work until confirmation. */
        }
      }
      if (active != null) {
        final failure = examFailure(e);
        error =
            failure.connection ||
                failure.message ==
                    "We couldn't complete that request. Try again."
            ? const ExamFailure(
                "We couldn't confirm your submission. Stay on this screen and reconnect to check.",
                retryable: true,
              )
            : failure;
        throw error!;
      }
    } finally {
      _submitting = false;
      notify();
    }
  }

  Future<void> _finish(String sessionId, String message) async {
    _attemptEpoch++;
    saver?.dispose();
    saver = null;
    await store.clear(sessionId);
    _check();
    active = null;
    pendingQuizId = null;
    pendingSessionId = null;
    startUncertain = false;
    completion = message;
    error = null;
    clock.invalidate();
    notify();
  }

  Future<void> logLeave() async {
    final sessionId = active?.sessionId ?? pendingSessionId;
    if (!current || sessionId == null) return;
    await SqliteOutbox(store.db).enqueue(const Uuid().v4(), 'leave_event', {
      'session_id': sessionId,
      'left_at': (active == null ? clock.wallNow() : clock.serverNow)
          .toUtc()
          .toIso8601String(),
    });
  }

  void dispose() {
    _disposed = true;
    saver?.dispose();
    clock.invalidate();
    unawaited(
      protectScreen?.call(false).catchError((Object _) {}) ??
          Future<void>.value(),
    );
    unawaited(_changes.close());
  }
}
