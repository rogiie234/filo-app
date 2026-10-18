import 'dart:async';

import '../../grading/presentation/submissions_screen.dart';
import '../../grading/presentation/gradebook_screen.dart';
import '../../grading/presentation/my_grades_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/domain/prototype_models.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../../posts/application/post_providers.dart';
import '../../posts/presentation/stream_post_card.dart';
import '../../submissions/application/submission_providers.dart';
import '../../submissions/domain/assignment_status.dart';

final _classworkLoadedProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, key) async* {
      final repository = await ref.watch(postRepositoryProvider.future);
      if (repository == null) {
        yield false;
        return;
      }
      final db = repository.database;
      yield* (db.select(db.syncState)
            ..where((s) => s.syncedTableName.equals(key)))
          .watch()
          .map((rows) => rows.isNotEmpty);
    });

/// Assignments are always read from the account's SQLite cache.
class ClassworkList extends ConsumerStatefulWidget {
  const ClassworkList({
    super.key,
    required this.classId,
    required this.instructor,
    required this.live,
    required this.previewPosts,
    required this.onOpen,
  });
  final String classId;
  final bool instructor, live;
  final List<ClassPost> previewPosts;
  final ValueChanged<ClassPost> onOpen;

  @override
  ConsumerState<ClassworkList> createState() => _ClassworkListState();
}

class _ClassworkListState extends ConsumerState<ClassworkList> {
  String _filter = 'All';
  Timer? _clock;

  DateTime? _nextDue;

  void _scheduleDeadline(List<ClassPost> assignments) {
    final now = DateTime.now();
    final upcoming =
        assignments
            .map((p) => p.dueAt)
            .whereType<DateTime>()
            .where((due) => due.isAfter(now))
            .toList()
          ..sort();
    final next = upcoming.firstOrNull;
    if (_nextDue == next) return;
    _clock?.cancel();
    _nextDue = next;
    if (next != null) {
      _clock = Timer(
        next.difference(now) + const Duration(milliseconds: 1),
        () {
          if (mounted) setState(() => _nextDue = null);
        },
      );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!widget.live) return;
    try {
      if (widget.instructor) {
        ref.invalidate(postSyncProvider(widget.classId));
        await ref.read(postSyncProvider(widget.classId).future);
      } else {
        ref.invalidate(submissionSyncProvider(widget.classId));
        await ref.read(submissionSyncProvider(widget.classId).future);
      }
    } catch (_) {
      // Keep cached rows; the failed read offers Retry below.
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.classId;
    final live = widget.live;
    final student = !widget.instructor;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    if (live && student) ref.watch(submissionSyncLifecycleProvider(id));
    final posts = live ? ref.watch(streamPostsProvider(id)) : null;
    final submissions = live && student
        ? ref.watch(classSubmissionsProvider(id))
        : null;
    final grades = live && student
        ? ref.watch(returnedGradesProvider(id))
        : null;
    final sync = !live
        ? null
        : student
        ? ref.watch(submissionSyncProvider(id))
        : ref.watch(postSyncProvider(id));
    final checkpoint = live
        ? ref.watch(
            _classworkLoadedProvider(
              '${student ? 'submissions' : 'posts'}:$id',
            ),
          )
        : null;
    final confirmedLoad = !live || checkpoint?.asData?.value == true;
    final loading =
        live &&
        ((posts!.isLoading && !posts.hasValue) ||
            (student &&
                ((submissions!.isLoading && !submissions.hasValue) ||
                    (grades!.isLoading && !grades.hasValue))));
    final failed =
        live &&
        (posts!.hasError ||
            sync!.hasError ||
            checkpoint!.hasError ||
            (student && (submissions!.hasError || grades!.hasError)));
    final assignments =
        (live ? posts!.asData?.value ?? <ClassPost>[] : widget.previewPosts)
            .where(
              (post) => post.classId == id && post.postType == 'assignment',
            )
            .toList()
          ..sort((a, b) {
            if (a.dueAt == null && b.dueAt != null) return 1;
            if (a.dueAt != null && b.dueAt == null) return -1;
            final due = a.dueAt == null ? 0 : a.dueAt!.compareTo(b.dueAt!);
            return due != 0 ? due : a.id.compareTo(b.id);
          });
    _scheduleDeadline(assignments);
    final statusKnown =
        confirmedLoad &&
        !(submissions?.hasError ?? false) &&
        !(grades?.hasError ?? false);
    AssignmentStatus? statusFor(ClassPost post) {
      final own = submissions?.asData?.value
          .where((s) => s.postId == post.id)
          .firstOrNull;
      final grade = grades?.asData?.value
          .where((g) => g.submissionId == own?.id)
          .firstOrNull;
      if (!statusKnown && own == null && grade == null) return null;
      return assignmentStatus(dueAt: post.dueAt, submission: own, grade: grade);
    }

    bool matches(ClassPost post) {
      if (!student || _filter == 'All') return true;
      final status = statusFor(post);
      return switch (_filter) {
        'To do' =>
          status == AssignmentStatus.assigned ||
              status == AssignmentStatus.draft ||
              status == AssignmentStatus.missing,
        'Turned in' =>
          status == AssignmentStatus.turnedIn ||
              status == AssignmentStatus.late,
        'Graded' => status == AssignmentStatus.graded,
        _ => true,
      };
    }

    final visible = assignments.where(matches).toList();
    final content = ListView(
      key: PageStorageKey('classwork-$id'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Classwork', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Make space for your next small win.',
          style: TextStyle(color: FiloColors.secondary),
        ),
        const SizedBox(height: 20),
        if (live)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              icon: Icon(student ? Icons.grading : Icons.table_chart_outlined),
              label: Text(student ? 'My grades' : 'Gradebook'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => student
                      ? MyGradesScreen(classId: id)
                      : GradebookScreen(classId: id),
                ),
              ),
            ),
          ),
        if (live && !online)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: OfflineBanner(),
          ),
        if (student) ...[
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0, .025, .94, 1],
            ).createShader(rect),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final filter in ['All', 'To do', 'Turned in', 'Graded'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClassworkFilterChip(
                        label: filter,
                        selected: _filter == filter,
                        onSelected: () => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (failed) ...[
          const Text(
            'Could not refresh classwork. Saved work is shown when available.',
          ),
          TextButton(
            onPressed: () {
              ref.invalidate(
                _classworkLoadedProvider(
                  '${student ? 'submissions' : 'posts'}:$id',
                ),
              );
              ref.invalidate(streamPostsProvider(id));
              if (student) {
                ref.invalidate(classSubmissionsProvider(id));
                ref.invalidate(returnedGradesProvider(id));
              }
              _refresh();
            },
            child: const Text('Retry'),
          ),
        ],
        if (loading ||
            (live && assignments.isEmpty && online && sync!.isLoading))
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: StreamPostSkeleton(),
            )
        else if (assignments.isEmpty && !failed)
          if (confirmedLoad)
            const EmptyState(
              title: 'No classwork yet.',
              message: 'Your next learning adventure will appear here.',
            )
          else if (!online)
            const Text(
              'No saved classwork on this device. Connect to the internet and refresh.',
            )
          else
            TextButton(
              onPressed: _refresh,
              child: const Text('Refresh classwork'),
            )
        else if (visible.isEmpty && assignments.isNotEmpty)
          Text(
            statusKnown
                ? 'No assignments match this filter.'
                : 'Refresh to load your submission statuses.',
          )
        else
          for (final post in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AssignmentRow(
                post: post,
                status: student ? statusFor(post) : null,
                showStatus: student,
                onTap: () {
                  if (live && !student) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SubmissionsScreen(classId: id, postId: post.id),
                      ),
                    );
                  } else {
                    widget.onOpen(post);
                  }
                },
              ),
            ),
      ],
    );
    return live
        ? RefreshIndicator(onRefresh: _refresh, child: content)
        : content;
  }
}

class ClassworkFilterChip extends StatelessWidget {
  const ClassworkFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    onSelected: (_) => onSelected(),
  );
}

class AssignmentStatusChip extends StatelessWidget {
  const AssignmentStatusChip({super.key, required this.status});
  final AssignmentStatus? status;
  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      AssignmentStatus.assigned => Icons.assignment_outlined,
      AssignmentStatus.draft => Icons.edit_outlined,
      AssignmentStatus.turnedIn => Icons.check_circle_outline,
      AssignmentStatus.late => Icons.schedule,
      AssignmentStatus.graded => Icons.grading_outlined,
      AssignmentStatus.missing => Icons.error_outline,
      null => Icons.sync_outlined,
    };
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color:
            status == AssignmentStatus.late ||
                status == AssignmentStatus.missing
            ? FiloColors.error
            : FiloColors.primary,
      ),
      label: Text(status?.label ?? 'Sync needed'),
      labelStyle: TextStyle(
        color:
            status == AssignmentStatus.late ||
                status == AssignmentStatus.missing
            ? FiloColors.error
            : FiloColors.ink,
        fontWeight: status == AssignmentStatus.graded
            ? FontWeight.w800
            : FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class AssignmentRow extends StatelessWidget {
  const AssignmentRow({
    super.key,
    required this.post,
    required this.status,
    required this.showStatus,
    required this.onTap,
  });
  final ClassPost post;
  final AssignmentStatus? status;
  final bool showStatus;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: FiloColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: FiloColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(
              Icons.assignment_outlined,
              color: FiloColors.primary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    streamDueLabel(context, post),
                    style: const TextStyle(color: FiloColors.secondary),
                  ),
                  Text(
                    post.points == null ? 'No points' : '${post.points} points',
                    style: const TextStyle(color: FiloColors.secondary),
                  ),
                  if (showStatus) AssignmentStatusChip(status: status),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
