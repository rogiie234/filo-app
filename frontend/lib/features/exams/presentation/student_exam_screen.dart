import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/class_providers.dart';
import '../application/exam_providers.dart';
import '../application/student_exam_repository.dart';
import '../data/exam_remote.dart';
import '../domain/exam.dart';
import '../domain/student_quiz_status.dart';
import 'exam_question_card.dart';
import 'student_quiz_overview.dart';

// One route owns quiz details, confirmation, answering and completion.
class ExamNavigation {
  bool open = false;
}

final examNavigationProvider = Provider((ref) => ExamNavigation());

Future<void> openStudentExam(
  BuildContext context,
  WidgetRef ref,
  StudentExamHandoff request,
) async {
  final navigation = ref.read(examNavigationProvider);
  if (navigation.open) return;
  navigation.open = true;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'student-exam'),
        builder: (_) => StudentExamScreen(request: request),
      ),
    );
  } finally {
    navigation.open = false;
  }
}

class StudentExamScreen extends ConsumerStatefulWidget {
  const StudentExamScreen({super.key, required this.request, this.classId});
  final StudentExamHandoff request;
  final String? classId;
  @override
  ConsumerState<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends ConsumerState<StudentExamScreen> {
  bool _understood = false, _busy = false, _resumed = false;
  bool _essay = false;
  bool _startBlocked = false;
  String? _expirySession;
  DialogRoute<bool>? _confirmationRoute;
  String? _message, _session;
  StudentExamRepository? _repository;
  final _edits = <String, ExamAnswer>{};
  final _unsaved = <String>{};
  final _revisions = <String, int>{};
  int _writes = 0;
  late final ExamNavigation _navigation;
  bool _ownsNavigation = false;

  @override
  void initState() {
    super.initState();
    _navigation = ref.read(examNavigationProvider);
    if (!_navigation.open) {
      _navigation.open = true;
      _ownsNavigation = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (ref.read(studentExamRepositoryProvider).hasError) {
        ref.invalidate(studentExamRepositoryProvider);
      }
      final r = await ref.read(studentExamRepositoryProvider.future);
      if (!mounted) return;
      if (r == null) throw const ExamFailure('Sign in to continue.');
      _repository = r;
      if (r.engaged) {
        if (r.starting) return;
        await r.recover();
        if (r.error != null) throw r.error!;
        _resumed = r.active != null && r.clock.canEdit;
      } else if (widget.request.sessionId != null) {
        r.pendingQuizId = widget.request.quizId;
        r.pendingSessionId = widget.request.sessionId;
        await r.recover();
        if (r.error != null) throw r.error!;
        _resumed = r.active != null && r.clock.canEdit;
      } else {
        r.completion = null;
      }
    } catch (e) {
      if (mounted) _message = examFailure(e).message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  StudentQuiz? _quiz() => ref
      .read(studentQuizCatalogProvider)
      .value
      ?.quizzes
      .where(
        (q) =>
            q.id == widget.request.quizId &&
            (widget.classId == null || q.classId == widget.classId),
      )
      .firstOrNull;

  Future<void> _start() async {
    if (_busy || (!_understood && _quiz()?.session?.inProgress != true)) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r =
          _repository ?? await ref.read(studentExamRepositoryProvider.future);
      if (!mounted) return;
      if (r == null) throw const ExamFailure('Sign in to continue.');
      _repository = r;
      if (!await ref.read(connectivityMonitorProvider).recheck()) {
        throw ExamFailure(
          _quiz()?.session?.inProgress == true
              ? 'Connect to the internet to continue.'
              : 'Connect to the internet to start.',
        );
      }
      if (!mounted) return;
      if (r.engaged) {
        await r.recover();
        if (r.error != null) throw r.error!;
        return;
      }
      await ref.read(classSyncProvider.notifier).refresh();
      if (!mounted) return;
      final catalog = await r.refreshCatalog();
      if (!mounted) return;
      final quiz = catalog.quizzes
          .where(
            (q) =>
                q.id == widget.request.quizId &&
                (widget.classId == null || q.classId == widget.classId),
          )
          .firstOrNull;
      if (catalog.failed)
        throw const ExamFailure(
          "We couldn't complete that request. Try again.",
        );
      if (quiz == null) throw const ExamFailure('This quiz is unavailable.');
      final room = ref
          .read(classCardsProvider)
          .value
          ?.where((room) => room.id == quiz.classId && !room.pending)
          .firstOrNull;
      if (room == null) throw const ExamFailure('This quiz is unavailable.');
      if (room.archived || quiz.json['class_archived'] == true) {
        throw const ExamFailure('This class is archived.');
      }
      if (quiz.session?.inProgress == true) {
        r.pendingQuizId = quiz.id;
        r.pendingSessionId = quiz.session!.id;
        await r.recover();
        if (r.error != null) throw r.error!;
        _resumed = r.active != null && r.clock.canEdit;
        return;
      }
      final reason = studentQuizDisabledReason(
        quiz,
        DateTime.now().toUtc(),
        archived: false,
        online: r.online(),
      );
      if (reason != null) throw ExamFailure(reason);
      await r.start(quiz.id);
    } catch (e) {
      if (!mounted) return;
      final failure = examFailure(e);
      _message = examStartMessage(failure, opensAt: _quiz()?.opensAt);
      _startBlocked =
          !failure.connection &&
          !failure.retryable &&
          !failure.message.startsWith('Connect to the internet') &&
          failure.message != "We couldn't complete that request. Try again.";
      ref.invalidate(studentQuizCatalogProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(ExamAnswer answer) async {
    final r = _repository;
    if (r == null || !r.clock.canEdit || _busy) return;
    final revision = (_revisions[answer.questionId] ?? 0) + 1;
    setState(() {
      _revisions[answer.questionId] = revision;
      _edits[answer.questionId] = answer;
      _unsaved.add(answer.questionId);
      _writes++;
      _message = null;
    });
    try {
      await r.answer(answer);
      if (mounted && _revisions[answer.questionId] == revision) {
        _unsaved.remove(answer.questionId);
      }
    } catch (e) {
      if (mounted) _message = examFailure(e).message;
    } finally {
      if (mounted) setState(() => _writes--);
    }
  }

  Future<void> _retryAnswers() async {
    for (final id in _unsaved.toList()) {
      if (!mounted) return;
      await _answer(_edits[id]!);
    }
  }

  Map<String, ExamAnswer> _answers() => {
    for (final saved in ref.read(examAnswersProvider).value ?? [])
      saved.answer.questionId: saved.answer,
    ..._edits,
  };

  Future<void> _submit() async {
    final r = _repository;
    if (r == null) return;
    final attempt = r.active;
    if (_busy || (_writes == 0 && _unsaved.isNotEmpty) || attempt == null)
      return;
    if (!r.clock.verified) return;
    if (r.submissionRequested || r.clock.expired) {
      await _expire();
      return;
    }
    final answers = _answers();
    final blanks = attempt.questions
        .where((q) => !examAnswerPresent(answers[q.id]))
        .length;
    setState(() => _busy = true);
    try {
      final route = DialogRoute<bool>(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  blanks == 0
                      ? "Submit your answers? You can't change them afterward."
                      : 'You have $blanks unanswered ${blanks == 1 ? 'question' : 'questions'}. Submit anyway?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                FiloButton(
                  label: 'Keep answering',
                  secondary: blanks == 0,
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 12),
                FiloButton(
                  label: blanks == 0 ? 'Submit' : 'Submit anyway',
                  secondary: blanks > 0,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      );
      _confirmationRoute = route;
      final confirmed = await Navigator.of(context).push(route);
      _confirmationRoute = null;
      if (confirmed != true || !mounted || !r.clock.canEdit) return;
      _message = null;
      FocusManager.instance.primaryFocus?.unfocus();
      await r.submit();
    } catch (e) {
      if (mounted) _message = examFailure(e).message;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    if (_ownsNavigation) _navigation.open = false;
    final r = _repository;
    if (r != null && !r.engaged) {
      unawaited(
        r.protectScreen?.call(false).catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityProvider, (previous, next) {
      if (previous?.value != true && next.value == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _repository?.engaged == true) unawaited(_open());
        });
      }
    });
    ref.watch(examUpdatesProvider);
    final repositoryState = ref.watch(studentExamRepositoryProvider);
    final r = repositoryState.value;
    if (r != null) _repository = r;
    final attempt = r?.active;
    final online = ref.watch(connectivityProvider).value == true;
    final catalog = ref.watch(studentQuizCatalogProvider);
    final now =
        ref.watch(studentQuizNowProvider).value ?? DateTime.now().toUtc();
    final quiz = _quiz();
    final rooms = ref.watch(classCardsProvider);
    final failed =
        catalog.hasError || rooms.hasError || catalog.value?.failed == true;
    final room = quiz == null
        ? null
        : rooms.value
              ?.where((room) => room.id == quiz.classId && !room.pending)
              .firstOrNull;
    final archived =
        room?.archived == true || quiz?.json['class_archived'] == true;
    final loading =
        catalog.isLoading ||
        rooms.isLoading ||
        catalog.value?.refreshing == true;
    final reason = quiz == null || (rooms.hasValue && room == null)
        ? (failed
              ? 'Refresh to check your exam status.'
              : loading
              ? null
              : !online && catalog.value?.loaded != true
              ? 'No saved quiz on this device. Connect to the internet and refresh.'
              : 'This quiz is unavailable.')
        : studentQuizDisabledReason(
            quiz,
            now,
            archived: archived,
            online: online,
          );
    final engaged = r?.engaged == true;
    final completion = r?.completion;
    if (completion != null && attempt == null) {
      final route = _confirmationRoute;
      _confirmationRoute = null;
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && route.isActive)
            Navigator.of(context).removeRoute(route, false);
        });
      }
      _edits.clear();
      _unsaved.clear();
      _revisions.clear();
    }
    final overview =
        !engaged && completion == null && widget.request.sessionId == null;
    final locked = _busy || engaged;
    return PopScope(
      canPop: !locked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && engaged) {
          showMessage(context, "You can't leave an exam in progress.");
        }
      },
      child: SelectionContainer.disabled(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              overview ? '${quiz?.typeLabel ?? 'Quiz'} details' : 'Exam',
            ),
            automaticallyImplyLeading: !locked,
          ),
          body: SafeArea(
            child: overview
                ? StudentQuizOverview(
                    quiz: room != null ? quiz : null,
                    now: now,
                    archived: archived,
                    online: online,
                    loading: loading,
                    understood: _understood,
                    busy: _busy,
                    onChanged: (value) =>
                        setState(() => _understood = value == true),
                    onStart:
                        !_startBlocked &&
                            reason == null &&
                            room != null &&
                            !failed &&
                            !catalog.isLoading
                        ? _start
                        : null,
                    message: _startBlocked
                        ? _message ?? reason
                        : reason ??
                              _message ??
                              (failed
                                  ? 'Refresh to check your exam status.'
                                  : null),
                    onRefresh: _openAndRefresh,
                    onRetry:
                        failed ||
                            (quiz != null &&
                                studentQuizState(quiz, now).pending) ||
                            (_message != null && !_startBlocked)
                        ? _openAndRefresh
                        : null,
                  )
                : completion != null && attempt == null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        completion == 'Your answers were submitted.'
                            ? ((r?.completionTimedOut == true)
                                  ? "Time's up. Your answers were submitted.\n\nYour answers were submitted. Results will be available once everyone has finished or the quiz closes."
                                  : 'Your answers were submitted. Results will be available once everyone has finished or the quiz closes.')
                            : completion,
                      ),
                      if (_essay &&
                          completion == 'Your answers were submitted.') ...[
                        const SizedBox(height: 12),
                        const Text(
                          "Essay results also need your instructor's grading.",
                        ),
                      ],
                    ],
                  )
                : attempt == null || attempt.questions.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (_busy || repositoryState.isLoading)
                        const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _message ??
                              r?.error?.message ??
                              (repositoryState.hasError
                                  ? "We couldn't reopen your exam. Check your connection and try again."
                                  : 'Loading your exam...'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_busy &&
                          !repositoryState.isLoading &&
                          (_message != null ||
                              r?.error != null ||
                              repositoryState.hasError))
                        FiloButton(
                          label: 'Try again',
                          onPressed: _busy ? null : _open,
                        ),
                    ],
                  )
                : _exam(r!, attempt, online),
          ),
        ),
      ),
    );
  }

  Future<void> _openAndRefresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (!await ref.read(connectivityMonitorProvider).recheck()) {
        throw ExamFailure(
          _quiz()?.session?.inProgress == true
              ? 'Connect to the internet to continue.'
              : 'Connect to the internet to start.',
        );
      }
      if (!mounted) return;
      await ref.read(classSyncProvider.notifier).refresh();
      if (!mounted) return;
      _startBlocked = false;
      if (ref.read(studentExamRepositoryProvider).hasError) {
        ref.invalidate(studentExamRepositoryProvider);
      }
      ref.invalidate(studentQuizCatalogProvider);
    } catch (e) {
      if (mounted) _message = examStartMessage(e, opensAt: _quiz()?.opensAt);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _expire() async {
    final r = _repository;
    if (!mounted ||
        r == null ||
        r.active == null ||
        !r.clock.verified ||
        (!r.clock.expired && !r.submissionRequested))
      return;
    final route = _confirmationRoute;
    _confirmationRoute = null;
    if (route?.isActive == true)
      Navigator.of(context).removeRoute(route!, false);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await r.submit();
      if (mounted) setState(() => _message = null);
    } catch (e) {
      if (mounted) setState(() => _message = examFailure(e).message);
    }
  }

  Widget _exam(StudentExamRepository r, ExamAttempt attempt, bool online) {
    final answersState = ref.watch(examAnswersProvider);
    ref.watch(
      examCountdownProvider.select(
        (_) => (r.clock.expired, r.clock.acceptanceClosed),
      ),
    );
    final expired = r.clock.expired;
    if (_session != attempt.sessionId) {
      _session = attempt.sessionId;
      _edits.clear();
      _unsaved.clear();
      _revisions.clear();
    }
    _essay = attempt.questions.any((q) => q.type == 'essay');
    if (expired && _expirySession != attempt.sessionId) {
      _expirySession = attempt.sessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_expire());
      });
    }
    final answers = _answers();
    final answered = attempt.questions
        .where((q) => examAnswerPresent(answers[q.id]))
        .length;
    final editable =
        !_busy &&
        r.current &&
        !r.submitting &&
        !r.submissionRequested &&
        r.clock.canEdit &&
        !expired &&
        answersState.value != null &&
        !answersState.hasError &&
        r.error?.reconcile != true &&
        r.saver?.error?.reconcile != true;
    final stored = {
      for (final answer in answersState.value ?? [])
        answer.answer.questionId: answer,
    };
    final editsConfirmed = _edits.entries.every((edit) {
      final saved = stored[edit.key];
      return saved?.sent == true &&
          saved!.answer.optionId == edit.value.optionId &&
          saved.answer.boolean == edit.value.boolean &&
          saved.answer.text == edit.value.text;
    });
    final savingState = ref.watch(examSavingStateProvider);
    final saved = _writes > 0 || _unsaved.isNotEmpty || !editsConfirmed
        ? 'Saving...'
        : savingState;
    final status = !online || savingState == 'Reconnecting...'
        ? 'Reconnecting...'
        : saved;
    return Column(
      children: [
        _ExamStatusBar(
          key: ValueKey(attempt.sessionId),
          repository: r,
          answered: answered,
          total: attempt.questions.length,
          status: status,
        ),
        Expanded(
          child: ListView.builder(
            key: PageStorageKey('exam-questions-${attempt.sessionId}'),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            itemCount: attempt.questions.length + 2,
            itemBuilder: (context, index) {
              if (index == 0)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_resumed && !expired)
                      const Text('Your exam has resumed with the time left.'),
                    if (!r.clock.verified)
                      const Text(
                        'Reconnect to verify your remaining time before continuing.',
                      ),
                    if (!online && !expired && r.clock.verified)
                      const Text(
                        'The timer keeps running while you reconnect.',
                      ),
                    if (expired) Text(r.clock.timeoutMessage),
                    if (_message ?? r.error?.message ?? r.saver?.error?.message
                        case final String message
                        when !expired ||
                            !message.startsWith(
                              "Time's up. Reconnect to check your submission.",
                            ))
                      Semantics(liveRegion: true, child: Text(message)),
                    if (_unsaved.isNotEmpty && _writes == 0)
                      TextButton(
                        onPressed: _writes == 0 && !_busy && r.clock.canEdit
                            ? _retryAnswers
                            : null,
                        child: const Text('Try again'),
                      ),
                    if (answersState.hasError) ...[
                      const Text(
                        "We couldn't reopen your exam. Check your connection and try again.",
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(examAnswersProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                    if (answersState.isLoading && !answersState.hasValue)
                      const LinearProgressIndicator(),
                    if (r.error != null ||
                        r.saver?.error != null ||
                        expired ||
                        !r.clock.verified)
                      TextButton(
                        onPressed: _busy ? null : _open,
                        child: const Text('Try again'),
                      ),
                  ],
                );
              if (index <= attempt.questions.length) {
                final question = attempt.questions[index - 1];
                return Padding(
                  key: ValueKey('${attempt.sessionId}:${question.id}'),
                  padding: const EdgeInsets.only(top: 16),
                  child: ExamQuestionCard(
                    question: question,
                    number: index,
                    answer: answers[question.id],
                    enabled: editable,
                    onChanged: (answer) => unawaited(_answer(answer)),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: FiloButton(
                  label: r.submitting ? 'Submitting...' : 'Submit',
                  leading: r.submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  busy: _busy || r.submitting,
                  onPressed:
                      !_busy &&
                          !r.submitting &&
                          ((editable && (_writes > 0 || _unsaved.isEmpty)) ||
                              (online && (expired || r.submissionRequested)))
                      ? _submit
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

bool examAnswerPresent(ExamAnswer? answer) =>
    answer?.optionId != null ||
    answer?.boolean != null ||
    answer?.text?.trim().isNotEmpty == true;

class _ExamStatusBar extends ConsumerStatefulWidget {
  const _ExamStatusBar({
    super.key,
    required this.repository,
    required this.answered,
    required this.total,
    required this.status,
  });
  final StudentExamRepository repository;
  final int answered, total;
  final String status;

  @override
  ConsumerState<_ExamStatusBar> createState() => _ExamStatusBarState();
}

class _ExamStatusBarState extends ConsumerState<_ExamStatusBar> {
  final _announced = <int>{};

  @override
  Widget build(BuildContext context) {
    final remaining =
        ref.watch(examCountdownProvider).value ??
        widget.repository.clock.remaining;
    final level =
        !widget.repository.clock.verified || remaining == Duration.zero
        ? 0
        : remaining < const Duration(minutes: 1)
        ? 1
        : remaining < const Duration(minutes: 5)
        ? 5
        : 0;
    final warning = level == 1
        ? 'Less than 1 minute left'
        : level == 5
        ? 'Less than 5 minutes left'
        : null;
    if (warning != null && _announced.add(level)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Announce thresholds only; the ticking value is never a live region.
          unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              warning,
              Directionality.of(context),
            ),
          );
        }
      });
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final background = level == 1
        ? colors.errorContainer
        : level == 5
        ? (dark ? const Color(0xFF493400) : FiloColors.warning)
        : colors.surface;
    final foreground = level == 1
        ? colors.onErrorContainer
        : level == 5
        ? (dark ? const Color(0xFFFFDDA0) : FiloColors.warningInk)
        : colors.onSurface;
    return ColoredBox(
      key: const ValueKey('exam-status-bar'),
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: false,
                child: Text(
                  widget.repository.clock.verified
                      ? 'Time left: ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                      : 'Time left: awaiting verification',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
              if (warning != null) Text(warning),
              Text('${widget.answered} of ${widget.total} answered'),
              Text(widget.status),
            ],
          ),
        ),
      ),
    );
  }
}
