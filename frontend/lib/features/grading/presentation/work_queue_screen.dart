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
import '../../../core/widgets/entry_background.dart';
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
import 'submissions_screen.dart';
import '../domain/grading_models.dart';
import '../../results/domain/results.dart';
import '../../results/presentation/instructor_results_screen.dart';
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
    this.activityLabel = 'Assignment',
  });
  final WorkQueueItemType type;
  final StudentQuiz? quiz;
  final String activityLabel;
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

/// Badge and folders count the same pending student submissions/attempts.
final reviewQueueCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(workQueueProvider(false)).entries.length,
);

List<WorkQueueEntry> instructorReviewEntries(
  ClassRoom room,
  GradingData data,
  DateTime now,
) {
  final entries = <WorkQueueEntry>[];
  final grades = _firstBy(data.grades, (g) => g['submission_id']);
  final posts = _firstBy(data.assignments, (p) => p['id']);
  final members = _firstBy(data.members, (m) => m['student_id']);
  for (final sub in data.submissions) {
    final grade = grades[sub['id']];
    final post = posts[sub['post_id']];
    if (post == null ||
        grade?['returned_at'] != null ||
        (grade == null &&
            (sub['status'] != 'turned_in' || sub['submitted_at'] == null)))
      continue;
    final profile = members[sub['student_id']]?['profiles'];
    entries.add(
      WorkQueueEntry(
        room,
        post['id'] as String,
        post['title'] as String? ?? 'Assignment',
        grade == null ? 'To grade' : 'Graded, not returned',
        sub['is_late'] == true ? 'Late' : 'Turned in',
        studentId: sub['student_id'] as String,
        studentName: profile is Map
            ? profile['display_name']?.toString() ?? 'Student'
            : 'Student',
        time: DateTime.tryParse('${sub['submitted_at'] ?? ''}'),
      ),
    );
  }
  final attemptsByQuiz = <Object?, List<Json>>{};
  for (final attempt in data.quizAttempts) {
    (attemptsByQuiz[attempt['quiz_id']] ??= []).add(attempt);
  }
  for (final quiz in data.quizzes) {
    if (quiz['status'] != 'published' ||
        quiz['deleted_at'] != null ||
        quiz['results_released_at'] != null)
      continue;
    final attempts = attemptsByQuiz[quiz['id']] ?? <Json>[];
    final monitoring = QuizMonitoring({'quiz': quiz, 'sessions': attempts});
    final blocked = monitoring.releaseBlocked(now);
    for (final attempt in monitoring.current.where(
      (a) => a.submitted && !a.released,
    )) {
      entries.add(
        WorkQueueEntry(
          room,
          quiz['id'] as String,
          quiz['title'] as String,
          !attempt.gradingComplete
              ? 'To grade'
              : blocked == null
              ? 'Ready to release'
              : 'Awaiting release',
          !attempt.gradingComplete
              ? 'Needs grading'
              : blocked ?? 'Ready to release',
          studentId: attempt.studentId,
          studentName: attempt.studentName,
          time: DateTime.tryParse('${attempt.json['submitted_at'] ?? ''}'),
          type: WorkQueueItemType.quiz,
          activityLabel: quiz['type'] == 'exam' ? 'Exam' : 'Quiz',
        ),
      );
    }
  }
  return entries;
}

class ReviewActivity {
  ReviewActivity(this.entries);
  final List<WorkQueueEntry> entries;
  WorkQueueEntry get first => entries.first;
  String get id => '${first.room.id}:${first.type.name}:${first.postId}';
  int get toGrade => entries.where((e) => e.group == 'To grade').length;
  int get ready => entries
      .where(
        (e) =>
            e.group == 'Graded, not returned' || e.group == 'Ready to release',
      )
      .length;
  int get awaiting => entries.length - toGrade - ready;
  String get summary => [
    if (toGrade > 0) '$toGrade to grade',
    if (ready > 0)
      '$ready ready to ${first.type == WorkQueueItemType.quiz ? 'release' : 'return'}',
    if (awaiting > 0) '$awaiting awaiting release',
  ].join(' / ');
}

List<ReviewActivity> reviewActivities(Iterable<WorkQueueEntry> entries) {
  final grouped = <String, List<WorkQueueEntry>>{};
  for (final entry in entries) {
    (grouped['${entry.room.id}:${entry.type.name}:${entry.postId}'] ??= []).add(
      entry,
    );
  }
  final activities = grouped.values.map((rows) {
    rows.sort(
      (a, b) => (a.time ?? DateTime(9999)).compareTo(b.time ?? DateTime(9999)),
    );
    return ReviewActivity(rows);
  }).toList();
  activities.sort((a, b) {
    final date = (a.first.time ?? DateTime(9999)).compareTo(
      b.first.time ?? DateTime(9999),
    );
    if (date != 0) return date;
    final title = a.first.title.compareTo(b.first.title);
    return title != 0 ? title : a.id.compareTo(b.id);
  });
  return activities;
}

final workQueueProvider = Provider.autoDispose.family<WorkQueueData, bool>((
  ref,
  student,
) {
  final cards = ref.watch(classCardsProvider);
  var loading = cards.isLoading && !cards.hasValue;
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
        catalog.value?.refreshing == true &&
        catalog.value?.loaded != true &&
        catalog.value!.quizzes.isEmpty;
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
          (posts.isLoading && !posts.hasValue) ||
          (subs.isLoading && !subs.hasValue) ||
          (grades.isLoading && !grades.hasValue) ||
          (sync.isLoading &&
              snapshot.value?.loaded != true &&
              (posts.value?.isEmpty ?? true));
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
          (data.isLoading && !data.hasValue) ||
          (sync.isLoading &&
              data.value?.loaded != true &&
              (data.value?.assignments.isEmpty ?? true));
      failed |= data.hasError || sync.hasError;
      final value = data.value;
      loaded &= value?.loaded == true;
      if (value == null) {
        continue;
      }
      loaded &= value.quizzesLoaded;
      entries.addAll(instructorReviewEntries(room, value, now));
    }
  }
  if (student) {
    entries.sort(
      (a, b) => compareStudentWork(
        a.time,
        '${a.type.name}:${a.postId}',
        b.time,
        '${b.type.name}:${b.postId}',
      ),
    );
  }
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
    return FiloFirstListLoad(
      id: 'student-work-queue',
      ready: queue.loaded && !queue.loading && !queue.failed,
      hasItems: queue.entries.isNotEmpty,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            FiloSpacing.screen,
            FiloSpacing.s16,
            FiloSpacing.screen,
            FiloSpacing.s32,
          ),
          children: [
            FiloPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'To-do',
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.s8),
                  Text(
                    'Assignments and quizzes, organized by due date.',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: FiloSpacing.s20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in ['All', 'To do', 'Done'])
                        FiloAnimatedChip(
                          label: Text(filter),
                          selected: _taskFilter == filter,
                          selectedColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surface,
                          labelStyle: Theme.of(context).textTheme.labelMedium!
                              .copyWith(
                                color: _taskFilter == filter
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                              ),
                          side: BorderSide(
                            color: _taskFilter == filter
                                ? Theme.of(context).colorScheme.primary
                                : FiloThemeTokens.of(context).controlBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: FiloSpacing.s12,
                            vertical: FiloSpacing.s8,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          onSelected: empty
                              ? null
                              : (_) => setState(() => _taskFilter = filter),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: FiloSpacing.screen),
            if (!online) ...const [
              OfflineBanner(),
              SizedBox(height: FiloSpacing.s16),
            ],
            if (queue.failed) ...[
              EmptyState(
                title: 'Work could not refresh',
                body:
                    'Saved work is shown when available; reconnect and retry.',
                showMascot: empty,
                pose: 'confused',
                bob: false,
                action: TextButton.icon(
                  onPressed: online ? _refresh : null,
                  icon: const FiloIcon(FiloIcons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
              const SizedBox(height: FiloSpacing.s16),
            ],
            if (queue.loading && empty && !queue.failed)
              FiloDelayedLoading(
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: FiloSpacing.s12),
                        child: TodoTaskSkeleton(),
                      ),
                  ],
                ),
              ),
            if (!queue.loading && !queue.failed && visible.isEmpty)
              EmptyState(
                pose: (!queue.loaded || (!online && empty))
                    ? 'sleepy'
                    : empty
                    ? 'waiting'
                    : _taskFilter == 'Done'
                    ? 'waiting'
                    : 'clock',
                bob: queue.loaded,
                title: (!queue.loaded || (!online && empty))
                    ? 'No saved work'
                    : _taskFilter == 'Done'
                    ? 'No completed work yet'
                    : empty
                    ? 'No work yet'
                    : _taskFilter == 'To do'
                    ? "You're all caught up"
                    : 'No matching work',
                action: (!queue.loaded || (!online && empty))
                    ? FiloButton(
                        label: 'Refresh',
                        onPressed: online ? _refresh : null,
                      )
                    : !empty
                    ? FiloButton(
                        label: 'Show all work',
                        onPressed: () => setState(() => _taskFilter = 'All'),
                      )
                    : null,
                message: (!queue.loaded || (!online && empty))
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
                  padding: const EdgeInsets.only(
                    top: FiloSpacing.s8,
                    bottom: FiloSpacing.s12,
                  ),
                  child: Semantics(
                    header: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group,
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                          ),
                        ),
                        Text(
                          '${visible.where((entry) => entry.group == group).length}',
                          style: Theme.of(context).textTheme.labelMedium!
                              .copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
                    padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
                    child: FiloListItem(
                      index: visible.indexOf(entry),
                      child: entry.type == WorkQueueItemType.quiz
                          ? StudentQuizRow(
                              key: ValueKey('quiz:${entry.postId}'),
                              quiz: entry.quiz!,
                              now:
                                  ref
                                      .watch(studentQuizNowProvider)
                                      .asData
                                      ?.value ??
                                  DateTime.now().toUtc(),
                              classLabel:
                                  '${entry.room.section} \u00b7 ${entry.room.course}',
                              onTap: () => Navigator.of(context).push(
                                FiloInstantRoute<void>(
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
                  ),
              ],
          ],
        ),
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
          : EntryBackground(
              variation: 7,
              verification: true,
              breeze: true,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                ),
                body: SafeArea(child: body),
              ),
            );
    }
    final activities = reviewActivities(queue.entries);
    final byClass = <String, List<ReviewActivity>>{};
    for (final activity in activities) {
      (byClass[activity.first.room.id] ??= []).add(activity);
    }
    final rooms = byClass.values.map((rows) => rows.first.first.room).toList()
      ..sort((a, b) {
        final date = (byClass[a.id]!.first.first.time ?? DateTime(9999))
            .compareTo(byClass[b.id]!.first.first.time ?? DateTime(9999));
        if (date != 0) return date;
        final title = '${a.course} / ${a.section}'.compareTo(
          '${b.course} / ${b.section}',
        );
        return title != 0 ? title : a.id.compareTo(b.id);
      });
    final body = FiloFirstListLoad(
      id: 'instructor-work-queue',
      ready: queue.loaded && !queue.loading && !queue.failed,
      hasItems: queue.entries.isNotEmpty,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            FiloSpacing.screen,
            FiloSpacing.s16,
            FiloSpacing.screen,
            FiloSpacing.screen,
          ),
          children: [
            Text(
              widget.student ? 'To-do' : 'To review',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: FiloSpacing.s8),
            Text(
              'Student work, ready for your feedback.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: FiloSpacing.s16),
            if (!online) const OfflineBanner(),
            if (queue.failed)
              EmptyState(
                title: 'Work could not refresh',
                body:
                    'Saved work is shown when available; reconnect and retry.',
                pose: 'confused',
                bob: false,
                showMascot: queue.entries.isEmpty,
                action: TextButton(
                  onPressed: online ? _refresh : null,
                  child: const Text('Retry'),
                ),
              ),
            if (queue.loading && queue.entries.isEmpty && !queue.failed)
              const FiloDelayedLoading(
                child: Column(
                  children: [
                    StreamPostSkeleton(),
                    StreamPostSkeleton(),
                    StreamPostSkeleton(),
                  ],
                ),
              ),
            if (!queue.loading &&
                !queue.failed &&
                queue.entries.isEmpty &&
                queue.loaded &&
                online)
              const EmptyState(
                title: 'No work to review',
                body: 'Student work will appear here when it is ready for your review.',
                pose: 'waiting',
              ),
            if (!queue.loading &&
                !queue.failed &&
                queue.entries.isEmpty &&
                (!queue.loaded || !online))
              EmptyState(
                pose: queue.loaded ? 'clock' : 'sleepy',
                bob: queue.loaded,
                title: 'No saved work',
                body: 'Connect and refresh to load work for review.',
                primaryAction: EmptyStateAction(
                  label: 'Refresh',
                  onPressed: online ? _refresh : null,
                ),
              ),
            for (final room in rooms)
              Card(
                key: ValueKey('review-class:${room.id}'),
                child: ExpansionTile(
                  key: PageStorageKey('review-class:${room.id}'),
                  leading: const FiloIcon(FiloIcons.folder),
                  title: Text('${room.course} / ${room.section}'),
                  subtitle: Text(
                    [
                      if (room.schoolYear?.isNotEmpty == true) room.schoolYear!,
                      'Pending submissions: ${byClass[room.id]!.fold<int>(0, (count, activity) => count + activity.entries.length)}',
                    ].join(' / '),
                  ),
                  children: [
                    for (final activity in byClass[room.id]!)
                      ListTile(
                        key: ValueKey(activity.id),
                        contentPadding: const EdgeInsets.all(FiloSpacing.s16),
                        leading: const FiloIcon(FiloIcons.folder),
                        title: Text(
                          '${activity.first.title} / ${activity.first.activityLabel}',
                        ),
                        subtitle: Text(
                          [
                            activity.summary,
                            if (activity.awaiting > 0)
                              activity.entries
                                  .firstWhere(
                                    (e) => e.group == 'Awaiting release',
                                  )
                                  .status,
                          ].join('\n'),
                        ),
                        trailing: const FiloIcon(FiloIcons.chevronRight),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  activity.first.type == WorkQueueItemType.quiz
                                  ? InstructorResultsScreen(
                                      quizId: activity.first.postId,
                                    )
                                  : SubmissionsScreen(
                                      classId: room.id,
                                      postId: activity.first.postId,
                                    ),
                            ),
                          );
                          if (mounted)
                            ref.invalidate(gradingSyncProvider(room.id));
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return widget.embedded
        ? body
        : EntryBackground(
            variation: 7,
            verification: true,
            breeze: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(widget.student ? 'To-do' : 'To review'),
              ),
              body: body,
            ),
          );
  }
}
