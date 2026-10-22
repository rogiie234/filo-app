import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../application/instructor_quiz_providers.dart';
import '../domain/quiz_draft.dart';
import '../domain/quiz_helpers.dart';
import 'assessment_row.dart';

/// Connected form entry for the list. Existing questions are preserved in full;
/// the dedicated question-editor task can extend this form without preview data.
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
  final _form = GlobalKey<FormState>();
  QuizDraft? _draft;
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
      _draft = QuizDraft(saved);
      // A stored value is an instructor choice, even when it matches a default.
      _answersChosenByHand = true;
      _published = saved.row['status'] == 'published';
      _revision++;
    });
  }

  Future<void> _reload() async {
    if (_busy || _loading) return;
    if (_draft?.isDirty == true) {
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

  Future<void> _leave() async {
    if (_busy) return;
    if (_draft?.isDirty == true) {
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

  Future<void> _save() async {
    if (_busy || _form.currentState?.validate() != true) return;
    final draft = _draft!;
    final opens = draft.settings['opens_at'] as String?;
    final closes = draft.settings['closes_at'] as String?;
    if (opens != null &&
        closes != null &&
        !DateTime.parse(closes).isAfter(DateTime.parse(opens))) {
      setState(() => _error = 'Closing time must be after the opening time.');
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
      final saved = await repository.save(draft);
      if (!mounted) return;
      _accept(saved);
      showMessage(context, _published ? 'Changes saved.' : 'Draft saved.');
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = draft.reconciliationRequired
              ? (draft.id == null
                    ? 'The save could not be confirmed. Check the classwork list before creating another draft.'
                    : 'The save could not be confirmed. Your edits are still here. Reload the saved version before trying again.')
              : error.toString().replaceFirst('Bad state: ', ''),
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
    final editing = !readOnly && !_busy && !_loading;
    final contentEditing = editing && draft?.locked != true;
    return PopScope(
      canPop: _allowPop || (!_busy && draft?.isDirty != true),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            readOnly
                ? 'Assessment'
                : draft?.id == null
                ? 'New assessment'
                : 'Edit assessment',
          ),
          leading: IconButton(
            tooltip: 'Back to classwork',
            onPressed: _busy ? null : _leave,
            icon: const FiloIcon(FiloIcons.back),
          ),
        ),
        body: SafeArea(
          child: _loading && draft == null
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (!online) const OfflineBanner(),
                      if (readOnly)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'This class is archived or unavailable. Assessments are read-only.',
                          ),
                        ),
                      if (draft?.locked == true)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'This quiz has already been started. Only the title and closing time can change.',
                          ),
                        )
                      else if (_published)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Students can already see this assessment. Your saved changes will affect it.',
                          ),
                        ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: FiloColors.error),
                        ),
                        if (online &&
                            (draft?.reconciliationRequired != true ||
                                draft?.id != null))
                          TextButton(
                            onPressed: _busy || _loading ? null : _reload,
                            child: Text(
                              draft?.reconciliationRequired == true
                                  ? 'Reload saved version'
                                  : 'Retry',
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (draft != null) ...[
                        TextFormField(
                          key: ValueKey('title-$_revision'),
                          initialValue: draft.settings['title'] as String?,
                          enabled: editing,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Give your assessment a title.'
                              : null,
                          onChanged: (value) =>
                              setState(() => draft.settings['title'] = value),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Quiz or Exam',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final type in ['quiz', 'exam'])
                              ChoiceChip(
                                label: Text(type == 'quiz' ? 'Quiz' : 'Exam'),
                                selected: draft.settings['type'] == type,
                                onSelected: contentEditing
                                    ? (_) => setState(() {
                                        draft.settings['type'] = type;
                                        if (!_answersChosenByHand) {
                                          draft.settings['show_correct_answers'] =
                                              type == 'quiz';
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
                          key: ValueKey('minutes-$_revision'),
                          initialValue:
                              '${draft.settings['time_limit_minutes']}',
                          enabled: contentEditing,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Time limit (minutes)',
                          ),
                          validator: (value) {
                            final n = int.tryParse(value ?? '');
                            return n == null || n < 1 || n > 600
                                ? 'Enter 1 to 600 minutes.'
                                : null;
                          },
                          onChanged: (value) => setState(
                            () => draft.settings['time_limit_minutes'] =
                                int.tryParse(value),
                          ),
                        ),
                        _hint(
                          'Choose 1 to 600 minutes; each attempt ends when time runs out or the assessment closes, whichever comes first.',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          key: ValueKey('instructions-$_revision'),
                          initialValue:
                              draft.settings['instructions'] as String?,
                          enabled: contentEditing,
                          maxLength: 5000,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Instructions (optional)',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (value) => setState(
                            () => draft.settings['instructions'] = value.isEmpty
                                ? null
                                : value,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        _hint(
                          'All dates and times use Philippine time (PHT, UTC+08:00).',
                        ),
                        const SizedBox(height: 16),
                        for (final field in ['opens_at', 'closes_at']) ...[
                          OutlinedButton.icon(
                            icon: const FiloIcon(FiloIcons.calendar),
                            onPressed:
                                (field == 'closes_at'
                                    ? editing
                                    : contentEditing)
                                ? () => _pickDate(field)
                                : null,
                            label: Text(
                              '${field == 'opens_at' ? 'Opens' : 'Closes'}: ${assessmentDateLabel(draft.settings[field] == null ? null : DateTime.parse(draft.settings[field] as String))}',
                            ),
                          ),
                          _hint(
                            field == 'opens_at'
                                ? 'Students can start at this date and time.'
                                : 'Students must finish by this date and time, even if their time limit has not run out.',
                          ),
                          if (draft.settings[field] != null &&
                              (field == 'closes_at' ? editing : contentEditing))
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => setState(
                                  () => draft.settings[field] = null,
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
                            contentPadding: EdgeInsets.zero,
                            title: Text(setting.$2),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(setting.$3),
                            ),
                            value: draft.settings[setting.$1] as bool,
                            onChanged: contentEditing
                                ? (value) => setState(() {
                                    draft.settings[setting.$1] = value;
                                    if (setting.$1 == 'show_correct_answers') {
                                      _answersChosenByHand = true;
                                    }
                                  })
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          key: ValueKey('passing-$_revision'),
                          initialValue:
                              draft.settings['passing_percent']?.toString() ??
                              '',
                          enabled: contentEditing,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Passing score (optional)',
                            suffixText: '%',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final percentage = int.tryParse(value.trim());
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
                                : int.tryParse(value.trim()) ?? value;
                          }),
                        ),
                        _hint(
                          'Enter a percentage from 0 to 100, or leave blank to set no passing score.',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Questions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${draft.questionCount} ${draft.questionCount == 1 ? 'question' : 'questions'} | ${draft.totalPoints} ${draft.totalPoints == 1 ? 'point' : 'points'}',
                        ),
                        if (draft.questions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('No questions yet.'),
                          ),
                        for (var i = 0; i < draft.questions.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: FiloPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Question ${i + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(draft.questions[i].prompt),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${draft.questions[i].points} ${draft.questions[i].points == 1 ? 'point' : 'points'}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
        bottomNavigationBar: draft == null || readOnly
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!online)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Connect to the internet to save changes.',
                          ),
                        ),
                      FiloButton(
                        label: _published ? 'Save changes' : 'Save draft',
                        busy: _busy,
                        onPressed:
                            editing &&
                                online &&
                                !draft.reconciliationRequired &&
                                (draft.isDirty || draft.id == null)
                            ? _save
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
