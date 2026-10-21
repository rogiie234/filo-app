import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/domain/prototype_models.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../../classes/presentation/classwork_list.dart'
    show AssignmentRow, ClassworkFilterChip, classworkLoadedProvider;
import '../../grading/presentation/gradebook_screen.dart';
import '../../grading/presentation/submissions_screen.dart';
import '../../posts/application/post_providers.dart';
import '../../posts/presentation/stream_post_card.dart' show StreamPostSkeleton;
import '../application/instructor_quiz_providers.dart';
import '../domain/quiz_draft.dart';
import 'assessment_row.dart';
import 'assessment_form_screen.dart';

class InstructorClassworkList extends ConsumerStatefulWidget {
  const InstructorClassworkList({
    super.key,
    required this.classId,
    required this.archived,
    required this.active,
  });
  final String classId;
  final bool archived, active;
  @override
  ConsumerState<InstructorClassworkList> createState() =>
      _InstructorClassworkListState();
}

class _InstructorClassworkListState
    extends ConsumerState<InstructorClassworkList>
    with WidgetsBindingObserver {
  String _filter = 'All';
  final Set<String> _deleting = {};
  bool _opening = false;
  bool _refreshing = false;
  String? _refreshMessage;
  Future<void>? _pendingRefresh;
  Timer? _boundaryTimer;
  DateTime? _nextBoundary;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boundaryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _boundaryTimer?.cancel();
    _nextBoundary = null;
    if (mounted) setState(() {});
  }

  void _scheduleBoundary(List<InstructorQuizSummary> quizzes) {
    if (!widget.active ||
        !_foreground ||
        ModalRoute.isCurrentOf(context) == false) {
      _boundaryTimer?.cancel();
      _nextBoundary = null;
      return;
    }
    final now = DateTime.now().toUtc();
    final boundaries = [
      for (final q in quizzes.where((q) => q.status != 'draft')) ...[
        q.opensAt,
        q.closesAt,
      ],
    ].whereType<DateTime>().where((date) => date.isAfter(now)).toList()..sort();
    final next = boundaries.firstOrNull;
    if (next == _nextBoundary) return;
    _boundaryTimer?.cancel();
    _nextBoundary = next;
    if (next != null)
      _boundaryTimer = Timer(
        next.difference(now) + const Duration(milliseconds: 1),
        () {
          if (mounted) setState(() => _nextBoundary = null);
        },
      );
  }

  Future<void> _refresh() =>
      _pendingRefresh ??= _performRefresh().whenComplete(() {
        _pendingRefresh = null;
      });

  Future<void> _performRefresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _refreshMessage = null;
    });
    try {
      // Pull and Retry must have a path out of a stale offline signal.
      final online = await ref.read(connectivityMonitorProvider).recheck();
      if (!mounted) return;
      if (!online) {
        setState(
          () => _refreshMessage =
              "You're offline. Connect to the internet and retry.",
        );
        return;
      }
      final id = widget.classId;
      if (ref.read(streamPostsProvider(id)).hasError)
        ref.invalidate(streamPostsProvider(id));
      if (ref.read(instructorQuizzesProvider(id)).hasError)
        ref.invalidate(instructorQuizzesProvider(id));
      final checkpoint = classworkLoadedProvider(
        'instructor_classwork_posts:$id',
      );
      if (ref.read(checkpoint).hasError) ref.invalidate(checkpoint);
      await Future.wait([
        ref.refresh(instructorAssignmentsRefreshProvider(id).future),
        ref.refresh(instructorQuizListRefreshProvider(id).future),
      ]).timeout(const Duration(seconds: 30));
    } catch (_) {
      if (mounted)
        setState(
          () => _refreshMessage = 'Could not refresh classwork. Saved work is shown when available.',
        );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _open(InstructorQuizSummary quiz) async {
    if (_opening) return;
    _opening = true;
    try {
      if (quiz.status != 'draft' && !widget.archived) {
        final accepted = await showFiloConfirmation(
          context,
          title: 'Edit this published assessment?',
          message: 'Students can already see this assessment. Your saved changes will affect it. Once a student starts, only the title and closing time can change.',
          confirmLabel: 'Continue editing',
          cancelLabel: 'Cancel',
          icon: FiloIcons.edit,
        );
        if (!accepted || !mounted) return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AssessmentFormScreen(
            classId: widget.classId,
            quizId: quiz.id,
            readOnly: widget.archived,
          ),
        ),
      );
      if (mounted) await _refresh();
    } finally {
      _opening = false;
    }
  }

  Future<void> _delete(InstructorQuizSummary quiz) async {
    if (_deleting.contains(quiz.id) || widget.archived || quiz.locked) return;
    final draft = quiz.status == 'draft';
    final confirmed = await showFiloConfirmation(
      context,
      title: draft ? 'Delete this draft?' : 'Delete this assessment?',
      message: draft
          ? 'This draft will be removed from your assessment list. Students have not been able to see it.'
          : 'This assessment will no longer be available in the class. Students will no longer be able to open it or start an attempt.',
      confirmLabel: draft ? 'Delete draft' : 'Delete assessment',
      cancelLabel: 'Cancel',
      icon: FiloIcons.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting.add(quiz.id));
    try {
      final repository = await ref.read(
        instructorQuizRepositoryProvider.future,
      );
      if (repository == null)
        throw StateError('Sign in to manage assessments.');
      await repository.deleteQuiz(widget.classId, quiz.id);
      if (mounted)
        showMessage(context, draft ? 'Draft deleted.' : 'Assessment deleted.');
    } catch (error) {
      if (mounted)
        showMessage(
          context,
          'Could not delete this assessment. ${error.toString().replaceFirst('Bad state: ', '')}',
        );
    } finally {
      if (mounted) setState(() => _deleting.remove(quiz.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.classId;
    ref.listen(connectivityProvider, (previous, next) {
      if (next.asData?.value == true &&
          previous?.asData?.value != true &&
          _refreshMessage != null &&
          mounted) {
        setState(() => _refreshMessage = null);
      }
    });
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final posts = ref.watch(streamPostsProvider(id));
    final quizState = ref.watch(instructorQuizzesProvider(id));
    final current = ModalRoute.isCurrentOf(context) ?? true;
    final postSync = online && widget.active && _foreground && current
        ? ref.watch(instructorAssignmentsRefreshProvider(id))
        : null;
    final quizSync = online && widget.active && _foreground && current
        ? ref.watch(instructorQuizListRefreshProvider(id))
        : null;
    final checkpoint = ref.watch(
      classworkLoadedProvider('instructor_classwork_posts:$id'),
    );
    final assignments = (posts.asData?.value ?? <ClassPost>[])
        .where((p) => p.postType == 'assignment' && p.classId == id)
        .toList();
    final quizzes = quizState.asData?.value ?? <InstructorQuizSummary>[];
    _scheduleBoundary(quizzes);
    final needPosts = _filter == 'All' || _filter == 'Assignments';
    final needQuizzes = _filter != 'Assignments';
    final postsKnown =
        checkpoint.asData?.value == true || assignments.isNotEmpty;
    final quizzesKnown = quizState.asData?.value != null;
    final failed =
        (needPosts &&
            (posts.hasError ||
                checkpoint.hasError ||
                (online && (postSync?.hasError ?? false)))) ||
        (needQuizzes &&
            (quizState.hasError || (online && (quizSync?.hasError ?? false))));
    final loading =
        (needPosts &&
            (posts.isLoading ||
                (!postsKnown && online && (postSync?.isLoading ?? false)))) ||
        (needQuizzes &&
            (quizState.isLoading ||
                (!quizzesKnown && (quizSync?.isLoading ?? false))));
    final complete =
        (!needPosts || postsKnown) && (!needQuizzes || quizzesKnown);
    final entries =
        <
            ({
              ClassPost? post,
              InstructorQuizSummary? quiz,
              DateTime date,
              String key,
            })
          >[
            if (needPosts)
              for (final post in assignments)
                (
                  post: post,
                  quiz: null,
                  date:
                      post.createdAt?.toUtc() ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                  key: 'post:${post.id}',
                ),
            if (needQuizzes)
              for (final quiz in quizzes)
                if (_filter != 'Drafts' || quiz.status == 'draft')
                  (
                    post: null,
                    quiz: quiz,
                    date:
                        quiz.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                    key: 'quiz:${quiz.id}',
                  ),
          ]
          ..sort((a, b) {
            final date = b.date.compareTo(a.date);
            return date != 0 ? date : a.key.compareTo(b.key);
          });
    final indexForKey = {
      for (var i = 0; i < entries.length; i++) entries[i].key: i,
    };
    final filteredEmpty =
        _filter != 'All' && (assignments.isNotEmpty || quizzes.isNotEmpty);
    final now = DateTime.now().toUtc();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        key: PageStorageKey('instructor-classwork-$id'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Classwork',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Assignments, quizzes and exams. Newest first.',
                    style: TextStyle(color: FiloColors.secondary),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const FiloIcon(FiloIcons.spreadsheet),
                    label: const Text('Gradebook'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GradebookScreen(classId: id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!online) const OfflineBanner(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in [
                          'All',
                          'Assignments',
                          'Quizzes and exams',
                          'Drafts',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClassworkFilterChip(
                              label: filter,
                              selected: _filter == filter,
                              onSelected: () =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        semanticsLabel: 'Refreshing classwork',
                      ),
                    ),
                  if (failed || _refreshMessage != null)
                    Text(
                      _refreshMessage ?? 'Could not refresh classwork. Saved work is shown when available.',
                    ),
                  if (failed ||
                      _refreshMessage != null ||
                      !online ||
                      (!complete && !loading))
                    TextButton(
                      onPressed: _refreshing ? null : _refresh,
                      child: const Text('Retry'),
                    ),
                  if (!complete && !loading && !failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        online ? 'Refresh to load the remaining classwork.' : 'Some classwork is not saved on this device. Connect to the internet and refresh.',
                      ),
                    ),
                  if (entries.isEmpty && complete && !loading && !failed)
                    filteredEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No classwork matches this filter.'),
                          )
                        : EmptyState(
                            title: _filter == 'Assignments'
                                ? 'No assignments yet'
                                : _filter == 'All'
                                ? 'No classwork yet'
                                : 'No assessments yet',
                            message: widget.archived
                                ? 'This class is archived and read-only.'
                                : _filter == 'Assignments'
                                ? 'Assignments will appear here when you create them.'
                                : "Create a quiz or exam for your class. Save a draft or publish when you're ready.",
                          ),
                ],
              ),
            ),
          ),
          if (loading && entries.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList.builder(
                itemCount: 3,
                itemBuilder: (_, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: StreamPostSkeleton(),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList.builder(
              itemCount: entries.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                return indexForKey[key.value];
              },
              itemBuilder: (context, index) {
                final entry = entries[index];
                final quiz = entry.quiz;
                return Padding(
                  key: ValueKey(entry.key),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: quiz != null
                      ? AssessmentRow(
                          quiz: quiz,
                          now: now,
                          onOpen: () => _open(quiz),
                          busy: _deleting.contains(quiz.id),
                          onDelete: widget.archived || quiz.locked || !online
                              ? null
                              : () => _delete(quiz),
                        )
                      : AssignmentRow(
                          post: entry.post!,
                          status: null,
                          showStatus: false,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SubmissionsScreen(
                                classId: id,
                                postId: entry.post!.id,
                              ),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
