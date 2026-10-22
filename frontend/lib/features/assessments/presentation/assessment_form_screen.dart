import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../application/instructor_quiz_providers.dart';
import '../domain/quiz_draft.dart';
import '../data/instructor_quiz_repository.dart';
import '../domain/quiz_publish.dart';
import '../domain/quiz_helpers.dart';
import 'assessment_row.dart';
import 'question_card.dart';
import 'question_bank_screen.dart';

/// Connected settings and question builder for instructor assessments.
class AssessmentFormScreen extends ConsumerStatefulWidget {
  const AssessmentFormScreen({
    super.key,
    required this.classId,
    this.quizId,
    this.readOnly = false,
  });
  final String classId;
  final String? quizId;
  final bool readOnly;
  @override
  ConsumerState<AssessmentFormScreen> createState() =>
      _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends ConsumerState<AssessmentFormScreen> {
  static const _stepLabels = ['Details', 'Settings', 'Questions'];
  final _pageScrolls = List.generate(3, (_) => ScrollController());
  final _closingTimeKey = GlobalKey();
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  ScrollController get _scroll => _pageScrolls[2];
  int _step = 0;
  bool _viewOnly = false;

  void _switchStep(int target) {
    assert(target >= 0 && target < _stepLabels.length);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = target;
    });
  }

  Future<bool> _validateStep(int page) async {
    if (_viewOnly) return true;
    final form = _forms[page].currentState;
    if (form == null) return false;
    final invalidFields = form.validateGranularly();
    if (invalidFields.isNotEmpty) {
      _switchStep(page);
      await revealAssessmentField(invalidFields.first.context);
      return false;
    }
    if (page == 1) {
      final opens = _draft!.locked
          ? _savedQuiz?.row['opens_at'] as String?
          : _draft!.settings['opens_at'] as String?;
      final closes = _draft!.settings['closes_at'] as String?;
      if (opens != null &&
          closes != null &&
          !DateTime.parse(closes).isAfter(DateTime.parse(opens))) {
        _switchStep(1);
        setState(() => _error = 'Closing time must be after the opening time.');
        final target = _closingTimeKey.currentContext;
        if (target != null) await revealAssessmentField(target);
        return false;
      }
      if (_error == 'Closing time must be after the opening time.') {
        setState(() => _error = null);
      }
    }
    return true;
  }

  Future<void> _navigate(int target) async {
    if (_busy || _loading || _draft == null) return;
    if (target > _step) {
      for (var page = 0; page < target; page++) {
        if (!await _validateStep(page) || !mounted) return;
      }
    }
    _switchStep(target);
  }

  final _editors = <String, QuestionEditorState>{};
  final _cardKeys = <String, GlobalKey>{};
  String? _expanded;
  bool _questionDirty = false;
  QuestionEditorState _editor(QuizQuestion q) =>
      _editors.putIfAbsent(q.localId, () => QuestionEditorState(q));
  bool get _dirty => _questionDirty || _draft?.isDirty == true;
  @override
  void dispose() {
    for (final controller in _pageScrolls) {
      controller.dispose();
    }
    super.dispose();
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _draft!.questions.length || from == to) return;
    setState(() {
      final q = _draft!.questions.removeAt(from);
      _draft!.questions.insert(to, q);
      _questionDirty = true;
      for (final q in _draft!.questions) {
        _editor(q).status = 'Unsaved changes';
      }
    });
  }

  final _bankIds = <String, String>{};
  final _bankSnapshots = <String, QuizQuestion>{};

  Future<void> _saveToBank(QuizQuestion q) async {
    if (_busy || ref.read(connectivityProvider).asData?.value != true) return;
    final editor = _editor(q);
    setState(() {
      editor.errors = q.validationErrors(
        pointsText: editor.points,
        pendingAnswer: editor.pendingAnswer,
      );
      if (editor.errors.isNotEmpty) _expanded = q.localId;
    });
    if (editor.errors.isNotEmpty) {
      await _revealQuestion(q.localId);
      return;
    }
    final id = _bankIds.putIfAbsent(q.localId, () => const Uuid().v4());
    final snapshot = _bankSnapshots.putIfAbsent(q.localId, q.copy);
    setState(() => _busy = true);
    try {
      final bank = await ref.read(questionBankRepositoryProvider.future);
      await bank.save(id, snapshot, creating: true);
      _bankIds.remove(q.localId);
      _bankSnapshots.remove(q.localId);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question saved to bank.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bank save not confirmed. Connect and retry Save to bank to check the original copy.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFromBank() async {
    if (_busy || !_canWrite || _draft!.locked || _draft!.reconciliationRequired)
      return;
    final copies = await showFiloBottomSheet<List<QuizQuestion>>(
      context: context,
      title: 'Add from question bank',
      scrollBody: false,
      builder: (_) => const QuestionBankScreen(picking: true),
    );
    if (!mounted ||
        copies == null ||
        copies.isEmpty ||
        !_canWrite ||
        _draft!.locked ||
        _draft!.reconciliationRequired)
      return;
    setState(() {
      _draft!.questions.addAll(copies);
      _expanded = copies.first.localId;
      _questionDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Questions added as copies. Save this assessment to keep them.',
        ),
      ),
    );
    await _revealQuestion(copies.first.localId);
  }

  Future<void> _questionAction(QuizQuestion q, String action) async {
    if (action == 'bank') {
      await _saveToBank(q);
      return;
    }
    final questions = _draft!.questions;
    final index = questions.indexOf(q);
    if (action == 'up' || action == 'down') {
      _move(index, index + (action == 'up' ? -1 : 1));
      return;
    }
    if (action == 'delete') {
      final confirmed = await showFiloConfirmation(
        context,
        title: 'Delete this question?',
        message: 'This question will be removed when you save.',
        confirmLabel: 'Delete',
        cancelLabel: 'Cancel',
        icon: FiloIcons.delete,
      );
      if (!confirmed || !mounted || _busy || _draft!.locked || _archived) {
        return;
      }
      setState(() {
        questions.remove(q);
        _editors.remove(q.localId);
        _cardKeys.remove(q.localId);
        _questionDirty = true;
      });
    } else if (action == 'duplicate') {
      setState(() {
        final copy = q.duplicate();
        questions.insert(index + 1, copy);
        final source = _editor(q);
        _editors[copy.localId] = QuestionEditorState(copy)
          ..points = source.points
          ..pendingAnswer = source.pendingAnswer;
        _expanded = copy.localId;
        _questionDirty = true;
      });
    }
  }

  Future<void> _revealQuestion(String id) async {
    // Lazy cards have no context until their viewport is built.
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(0);
    for (var step = 0; step < 100 && mounted; step++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) return;
      final target = _cardKeys[id]?.currentContext;
      if (target != null) {
        final q = _draft!.questions.where((q) => q.localId == id).firstOrNull;
        if (q != null && _editor(q).errors.isNotEmpty) {
          await revealQuestionError(target, _editor(q).errors);
        } else {
          await Scrollable.ensureVisible(target, alignment: 0.1);
        }
        return;
      }
      final next = (_scroll.offset + _scroll.position.viewportDimension * 0.8)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      if (next == _scroll.offset) return;
      _scroll.jumpTo(next);
    }
  }

  QuizDraft? _draft;
  InstructorQuiz? _savedQuiz;
  bool _loading = true,
      _busy = false,
      _published = false,
      _allowPop = false,
      _archived = false;
  String? _error;
  int _revision = 0;
  bool _answersChosenByHand = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final repository = await ref.read(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null) throw StateError('Sign in to open assessments.');
      final db = repository.database;
      final profile = await db.readProfile(repository.userId);
      final room = await (db.select(
        db.cacheClasses,
      )..where((c) => c.id.equals(widget.classId))).getSingleOrNull();
      if (profile?.role != 'instructor' ||
          profile?.deletedAt != null ||
          room == null ||
          room.ownerId != repository.userId ||
          room.deletedAt != null) {
        throw StateError('This assessment is no longer available.');
      }
      _archived = room.archivedAt != null;
      final id = _draft?.id ?? widget.quizId;
      if (id == null) {
        if (!mounted) return;
        setState(() {
          _draft ??= QuizDraft.create(widget.classId);
          _loading = false;
          _error = null;
        });
        return;
      }
      final cached = await repository.watchQuiz(widget.classId, id).first;
      if (!mounted) return;
      if (cached != null && _draft == null) _accept(cached);
      if (ref.read(connectivityProvider).asData?.value == true) {
        final saved = await repository.refreshQuiz(widget.classId, id);
        if (!mounted) return;
        if (_draft == null || !_draft!.isDirty) {
          _accept(saved);
        } else {
          setState(() {
            _draft!.locked = saved.locked;
            _published = saved.row['status'] == 'published';
          });
        }
      } else if (_draft == null) {
        throw StateError(
          'This assessment is not saved on this device. Connect to the internet and retry.',
        );
      }
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _accept(InstructorQuiz saved) {
    setState(() {
      _savedQuiz = saved;
      _draft = QuizDraft(saved);
      // A stored value is an instructor choice, even when it matches a default.
      _answersChosenByHand = true;
      _published = saved.row['status'] == 'published';
      _revision++;
      _questionDirty = false;
      _editors.clear();
      _cardKeys.clear();
      _expanded = null;
    });
  }

  Future<void> _reload() async {
    if (_busy || _loading) return;
    if (_dirty) {
      final discard = await showFiloConfirmation(
        context,
        title: 'Discard your changes?',
        message: 'Your unsaved changes will be lost.',
        confirmLabel: 'Discard changes',
        cancelLabel: 'Keep editing',
        icon: FiloIcons.delete,
      );
      if (!discard || !mounted) return;
    }
    final id = _draft?.id ?? widget.quizId;
    if (id == null && _draft?.reconciliationRequired == true) return;
    if (id != null) {
      setState(() => _busy = true);
      try {
        final repository = await ref.read(
          instructorQuizRepositoryProvider.future,
        );
        if (repository == null) {
          throw StateError('Sign in to reload this assessment.');
        }
        final saved = await repository.refreshQuiz(widget.classId, id);
        if (mounted) {
          _accept(saved);
          setState(() => _error = null);
        }
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = error.toString().replaceFirst('Bad state: ', ''),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      await _load();
    }
  }

  Future<void> _leave({bool exitBuilder = false}) async {
    if (_busy) return;
    if (!exitBuilder && _step > 0) {
      _switchStep(_step - 1);
      return;
    }
    if (_dirty) {
      final discard = await showFiloConfirmation(
        context,
        title: 'Discard your changes?',
        message: 'Your unsaved changes will be lost.',
        confirmLabel: 'Discard changes',
        cancelLabel: 'Keep editing',
        icon: FiloIcons.delete,
      );
      if (!discard || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _pickDate(String field) async {
    final current = _draft!.settings[field] as String?;
    final civil = utcToManila(
      current == null ? DateTime.now().toUtc() : DateTime.parse(current),
    );
    final first = DateTime(civil.year < 2000 ? civil.year : 2000);
    final last = DateTime(civil.year > 2100 ? civil.year : 2100, 12, 31);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(civil.year, civil.month, civil.day),
      helpText: 'Select date (Philippine time)',
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: civil.hour, minute: civil.minute),
      helpText: 'Select time (PHT, UTC+08:00)',
    );
    if (time == null || !mounted) return;
    setState(
      () => _draft!.settings[field] = manilaToUtc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toIso8601String(),
    );
  }

  bool get _canWrite =>
      !_viewOnly &&
      !_archived &&
      !_loading &&
      ref.read(connectivityProvider).asData?.value == true &&
      _draft?.reconciliationRequired != true;

  final _publishProblems = <QuizPublishProblem>[];
  final _problemFields = <QuizPublishProblem, FormFieldState<dynamic>>{};

  Future<void> _showProblem(QuizPublishProblem problem) async {
    _switchStep(problem.page);
    if (_problemFields.containsKey(problem)) {
      await revealAssessmentField(_problemFields[problem]!.context);
    } else if (problem.questionId != null) {
      setState(() => _expanded = problem.questionId);
      await _revealQuestion(problem.questionId!);
    } else if (problem.page == 1) {
      await WidgetsBinding.instance.endOfFrame;
      final target = _closingTimeKey.currentContext;
      if (mounted && target != null) await revealAssessmentField(target);
    } else if (problem.page == 0) {
      await _validateStep(0);
    }
  }

  Future<void> _publish() async {
    if (_busy || !_canWrite || _published) return;
    final draft = _draft!;
    final problems = quizPublishProblems(draft, DateTime.now().toUtc());
    _problemFields.clear();
    for (var page = 0; page < 2; page++) {
      final invalid = _forms[page].currentState?.validateGranularly();
      if (invalid != null) {
        for (final field in invalid) {
          final problem = QuizPublishProblem(
            field.errorText ?? 'Check this field.',
            page,
          );
          problems.add(problem);
          _problemFields[problem] = field;
        }
      }
    }
    for (var i = 0; i < draft.questions.length; i++) {
      final q = draft.questions[i];
      final e = _editor(q);
      e.errors = q.validationErrors(
        pointsText: e.points,
        pendingAnswer: e.pendingAnswer,
      );
      for (final message in e.errors.values) {
        problems.add(
          QuizPublishProblem(
            'Question ${i + 1}: $message',
            2,
            questionId: q.localId,
          ),
        );
      }
    }
    setState(() {
      _publishProblems
        ..clear()
        ..addAll(problems);
    });
    if (problems.isNotEmpty) {
      if (_pageScrolls[_step].hasClients) _pageScrolls[_step].jumpTo(0);
      return;
    }
    setState(() => _busy = true);
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Publish this assessment?',
      message: quizPublishSummary(draft),
      confirmLabel: 'Publish',
      cancelLabel: 'Keep editing',
      icon: FiloIcons.assessment,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!confirmed || !_canWrite) return;
    await _save(publish: true);
  }

  Future<void> _save({bool publish = false}) async {
    if (_busy || !_canWrite) return;
    final draft = _draft!;
    if (!await _validateStep(0) || !mounted) return;
    if (!await _validateStep(1) || !mounted) return;
    String? invalid;
    for (final q in draft.locked ? <QuizQuestion>[] : draft.questions) {
      final e = _editor(q);
      e.errors = q.validationErrors(
        pointsText: e.points,
        pendingAnswer: e.pendingAnswer,
      );
      if (e.errors.isNotEmpty) {
        invalid ??= q.localId;
      }
    }
    if (invalid != null) {
      _switchStep(2);
      setState(() => _expanded = invalid);
      await _revealQuestion(invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null) {
        throw StateError('Sign in to save this assessment.');
      }
      // Keep rejected content visible, but never replay it after a server lock.
      final requestDraft = draft.locked && _savedQuiz != null
          ? (QuizDraft(_savedQuiz!)
              ..settings['title'] = draft.settings['title']
              ..settings['closes_at'] = draft.settings['closes_at'])
          : draft;
      var saved = await repository.save(
        requestDraft,
        onQuestionProgress: (id, status) {
          if (mounted) {
            setState(() {
              final e = _editors[id];
              if (e != null) e.status = status;
            });
          }
        },
      );
      if (!identical(requestDraft, draft)) {
        draft.acceptSaved(saved);
        _editors.clear();
      }
      _savedQuiz = saved;
      if (publish) {
        saved = await repository.publish(widget.classId, draft.id!);
        draft.acceptSaved(saved);
      }
      if (!mounted) return;
      setState(() {
        _savedQuiz = saved;
        _publishProblems.clear();
        // Repository accepted the refreshed content while retaining local IDs.
        _published = saved.row['status'] == 'published';
        _questionDirty = false;
        for (final q in draft.questions) {
          _editor(q).status = 'Saved';
        }
      });
      showMessage(
        context,
        publish
            ? 'Assessment published.'
            : _published
            ? 'Changes saved.'
            : 'Draft saved.',
      );
    } catch (error) {
      if (error is QuizReconciliationRequired) {
        draft.reconciliationRequired = true;
      }
      if (quizFriendlyError(error).contains('already been started') &&
          draft.id != null) {
        try {
          final repository = await ref.read(
            instructorQuizRepositoryProvider.future,
          );
          final fresh = await repository?.refreshQuiz(
            widget.classId,
            draft.id!,
          );
          if (mounted && fresh != null) {
            setState(() {
              _savedQuiz = fresh;
              draft.locked = fresh.locked;
              draft.reconciliationRequired = false;
              _published = fresh.row['status'] == 'published';
            });
          }
        } catch (_) {
          draft.locked = true;
          draft.reconciliationRequired = true;
        }
      }
      if (mounted) {
        for (final q in draft.questions) {
          if (draft.reconciliationRequired) {
            _editor(q).status = 'Save not confirmed';
          }
        }
        setState(
          () =>
              _error = quizFriendlyError(error).contains('already been started')
              ? '${quizFriendlyError(error)} Unsaved content is kept here read-only and will not be saved. Reload to view the saved version.'
              : _draft!.reconciliationRequired
              ? (draft.id == null
                    ? 'The save could not be confirmed. Check the classwork list before creating another draft.'
                    : 'The change could not be confirmed. Your edits are still here. Reload the saved version before trying again.')
              : quizFriendlyError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final classes = ref.watch(classesProvider);
    final room = classes.asData?.value
        .where((c) => c.id == widget.classId)
        .firstOrNull;
    final readOnly =
        widget.readOnly ||
        _archived ||
        room?.archivedAt != null ||
        (classes.hasValue && (room == null || room.deletedAt != null));
    final draft = _draft;
    _viewOnly = readOnly;
    final editing = !readOnly && !_busy && !_loading;
    final contentEditing = editing && draft?.locked != true;
    final inputTheme = Theme.of(context).inputDecorationTheme;
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: inputTheme.copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FiloColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FiloColors.primary, width: 2),
          ),
        ),
      ),
      child: PopScope(
        canPop: _allowPop || (_step == 0 && !_busy && !_dirty),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Assessment actions',
                enabled: !_busy && !_loading,
                onSelected: (_) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuestionBankScreen(),
                  ),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'bank', child: Text('Question bank')),
                ],
              ),
            ],
            title: Text(
              readOnly
                  ? 'Assessment'
                  : draft?.id == null
                  ? 'New assessment'
                  : 'Edit assessment',
            ),
            leading: IconButton(
              tooltip: 'Back to classwork',
              onPressed: _busy ? null : () => _leave(exitBuilder: true),
              icon: const FiloIcon(FiloIcons.back),
            ),
          ),
          body: SafeArea(
            child: _loading && draft == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (draft != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _stepLabels[_step],
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Step ${_step + 1} of 3',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: FiloColors.secondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (draft.id != null) ...[
                                const SizedBox(width: 12),
                                Chip(
                                  label: Text(
                                    quizDisplayStatus(
                                      status: _published
                                          ? 'published'
                                          : 'draft',
                                      opensAt: _savedQuiz?.settings.opensAt,
                                      closesAt: _savedQuiz?.settings.closesAt,
                                      now: DateTime.now().toUtc(),
                                    ).label,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: _step,
                          children: [
                            for (
                              var page = 0;
                              page < _stepLabels.length;
                              page++
                            )
                              Form(
                                key: _forms[page],
                                child: CustomScrollView(
                                  controller: _pageScrolls[page],
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        16,
                                        24,
                                        24,
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (!online) const OfflineBanner(),
                                            if (readOnly)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                child: Text(
                                                  'This class is archived or unavailable. Assessments are read-only.',
                                                ),
                                              ),
                                            if (draft?.locked == true)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                child: Text(
                                                  'This quiz has already been started. Only the title and closing time can change.',
                                                ),
                                              )
                                            else if (_published)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                child: Text(
                                                  'Students can already see this assessment. Your saved changes will affect it.',
                                                ),
                                              ),
                                            if (_publishProblems
                                                .isNotEmpty) ...[
                                              const Text(
                                                'Before publishing, fix these problems:',
                                              ),
                                              for (final problem
                                                  in _publishProblems)
                                                TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _showProblem(
                                                          problem,
                                                        ),
                                                  child: Text(problem.message),
                                                ),
                                            ],
                                            if (_error != null) ...[
                                              Text(
                                                _error!,
                                                style: const TextStyle(
                                                  color: FiloColors.error,
                                                ),
                                              ),
                                              if (online &&
                                                  (draft?.reconciliationRequired !=
                                                          true ||
                                                      draft?.id != null))
                                                TextButton(
                                                  onPressed: _busy || _loading
                                                      ? null
                                                      : _reload,
                                                  child: Text(
                                                    draft?.reconciliationRequired ==
                                                            true
                                                        ? 'Reload saved version'
                                                        : 'Retry',
                                                  ),
                                                ),
                                              const SizedBox(height: 16),
                                            ],
                                            if (draft != null) ...[
                                              if (page == 0) ...[
                                                TextFormField(
                                                  key: ValueKey(
                                                    'title-$_revision',
                                                  ),
                                                  initialValue:
                                                      draft.settings['title']
                                                          as String?,
                                                  enabled: editing,
                                                  maxLength: 120,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Title',
                                                      ),
                                                  validator: (value) =>
                                                      value == null ||
                                                          value.trim().isEmpty
                                                      ? 'Give your assessment a title.'
                                                      : null,
                                                  onChanged: (value) =>
                                                      setState(() {
                                                        _questionDirty = true;
                                                        draft.settings['title'] =
                                                            value;
                                                      }),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Quiz or Exam',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall,
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 8,
                                                  children: [
                                                    for (final type in [
                                                      'quiz',
                                                      'exam',
                                                    ])
                                                      ChoiceChip(
                                                        label: Text(
                                                          type == 'quiz'
                                                              ? 'Quiz'
                                                              : 'Exam',
                                                        ),
                                                        selected:
                                                            draft
                                                                .settings['type'] ==
                                                            type,
                                                        onSelected:
                                                            contentEditing
                                                            ? (
                                                                _,
                                                              ) => setState(() {
                                                                draft.settings['type'] =
                                                                    type;
                                                                if (!_answersChosenByHand) {
                                                                  draft.settings['show_correct_answers'] =
                                                                      type ==
                                                                      'quiz';
                                                                }
                                                              })
                                                            : null,
                                                      ),
                                                  ],
                                                ),
                                                _hint(
                                                  'Quiz shows correct answers by default; Exam hides them. Both use the same rules.',
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  key: ValueKey(
                                                    'minutes-$_revision',
                                                  ),
                                                  initialValue:
                                                      '${draft.settings['time_limit_minutes']}',
                                                  enabled: contentEditing,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Time limit (minutes)',
                                                      ),
                                                  validator: (value) {
                                                    if (draft.locked)
                                                      return null;
                                                    final n = int.tryParse(
                                                      value ?? '',
                                                    );
                                                    return n == null ||
                                                            n < 1 ||
                                                            n > 600
                                                        ? 'Enter 1 to 600 minutes.'
                                                        : null;
                                                  },
                                                  onChanged: (value) => setState(
                                                    () =>
                                                        draft.settings['time_limit_minutes'] =
                                                            int.tryParse(value),
                                                  ),
                                                ),
                                                _hint(
                                                  'Choose 1 to 600 minutes; each attempt ends when time runs out or the assessment closes, whichever comes first.',
                                                ),
                                                const SizedBox(height: 20),
                                                TextFormField(
                                                  key: ValueKey(
                                                    'instructions-$_revision',
                                                  ),
                                                  initialValue:
                                                      draft.settings['instructions']
                                                          as String?,
                                                  enabled: contentEditing,
                                                  maxLength: 5000,
                                                  minLines: 3,
                                                  maxLines: 6,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Instructions (optional)',
                                                        alignLabelWithHint:
                                                            true,
                                                      ),
                                                  onChanged: (value) => setState(
                                                    () =>
                                                        draft.settings['instructions'] =
                                                            value.isEmpty
                                                            ? null
                                                            : value,
                                                  ),
                                                ),
                                              ],
                                              if (page == 1) ...[
                                                _hint(
                                                  'All dates and times use Philippine time (PHT, UTC+08:00).',
                                                ),
                                                const SizedBox(height: 16),
                                                for (final field in [
                                                  'opens_at',
                                                  'closes_at',
                                                ]) ...[
                                                  OutlinedButton.icon(
                                                    key: field == 'closes_at'
                                                        ? _closingTimeKey
                                                        : null,
                                                    style: OutlinedButton.styleFrom(
                                                      backgroundColor:
                                                          FiloColors.surface,
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      minimumSize: const Size(
                                                        0,
                                                        64,
                                                      ),
                                                      side: const BorderSide(
                                                        color:
                                                            FiloColors.border,
                                                        width: 1.5,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                      ),
                                                    ),
                                                    icon: const FiloIcon(
                                                      FiloIcons.calendar,
                                                    ),
                                                    onPressed:
                                                        (field == 'closes_at'
                                                            ? editing
                                                            : contentEditing)
                                                        ? () => _pickDate(field)
                                                        : null,
                                                    label: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          field == 'opens_at'
                                                              ? 'Opens'
                                                              : 'Closes',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: FiloColors
                                                                        .secondary,
                                                                  ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          assessmentDateLabel(
                                                            draft.settings[field] ==
                                                                    null
                                                                ? null
                                                                : DateTime.parse(
                                                                    draft.settings[field]
                                                                        as String,
                                                                  ),
                                                          ),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleSmall,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  _hint(
                                                    field == 'opens_at'
                                                        ? 'Students can start at this date and time.'
                                                        : 'Students must finish by this date and time, even if their time limit has not run out.',
                                                  ),
                                                  if (draft.settings[field] !=
                                                          null &&
                                                      (field == 'closes_at'
                                                          ? editing
                                                          : contentEditing))
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: TextButton(
                                                        onPressed: () => setState(
                                                          () =>
                                                              draft.settings[field] =
                                                                  null,
                                                        ),
                                                        child: Text(
                                                          field == 'opens_at'
                                                              ? 'Clear opening time'
                                                              : 'Clear closing time',
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                ],
                                                for (final setting in const [
                                                  (
                                                    'shuffle_questions',
                                                    'Shuffle questions',
                                                    'Give each student a shuffled question order that stays the same when they resume.',
                                                  ),
                                                  (
                                                    'shuffle_options',
                                                    'Shuffle options',
                                                    'Shuffle multiple-choice options for each student and keep that order when they resume.',
                                                  ),
                                                  (
                                                    'show_correct_answers',
                                                    'Show correct answers',
                                                    'Let students see correct answers when their results are released.',
                                                  ),
                                                ]) ...[
                                                  SwitchListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      setting.$2,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall,
                                                    ),
                                                    subtitle: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8,
                                                          ),
                                                      child: Text(
                                                        setting.$3,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: FiloColors
                                                                  .secondary,
                                                            ),
                                                      ),
                                                    ),
                                                    value:
                                                        draft.settings[setting
                                                                .$1]
                                                            as bool,
                                                    onChanged: contentEditing
                                                        ? (
                                                            value,
                                                          ) => setState(() {
                                                            draft.settings[setting
                                                                    .$1] =
                                                                value;
                                                            if (setting.$1 ==
                                                                'show_correct_answers') {
                                                              _answersChosenByHand =
                                                                  true;
                                                            }
                                                          })
                                                        : null,
                                                  ),
                                                  const SizedBox(height: 12),
                                                ],
                                                TextFormField(
                                                  key: ValueKey(
                                                    'passing-$_revision',
                                                  ),
                                                  initialValue:
                                                      draft
                                                          .settings['passing_percent']
                                                          ?.toString() ??
                                                      '',
                                                  enabled: contentEditing,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Passing score (optional)',
                                                        suffixText: '%',
                                                      ),
                                                  validator: (value) {
                                                    if (draft.locked)
                                                      return null;
                                                    if (value == null ||
                                                        value.trim().isEmpty) {
                                                      return null;
                                                    }
                                                    final percentage =
                                                        int.tryParse(
                                                          value.trim(),
                                                        );
                                                    return percentage == null ||
                                                            percentage < 0 ||
                                                            percentage > 100
                                                        ? 'Enter a whole percentage from 0 to 100.'
                                                        : null;
                                                  },
                                                  onChanged: (value) => setState(() {
                                                    // Keep invalid input dirty; validation prevents sending it.
                                                    draft.settings['passing_percent'] =
                                                        value.trim().isEmpty
                                                        ? null
                                                        : int.tryParse(
                                                                value.trim(),
                                                              ) ??
                                                              value;
                                                  }),
                                                ),
                                                _hint(
                                                  'Enter a percentage from 0 to 100, or leave blank to set no passing score.',
                                                ),
                                              ],
                                              if (page == 2) ...[
                                                Text(
                                                  '${draft.questionCount} ${draft.questionCount == 1 ? 'question' : 'questions'} | ${draft.questions.any((q) {
                                                        final n = int.tryParse(_editor(q).points);
                                                        return n == null || n < 1 || n > 1000;
                                                      }) ? 'Points need attention' : '${draft.totalPoints} ${draft.totalPoints == 1 ? 'point' : 'points'}'}',
                                                ),
                                                if (draft.questions.isEmpty)
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 16,
                                                        ),
                                                    child: Text(
                                                      'No questions yet.',
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (page == 2 && draft != null)
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          0,
                                          24,
                                          12,
                                        ),
                                        sliver: SliverToBoxAdapter(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              FiloButton(
                                                secondary: true,
                                                onPressed:
                                                    contentEditing &&
                                                        online &&
                                                        !draft
                                                            .reconciliationRequired
                                                    ? _addFromBank
                                                    : null,
                                                icon: Icons
                                                    .library_books_outlined,
                                                label: 'Add from question bank',
                                              ),
                                              if (!online)
                                                const Text(
                                                  'Connect to read or save questions in the bank.',
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (page == 2 && draft != null)
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          12,
                                          24,
                                          0,
                                        ),
                                        sliver: SliverReorderableList(
                                          itemCount: draft.questions.length,
                                          findChildIndexCallback: (key) {
                                            if (key is! ValueKey<String>)
                                              return null;
                                            final index = draft.questions
                                                .indexWhere(
                                                  (q) => q.localId == key.value,
                                                );
                                            return index < 0 ? null : index;
                                          },
                                          onReorder: (from, to) {
                                            if (contentEditing)
                                              _move(
                                                from,
                                                to > from ? to - 1 : to,
                                              );
                                          },
                                          itemBuilder: (context, index) {
                                            final q = draft.questions[index];
                                            return KeyedSubtree(
                                              key: ValueKey(q.localId),
                                              child: QuestionCard(
                                                canSaveToBank:
                                                    online &&
                                                    !_busy &&
                                                    !_loading,
                                                key: _cardKeys.putIfAbsent(
                                                  q.localId,
                                                  () => GlobalKey(),
                                                ),
                                                question: q,
                                                editor: _editor(q),
                                                index: index,
                                                expanded:
                                                    _expanded == q.localId,
                                                enabled: contentEditing,
                                                onToggle: () {
                                                  if (!_busy)
                                                    setState(
                                                      () => _expanded =
                                                          _expanded == q.localId
                                                          ? null
                                                          : q.localId,
                                                    );
                                                },
                                                onChanged: () => setState(
                                                  () => _questionDirty = true,
                                                ),
                                                onAction: (action) =>
                                                    _questionAction(q, action),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    if (page == 2 && draft != null)
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          0,
                                          24,
                                          24,
                                        ),
                                        sliver: SliverToBoxAdapter(
                                          child: PopupMenuButton<String>(
                                            enabled: contentEditing,
                                            tooltip: 'Add question',
                                            onSelected: (type) => setState(() {
                                              final q =
                                                  QuizQuestion.newQuestion(
                                                    type,
                                                  );
                                              draft.questions.add(q);
                                              _expanded = q.localId;
                                              _questionDirty = true;
                                              _revealQuestion(q.localId);
                                            }),
                                            itemBuilder: (_) => [
                                              for (final entry
                                                  in questionTypeLabels.entries)
                                                PopupMenuItem(
                                                  value: entry.key,
                                                  child: Text(entry.value),
                                                ),
                                            ],
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: FiloColors.tint,
                                                border: Border.all(
                                                  color: FiloColors.border,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.add,
                                                    color: FiloColors.primary,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text('Add question'),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                    Icons.expand_more,
                                                    color: FiloColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: draft == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!online && _step == 2 && !readOnly)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Connect to the internet to save or publish.',
                            ),
                          ),
                        if (_step < 2) ...[
                          if (_step > 0)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _navigate(_step - 1),
                              child: const Text('Back'),
                            ),
                          FiloButton(
                            label: _step == 0
                                ? 'Next: Settings'
                                : 'Next: Questions',
                            onPressed: !_busy && !_loading
                                ? () => _navigate(_step + 1)
                                : null,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _navigate(_step - 1),
                                  child: const Text('Back'),
                                ),
                              ),
                              if (!readOnly && !_published) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FiloButton(
                                    label: 'Save draft',
                                    secondary: true,
                                    onPressed:
                                        editing &&
                                            online &&
                                            !draft.reconciliationRequired &&
                                            (_dirty || draft.id == null)
                                        ? () => _save()
                                        : null,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!readOnly) const SizedBox(height: 8),
                          if (!readOnly)
                            FiloButton(
                              label: _published ? 'Save changes' : 'Publish',
                              busy: _busy,
                              onPressed:
                                  editing &&
                                      online &&
                                      !draft.reconciliationRequired &&
                                      (!_published ||
                                          _dirty ||
                                          draft.id == null)
                                  ? (_published ? () => _save() : _publish)
                                  : null,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
