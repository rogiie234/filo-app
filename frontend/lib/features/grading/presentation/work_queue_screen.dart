import 'dart:async';

import '../../exams/application/exam_providers.dart';
import '../../exams/domain/exam.dart';
import '../../exams/domain/student_quiz_status.dart';
import '../../exams/presentation/student_quiz_detail_screen.dart';
import '../../exams/presentation/student_quiz_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/domain/prototype_models.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../../posts/application/post_providers.dart';
import '../../posts/presentation/stream_post_card.dart';
import '../../submissions/application/submission_providers.dart';
import '../../submissions/domain/assignment_status.dart';
import '../../submissions/presentation/assignment_detail_screen.dart';
import '../application/grading_providers.dart';
import 'grade_screen.dart';
import 'todo_widgets.dart';

enum WorkQueueItemType { assignment, quiz }

class WorkQueueEntry {
  const WorkQueueEntry(
    this.room,
    this.postId,
    this.title,
    this.group,
    this.status, {
    this.studentId,
    this.studentName,
    this.time,
    this.points,
    this.type = WorkQueueItemType.assignment,
    this.quiz,
  });
  final WorkQueueItemType type;
  final StudentQuiz? quiz;
  final ClassRoom room;
  final String postId, title, group, status;
  final String? studentId, studentName;
  final DateTime? time;
  final int? points;
}

class WorkQueueData {
  const WorkQueueData(this.entries, this.loading, this.failed, this.loaded);
  final List<WorkQueueEntry> entries;
  final bool loading, failed, loaded;
}

// Preserve the previous first-match behavior if a snapshot contains duplicates.
Map<K, T> _firstBy<T, K>(Iterable<T>? rows, K Function(T) key) {
  final result = <K, T>{};
  for (final row in rows ?? <T>[]) {
    result.putIfAbsent(key(row), () => row);
  }
  return result;
}

/// Badge reads do not construct, format, or sort full queue entries.
final reviewQueueCountProvider = Provider.autoDispose<int>((ref) {
  final cards = ref.watch(classCardsProvider);
  var count = 0;
  for (final room in cards.value ?? <ClassRoom>[]) {
    if (room.archived || room.pending) continue;
    final data = ref.watch(gradingDataProvider(room.id));
    ref.watch(gradingSyncProvider(room.id));
    final value = data.asData?.value;
    if (value == null) continue;
    final grades = _firstBy(value.grades, (g) => g['submission_id']);
    final postIds = value.assignments.map((p) => p['id']).toSet();
    for (final sub in value.submissions) {
      final grade = grades[sub['id']];
      if (grade?['returned_at'] != null ||
          (grade == null &&
              (sub['status'] != 'turned_in' || sub['submitted_at'] == null))) {
        continue;
      }
      if (postIds.contains(sub['post_id'])) count++;
    }
  }
  return count;
});

final workQueueProvider = Provider.autoDispose.family<WorkQueueData, bool>((
  ref,
  student,
) {
  final cards = ref.watch(classCardsProvider);
  var loading = cards.isLoading;
  var failed = cards.hasError;
  var loaded = cards.hasValue;
  final entries = <WorkQueueEntry>[];
  final catalog = student ? ref.watch(studentQuizCatalogProvider) : null;
  final now = student
      ? (ref.watch(studentQuizNowProvider).asData?.value ??
                DateTime.now().toUtc())
            .toLocal()
      : DateTime.now();
  if (student) {
    loading |= catalog!.isLoading && !catalog.hasValue;
    loading |=
        catalog.value?.refreshing == true && catalog.value!.quizzes.isEmpty;
    failed |= catalog.hasError || catalog.value?.failed == true;
    loaded &= catalog.value?.loaded == true;
  }
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final nextWeek = today.add(Duration(days: 8 - today.weekday));
  for (final room in cards.value ?? <ClassRoom>[]) {
    if (room.archived || room.pending) {
      continue;
    }
    if (student) {
      for (final quiz in catalog?.value?.quizzes ?? <StudentQuiz>[]) {
        if (quiz.classId != room.id) continue;
        entries.add(
          WorkQueueEntry(
            room,
            quiz.id,
            quiz.title,
            studentQuizGroup(quiz, now),
            studentQuizState(quiz, now).status.label,
            time: quiz.closesAt,
            points: quiz.points,
            type: WorkQueueItemType.quiz,
            quiz: quiz,
          ),
        );
      }
      final snapshot = ref.watch(gradingDataProvider(room.id));
      loaded &= snapshot.value?.loaded == true;
      ref.watch(submissionSyncLifecycleProvider(room.id));
      final posts = ref.watch(streamPostsProvider(room.id));
      final subs = ref.watch(classSubmissionsProvider(room.id));
      final grades = ref.watch(returnedGradesProvider(room.id));
      final sync = ref.watch(submissionSyncProvider(room.id));
      loading |=
          posts.isLoading ||
          subs.isLoading ||
          grades.isLoading ||
          (sync.isLoading && (posts.value?.isEmpty ?? true));
      failed |=
          posts.hasError || subs.hasError || grades.hasError || sync.hasError;
      final subsByPost = _firstBy(subs.value, (s) => s.postId);
      final gradesBySubmission = _firstBy(grades.value, (g) => g.submissionId);
      for (final post in posts.value ?? <ClassPost>[]) {
        if (post.postType != 'assignment') {
          continue;
        }
        final sub = subsByPost[post.id];
        final grade = gradesBySubmission[sub?.id];
        final status = assignmentStatus(
          dueAt: post.dueAt,
          submission: sub,
          grade: grade,
        );
        final done = sub?.status == 'turned_in' || grade?.returnedAt != null;
        final due = post.dueAt;
        final group = done
            ? 'Done'
            : due == null
            ? 'Later'
            : due.isBefore(now)
            ? 'Overdue'
            : due.isBefore(tomorrow)
            ? 'Today'
            : due.isBefore(nextWeek)
            ? 'This week'
            : 'Later';
        entries.add(
          WorkQueueEntry(
            room,
            post.id,
            post.title,
            group,
            status.label,
            time: due,
            points: post.points,
          ),
        );
      }
    } else {
      final data = ref.watch(gradingDataProvider(room.id));
      final sync = ref.watch(gradingSyncProvider(room.id));
      loading |=
          data.isLoading ||
          (sync.isLoading && (data.asData?.value.assignments.isEmpty ?? true));
      failed |= data.hasError || sync.hasError;
      final value = data.asData?.value;
      loaded &= value?.loaded == true;
      if (value == null) {
        continue;
      }
      final gradesBySubmission = _firstBy(
        value.grades,
        (g) => g['submission_id'],
      );
      final postsById = _firstBy(value.assignments, (p) => p['id']);
      final membersByStudent = _firstBy(value.members, (m) => m['student_id']);
      for (final sub in value.submissions) {
        final grade = gradesBySubmission[sub['id']];
        if (grade?['returned_at'] != null ||
            (grade == null &&
                (sub['status'] != 'turned_in' ||
                    sub['submitted_at'] == null))) {
          continue;
        }
        final post = postsById[sub['post_id']];
        if (post == null) {
          continue;
        }
        final member = membersByStudent[sub['student_id']];
        final profile = member?['profiles'];
        final name = profile is Map
            ? profile['display_name']?.toString()
            : member?['display_name']?.toString();
        entries.add(
          WorkQueueEntry(
            room,
            post['id'] as String,
            post['title'] as String? ?? 'Assignment',
            grade == null ? 'To grade' : 'Graded, not returned',
            sub['is_late'] == true ? 'Late' : 'Turned in',
            studentId: sub['student_id'] as String,
            studentName: name ?? 'Student',
            time: DateTime.tryParse(sub['submitted_at']?.toString() ?? ''),
          ),
        );
      }
    }
  }
  entries.sort(
    (a, b) => student
        ? compareStudentWork(
            a.time,
            '${a.type.name}:${a.postId}',
            b.time,
            '${b.type.name}:${b.postId}',
          )
        : (a.time ?? DateTime(9999)).compareTo(b.time ?? DateTime(9999)),
  );
  return WorkQueueData(entries, loading, failed, loaded);
});

class WorkQueueScreen extends ConsumerStatefulWidget {
  const WorkQueueScreen({
    super.key,
    required this.student,
    this.embedded = false,
  });
  final bool student, embedded;
  @override
  ConsumerState<WorkQueueScreen> createState() => _WorkQueueScreenState();
}

class _WorkQueueScreenState extends ConsumerState<WorkQueueScreen> {
  final Set<String> _busy = {};
  String _taskFilter = 'All';
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidate(workQueueProvider(widget.student));
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      if (widget.student) ref.invalidate(studentQuizCatalogProvider);
      await ref.read(classSyncProvider.notifier).refresh();
      if (widget.student) {
        final repository = await ref.read(studentExamRepositoryProvider.future);
        await repository?.refreshCatalog();
      }
      final rooms = ref.read(classCardsProvider).asData?.value ?? <ClassRoom>[];
      await Future.wait(
        rooms.where((r) => !r.archived && !r.pending).map((r) async {
          if (widget.student) {
            ref.invalidate(submissionSyncProvider(r.id));
            await ref.read(submissionSyncProvider(r.id).future);
          } else {
            ref.invalidate(gradingSyncProvider(r.id));
            await ref.read(gradingSyncProvider(r.id).future);
          }
        }),
      );
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not refresh. Saved work is shown. Pull to refresh to retry.',
        );
      }
    }
  }

  Widget _studentBody(WorkQueueData queue, bool online) {
    const groups = ['Overdue', 'Today', 'This week', 'Later', 'Done'];
    final visible = queue.entries
        .where(
          (entry) => switch (_taskFilter) {
            'Done' => entry.group == 'Done',
            'To do' => entry.group != 'Done',
            _ => true,
          },
        )
        .toList();
    final empty = queue.entries.isEmpty;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Semantics(
            header: true,
            child: const Text(
              'To-do',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: FiloColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Assignments and quizzes, organized by due date.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: FiloColors.secondary,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in ['All', 'To do', 'Done'])
                ChoiceChip(
                  label: Text(filter),
                  selected: _taskFilter == filter,
                  selectedColor: FiloColors.selected,
                  backgroundColor: FiloColors.surface,
                  labelStyle: TextStyle(
                    color: _taskFilter == filter
                        ? FiloColors.ink
                        : FiloColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: _taskFilter == filter
                        ? FiloColors.primary
                        : FiloColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _taskFilter = filter),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!online) ...const [OfflineBanner(), SizedBox(height: 16)],
          if (queue.failed) ...[
            FiloPanel(
              color: FiloColors.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Could not refresh work.',
                    style: TextStyle(color: FiloColors.ink, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: online ? _refresh : null,
                      icon: const FiloIcon(FiloIcons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (queue.loading && empty)
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: TodoTaskSkeleton(),
              ),
          if (!queue.loading && !queue.failed && visible.isEmpty)
            TodoEmptyState(
              mascotPose: _taskFilter == 'Done' ? 'waiting' : 'cheerful_note',
              title: !queue.loaded
                  ? 'No saved work.'
                  : _taskFilter == 'Done'
                  ? 'No completed work yet.'
                  : "You're all caught up.",
              message: !queue.loaded
                  ? 'Connect to the internet and refresh.'
                  : _taskFilter == 'Done'
                  ? 'Submitted work will appear here.'
                  : !empty
                  ? 'Check Done to view submitted work.'
                  : 'Assignments and quizzes will appear here when your instructor posts them.',
            ),
          for (final group in groups)
            if (visible.any((entry) => entry.group == group)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FiloColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.where((entry) => entry.group == group).length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FiloColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final entry in visible.where(
                (entry) => entry.group == group,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: entry.type == WorkQueueItemType.quiz
                      ? StudentQuizRow(
                          key: ValueKey('quiz:${entry.postId}'),
                          quiz: entry.quiz!,
                          now:
                              ref.watch(studentQuizNowProvider).asData?.value ??
                              DateTime.now().toUtc(),
                          classLabel:
                              '${entry.room.section} \u00b7 ${entry.room.course}',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StudentQuizDetailScreen(
                                classId: entry.room.id,
                                quizId: entry.postId,
                              ),
                            ),
                          ),
                        )
                      : TodoTaskCard(
                          title: entry.title,
                          classLabel:
                              '${entry.room.section} \u00b7 ${entry.room.course}',
                          status: entry.status,
                          points: entry.points,
                          dueLabel: entry.time == null
                              ? 'No due date'
                              : 'Due ${MaterialLocalizations.of(context).formatMediumDate(entry.time!.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.time!.toLocal()))}',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AssignmentDetailScreen(
                                classId: entry.room.id,
                                postId: entry.postId,
                              ),
                            ),
                          ),
                        ),
                ),
            ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(workQueueProvider(widget.student));
    final online = ref.watch(connectivityProvider).asData?.value == true;
    if (widget.student) {
      final body = _studentBody(queue, online);
      return widget.embedded
          ? body
          : Scaffold(
              appBar: AppBar(),
              body: SafeArea(child: body),
            );
    }
    final groups = widget.student
        ? ['Overdue', 'Today', 'This week', 'Later', 'Done']
        : ['To grade', 'Graded, not returned'];
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.student ? 'To-do' : 'To review',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (!online) const OfflineBanner(),
          if (queue.failed)
            TextButton(
              onPressed: online ? _refresh : null,
              child: const Text('Could not refresh work. Retry'),
            ),
          if (queue.loading && queue.entries.isEmpty) ...const [
            StreamPostSkeleton(),
            StreamPostSkeleton(),
            StreamPostSkeleton(),
          ],
          if (!queue.loading && !queue.failed && queue.entries.isEmpty)
            Text(
              !queue.loaded
                  ? 'No saved work. Connect to the internet and refresh.'
                  : widget.student
                  ? "You're all caught up."
                  : 'Nothing to grade right now.',
            ),
          for (final group in groups)
            if (queue.entries.any((e) => e.group == group)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  group,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final entry in queue.entries.where((e) => e.group == group))
                Card(
                  child: ListTile(
                    leading: FiloIcon(
                      widget.student ? FiloIcons.assessment : FiloIcons.person,
                    ),
                    title: Text(
                      widget.student ? entry.title : entry.studentName!,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.student) Text(entry.title),
                        Text('${entry.room.section} • ${entry.room.course}'),
                        Text(
                          entry.time == null
                              ? (widget.student
                                    ? 'No due date'
                                    : 'No work turned in')
                              : '${widget.student ? 'Due' : 'Turned in'} ${MaterialLocalizations.of(context).formatMediumDate(entry.time!.toLocal())} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(entry.time!.toLocal()))}',
                        ),
                        if (widget.student) Text('${entry.points ?? 0} points'),
                        Chip(
                          avatar: FiloIcon(
                            entry.status == 'Late' || entry.status == 'Missing'
                                ? FiloIcons.clock
                                : FiloIcons.checkCircle,
                            size: 16,
                          ),
                          label: Text(
                            entry.group == 'Graded, not returned'
                                ? 'Graded (not returned)'
                                : entry.status,
                          ),
                        ),
                        if (!widget.student && group == 'Graded, not returned')
                          TextButton(
                            onPressed:
                                online &&
                                    !_busy.contains(
                                      '${entry.room.id}:${entry.postId}',
                                    )
                                ? () => _return(entry)
                                : null,
                            child: const Text('Return assignment grades'),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => widget.student
                            ? AssignmentDetailScreen(
                                classId: entry.room.id,
                                postId: entry.postId,
                              )
                            : GradeScreen(
                                classId: entry.room.id,
                                postId: entry.postId,
                                studentId: entry.studentId!,
                              ),
                      ),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(widget.student ? 'To-do' : 'To review')),
            body: body,
          );
  }

  Future<void> _return(WorkQueueEntry entry) async {
    final key = '${entry.room.id}:${entry.postId}';
    setState(() => _busy.add(key));
    try {
      if (ref.read(connectivityProvider).asData?.value != true) {
        return;
      }
      final repository = await ref.read(gradingRepositoryProvider.future);
      if (repository == null) {
        throw StateError('Sign in required');
      }
      await repository.refresh(entry.room.id);
      final data = await repository.read(entry.room.id);
      final ids = data.submissions
          .where((s) => s['post_id'] == entry.postId)
          .map((s) => s['id'])
          .toSet();
      final count = data.grades
          .where(
            (g) => ids.contains(g['submission_id']) && g['returned_at'] == null,
          )
          .length;
      if (!mounted) {
        return;
      }
      if (count == 0) {
        showMessage(context, 'No grades to return.');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Return $count graded ${count == 1 ? 'work' : 'works'}?'),
          content: Text(
            count == 1
                ? 'This student will be able to see their score and feedback.'
                : 'These students will be able to see their scores and feedback.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Return'),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          ref.read(connectivityProvider).asData?.value != true) {
        return;
      }
      final returned = await repository.returnAll(entry.room.id, entry.postId);
      if (mounted) {
        showMessage(
          context,
          returned == 0
              ? 'No grades to return.'
              : '$returned ${returned == 1 ? 'grade' : 'grades'} returned.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          "We couldn't confirm the update. Refresh to check the grade before trying again.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(key));
      }
    }
  }
}
