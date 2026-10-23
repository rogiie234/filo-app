import 'dart:async';

import '../../exams/application/exam_providers.dart';
import '../../exams/domain/exam.dart';
import '../../exams/domain/student_quiz_status.dart';
import '../../exams/presentation/student_quiz_detail_screen.dart';
import '../../exams/presentation/student_quiz_widgets.dart';

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

final classworkLoadedProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, key) async* {
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
  },
);

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
      ref.invalidate(studentQuizCatalogProvider);
      final online = await ref.read(connectivityMonitorProvider).recheck();
      if (!mounted || !online) return;
      if (!widget.instructor) {
        final repository = await ref.read(studentExamRepositoryProvider.future);
        await repository?.refreshCatalog();
        if (!mounted) return;
      }
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
    final catalog = live && student
        ? ref.watch(studentQuizCatalogProvider)
        : null;
    final now = live && student
        ? ref.watch(studentQuizNowProvider).asData?.value ??
              DateTime.now().toUtc()
        : DateTime.now().toUtc();
    final quizzes =
        catalog?.value?.quizzes.where((q) => q.classId == id).toList() ??
        <StudentQuiz>[];
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
            classworkLoadedProvider('${student ? 'submissions' : 'posts'}:$id'),
          )
        : null;
    final confirmedLoad = !live || checkpoint?.value == true;
    final needPosts = _filter != 'Quizzes';
    final needQuizzes = live && student && _filter != 'Graded';
    final needStatuses = student && _filter != 'All' && _filter != 'Quizzes';
    final postsReady =
        !live ||
        posts!.hasValue &&
            !((posts.value?.isEmpty ?? true) &&
                !confirmedLoad &&
                online &&
                sync!.isLoading);
    final quizzesReady =
        !needQuizzes ||
        catalog?.value != null &&
            (catalog!.value!.loaded || !catalog.value!.refreshing);
    final failed =
        (needQuizzes &&
            (catalog?.hasError == true || catalog?.value?.failed == true)) ||
        (live &&
            needPosts &&
            (posts!.hasError ||
                sync!.hasError ||
                checkpoint!.hasError ||
                needStatuses && (submissions!.hasError || grades!.hasError)));
    final loading =
        !failed &&
        ((needPosts && !postsReady) ||
            (needQuizzes && !quizzesReady) ||
            live &&
                needStatuses &&
                (submissions!.isLoading && !submissions.hasValue ||
                    grades!.isLoading && !grades.hasValue));
    final incomplete =
        live &&
        (needPosts && !confirmedLoad ||
            needQuizzes && catalog?.value?.loaded != true);
    final assignments =
        (live ? posts!.value ?? <ClassPost>[] : widget.previewPosts)
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
        !live ||
        confirmedLoad &&
            (submissions?.hasValue ?? false) &&
            (grades?.hasValue ?? false);
    AssignmentStatus? statusFor(ClassPost post) {
      final own = submissions?.value
          ?.where((s) => s.postId == post.id)
          .firstOrNull;
      final grade = grades?.value
          ?.where((g) => g.submissionId == own?.id)
          .firstOrNull;
      if (!statusKnown && own == null && grade == null) return null;
      return assignmentStatus(dueAt: post.dueAt, submission: own, grade: grade);
    }

    bool matches(ClassPost post) {
      if (!student || _filter == 'All') return true;
      final status = statusFor(post);
      return switch (_filter) {
        'Quizzes' => false,
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
    final visibleQuizzes = quizzes.where(
      (q) => switch (_filter) {
        'All' || 'Quizzes' => true,
        'To do' => q.session?.submitted != true,
        'Turned in' => q.session?.submitted == true,
        _ => false,
      },
    );
    final work =
        <({ClassPost? post, StudentQuiz? quiz})>[
          for (final post in visible) (post: post, quiz: null),
          for (final quiz in visibleQuizzes) (post: null, quiz: quiz),
        ]..sort(
          (a, b) => compareStudentWork(
            a.post?.dueAt ?? a.quiz?.closesAt,
            a.post == null ? 'quiz:${a.quiz!.id}' : 'post:${a.post!.id}',
            b.post?.dueAt ?? b.quiz?.closesAt,
            b.post == null ? 'quiz:${b.quiz!.id}' : 'post:${b.post!.id}',
          ),
        );
    final empty = assignments.isEmpty && quizzes.isEmpty;
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
              icon: FiloIcon(
                student ? FiloIcons.grades : FiloIcons.spreadsheet,
              ),
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
                  for (final filter in [
                    'All',
                    'To do',
                    'Turned in',
                    'Graded',
                    'Quizzes',
                  ])
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
                classworkLoadedProvider(
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
        if (incomplete && !loading && !failed && !empty) ...[
          const Text(
            'Some classwork is not saved on this device. Connect to the internet and refresh.',
          ),
          TextButton(onPressed: _refresh, child: const Text('Retry')),
        ],
        if (loading)
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: StreamPostSkeleton(),
            )
        else if (empty && !failed)
          if (confirmedLoad && (!needQuizzes || catalog?.value?.loaded == true))
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
        else if (work.isEmpty && !empty)
          Text(
            statusKnown
                ? 'No classwork matches this filter.'
                : 'Refresh to load your submission statuses.',
          )
        else
          for (final entry in work)
            if (entry.quiz != null)
              Padding(
                key: ValueKey('quiz:${entry.quiz!.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: StudentQuizRow(
                  key: ValueKey('quiz:${entry.quiz!.id}'),
                  quiz: entry.quiz!,
                  now: now,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudentQuizDetailScreen(
                        classId: id,
                        quizId: entry.quiz!.id,
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                key: ValueKey('post:${entry.post!.id}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: AssignmentRow(
                  post: entry.post!,
                  status: student ? statusFor(entry.post!) : null,
                  showStatus: student,
                  onTap: () {
                    if (live && !student) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SubmissionsScreen(
                            classId: id,
                            postId: entry.post!.id,
                          ),
                        ),
                      );
                    } else {
                      widget.onOpen(entry.post!);
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
      AssignmentStatus.assigned => FiloIcons.assessment,
      AssignmentStatus.draft => FiloIcons.edit,
      AssignmentStatus.turnedIn => FiloIcons.checkCircle,
      AssignmentStatus.late => FiloIcons.clock,
      AssignmentStatus.graded => FiloIcons.grades,
      AssignmentStatus.missing => FiloIcons.error,
      null => FiloIcons.sync,
    };
    return Chip(
      avatar: FiloIcon(
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
            const FiloIcon(
              FiloIcons.assessment,
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
            const FiloIcon(FiloIcons.chevronRight),
          ],
        ),
      ),
    ),
  );
}
