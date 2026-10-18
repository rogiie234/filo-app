import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
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
  });
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

final workQueueProvider = Provider.autoDispose.family<WorkQueueData, bool>((
  ref,
  student,
) {
  final cards = ref.watch(classCardsProvider);
  var loading = cards.isLoading;
  var failed = cards.hasError;
  var loaded = cards.hasValue;
  final entries = <WorkQueueEntry>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final nextWeek = today.add(Duration(days: 8 - today.weekday));
  for (final room in cards.asData?.value ?? <ClassRoom>[]) {
    if (room.archived || room.pending) {
      continue;
    }
    if (student) {
      final snapshot = ref.watch(gradingDataProvider(room.id));
      loaded &= snapshot.asData?.value.loaded == true;
      ref.watch(submissionSyncLifecycleProvider(room.id));
      final posts = ref.watch(streamPostsProvider(room.id));
      final subs = ref.watch(classSubmissionsProvider(room.id));
      final grades = ref.watch(returnedGradesProvider(room.id));
      final sync = ref.watch(submissionSyncProvider(room.id));
      loading |=
          posts.isLoading ||
          subs.isLoading ||
          grades.isLoading ||
          (sync.isLoading && (posts.asData?.value.isEmpty ?? true));
      failed |=
          posts.hasError || subs.hasError || grades.hasError || sync.hasError;
      for (final post in posts.asData?.value ?? <ClassPost>[]) {
        if (post.postType != 'assignment') {
          continue;
        }
        final sub = subs.asData?.value
            .where((s) => s.postId == post.id)
            .firstOrNull;
        final grade = grades.asData?.value
            .where((g) => g.submissionId == sub?.id)
            .firstOrNull;
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
      for (final sub in value.submissions) {
        final grade = value.grades
            .where((g) => g['submission_id'] == sub['id'])
            .firstOrNull;
        if (grade?['returned_at'] != null ||
            (grade == null &&
                (sub['status'] != 'turned_in' ||
                    sub['submitted_at'] == null))) {
          continue;
        }
        final post = value.assignments
            .where((p) => p['id'] == sub['post_id'])
            .firstOrNull;
        if (post == null) {
          continue;
        }
        final member = value.members
            .where((m) => m['student_id'] == sub['student_id'])
            .firstOrNull;
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
    (a, b) => (a.time ?? DateTime(9999)).compareTo(b.time ?? DateTime(9999)),
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
      await ref.read(classSyncProvider.notifier).refresh();
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

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(workQueueProvider(widget.student));
    final online = ref.watch(connectivityProvider).asData?.value == true;
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
                    leading: Icon(
                      widget.student
                          ? Icons.assignment_outlined
                          : Icons.person_outline,
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
                          avatar: Icon(
                            entry.status == 'Late' || entry.status == 'Missing'
                                ? Icons.schedule
                                : Icons.check_circle_outline,
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
