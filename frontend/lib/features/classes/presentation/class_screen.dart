import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../files/presentation/class_files.dart';
import '../application/preview_controller.dart';
import '../application/class_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../domain/prototype_models.dart';
import 'class_students_screen.dart';
import 'class_classmates_screen.dart';
import 'class_banner_screen.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/connectivity/connectivity_provider.dart';

class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key, required this.classId, this.profile});
  final AccountProfile? profile;
  final String classId;
  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  int _tab = 0;
  String _filter = 'All';
  String? _openedSection;
  bool _checkingAccess = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.profile != null;
    if (live) ref.watch(classSyncLifecycleProvider);
    final cards = live ? ref.watch(classCardsProvider) : null;
    if (live && cards!.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final state = !live
        ? ref.watch(previewProvider)
        : PreviewState(
            role: widget.profile!.role == AccountRole.instructor
                ? PreviewRole.instructor
                : PreviewRole.student,
            classes: cards!.asData?.value ?? [],
            posts: const [],
            assessments: const [],
          );
    final matches = state.classes.where(
      (room) => room.id == widget.classId && !room.pending,
    );
    if (matches.isEmpty) {
      if (live &&
          cards!.hasValue &&
          _openedSection != null &&
          !_checkingAccess &&
          !_busy) {
        _checkingAccess = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _accessLost());
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Class unavailable')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (live)
                TextButton(
                  onPressed: () async {
                    await ref.read(classSyncProvider.notifier).refresh();
                    if (mounted) setState(() {});
                  },
                  child: const Text('Refresh'),
                ),
              TextButton(
                onPressed: () =>
                    live ? Navigator.pop(context) : context.go('/classes'),
                child: const Text('Back to classes'),
              ),
            ],
          ),
        ),
      );
    }
    final room = matches.first;
    _openedSection = room.section;
    final instructor = state.role == PreviewRole.instructor;
    final pendingCount = live && instructor
        ? ref
                  .watch(pendingClassRequestsProvider)
                  .asData
                  ?.value[widget.classId] ??
              0
        : 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to classes',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => live ? Navigator.pop(context) : context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.section,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
            ),
            Text(
              room.course,
              style: const TextStyle(fontSize: 12, color: FiloColors.secondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (live && instructor && room.joinCode != null)
              Text(
                'Class code: ${room.joinCode}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Class menu',
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              backgroundColor: Colors.red,
              child: const Icon(Icons.more_horiz_rounded),
            ),
            onPressed: () => _menu(room, live, instructor, pendingCount),
          ),
        ],
      ),
      body: Column(
        children: [
          if (room.archived)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('This class is archived.'),
            ),
          if (live && ref.watch(classSyncProvider).hasError)
            TextButton(
              onPressed: () => ref.read(classSyncProvider.notifier).refresh(),
              child: const Text('Could not refresh. Retry'),
            ),
          Expanded(
            child: _refresh(
              IndexedStack(
                index: _tab,
                children: [
                  _stream(state, room),
                  ClassFiles(hasSamples: !live && room.id == 'it119'),
                  _classwork(state, room),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (instructor && _tab != 1)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: FiloButton(
                  label: _tab == 0 ? 'Create post' : 'New assessment',
                  icon: Icons.add_rounded,
                  onPressed: live || room.archived
                      ? null
                      : () => context.push(
                          '/classes/${room.id}/${_tab == 0 ? 'post/new' : 'assessment/new'}',
                        ),
                ),
              ),
            ),
          if (live && instructor && _tab != 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                room.archived
                    ? 'This class is archived and read-only.'
                    : 'Posting and assessments are not available yet.',
              ),
            ),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dynamic_feed_outlined),
                selectedIcon: Icon(Icons.dynamic_feed_rounded),
                label: 'Stream',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_rounded),
                label: 'Files',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_rounded),
                label: 'Classwork',
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _busy = false;

  void _menu(ClassRoom room, bool live, bool instructor, int pendingCount) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Class details'),
              onTap: () {
                Navigator.pop(sheet);
                _details(room, live, instructor);
              },
            ),
            if (live)
              ListTile(
                leading: Badge(
                  isLabelVisible: instructor && pendingCount > 0,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.people_outline),
                ),
                title: Text(instructor ? 'Students' : 'Classmates'),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => instructor
                          ? ClassStudentsScreen(classId: room.id)
                          : ClassClassmatesScreen(classId: room.id),
                    ),
                  );
                },
              ),
            if (live)
              ListTile(
                leading: Icon(
                  instructor ? Icons.settings_outlined : Icons.exit_to_app,
                ),
                title: Text(instructor ? 'Class settings' : 'Leave class'),
                onTap: _busy
                    ? null
                    : () {
                        Navigator.pop(sheet);
                        if (instructor) {
                          _settings(room);
                        } else {
                          _leave(room);
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  void _details(ClassRoom room, bool live, bool instructor) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Class details',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('${room.section}\n${room.course}\n${room.instructor}'),
              if (live) Text('School Year: ${room.schoolYear ?? ''}'),
              if (live && instructor) ...[
                Text('Class code: ${room.joinCode ?? ''}'),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy code'),
                  onPressed: room.joinCode == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: room.joinCode!),
                          );
                          if (sheet.mounted)
                            showMessage(sheet, 'Class code copied.');
                        },
                ),
              ],
              if (room.archived) const Text('Archived - read-only'),
            ],
          ),
        ),
      ),
    );
  }

  void _settings(ClassRoom room) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Class settings')),
            ListTile(
              title: const Text('Change banner'),
              subtitle: room.archived
                  ? const Text('Restore this class before changing its banner.')
                  : null,
              onTap: _busy || room.archived
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ClassBannerScreen(classId: room.id),
                        ),
                      );
                    },
            ),
            ListTile(
              title: const Text('Delete class'),
              onTap: _busy
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      _deleteClass(room);
                    },
            ),
            ListTile(
              title: Text(room.archived ? 'Restore class' : 'Archive class'),
              onTap: _busy
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      _classAction(room, archive: true);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accessLost() async {
    if (!mounted) return;
    try {
      if (widget.profile!.role == AccountRole.student) {
        final client = ref.read(supabaseClientProvider);
        final membership = await client
            .from('class_members')
            .select('status')
            .eq('class_id', widget.classId)
            .eq('student_id', client.auth.currentUser!.id)
            .maybeSingle();
        if (mounted && membership?['status'] == 'removed') {
          showMessage(context, 'You were removed from $_openedSection');
          Navigator.pop(context);
        }
      }
    } catch (_) {
      // A failed lookup is not evidence of removal. Retry after another refresh.
    } finally {
      if (mounted) _checkingAccess = false;
    }
  }

  Future<void> _deleteClass(ClassRoom room) async {
    if (_busy || ref.read(connectivityProvider).asData?.value != true) {
      showMessage(context, 'Connect to the internet to manage this class.');
      return;
    }
    final input = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text('Delete ${room.section}?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This class will be hidden from you and your students. You can restore it within 14 days. After that, the class, posts, submissions, quizzes, grades, and server files will be permanently deleted. Files already downloaded to devices will stay.',
                ),
                Text(
                  'Type the section name exactly as shown to confirm: ${room.section}',
                ),
                TextField(
                  controller: input,
                  onChanged: (_) => update(() {}),
                  decoration: InputDecoration(
                    labelText: 'Section name',
                    errorText:
                        input.text.isNotEmpty && input.text != room.section
                        ? "The section name doesn't match. Type it exactly as shown."
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: input.text == room.section
                  ? () => Navigator.pop(dialog, true)
                  : null,
              child: const Text('Delete class'),
            ),
          ],
        ),
      ),
    );
    // The dialog may still be animating out; dispose after its route transition.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (confirmed != true || !mounted || _busy) return;
    if (ref.read(connectivityProvider).asData?.value != true) {
      showMessage(context, 'Connect to the internet to manage this class.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      await repository.delete(room.id, room.section);
      if (mounted) {
        showMessage(
          context,
          'Class deleted. Restore it from Recently deleted within 14 days.',
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        showMessage(
          context,
          "We couldn't confirm the deletion. Refresh your classes before trying again.",
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(ClassRoom room) => _classAction(room);

  Future<void> _classAction(ClassRoom room, {bool archive = false}) async {
    if (_busy) return;
    if (ref.read(connectivityProvider).asData?.value != true) {
      showMessage(context, 'Connect to the internet to manage this class.');
      return;
    }
    final label = archive
        ? (room.archived ? 'Restore class' : 'Archive class')
        : 'Leave class';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          archive
              ? '${room.archived ? 'Restore' : 'Archive'} ${room.section}?'
              : 'Leave ${room.section}?',
        ),
        content: Text(
          archive
              ? (room.archived
                    ? 'Students will regain access to class activities.'
                    : 'Students will keep read-only access to materials and grades. No one can post, submit new work, or take quizzes. New join requests will be closed. You can restore this class later.')
              : 'You will lose access to this class. Your downloaded files will stay on your device. Your submissions and grades will stay with your instructor. To rejoin, you will need to send a new request for approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    if (ref.read(connectivityProvider).asData?.value != true) {
      showMessage(context, 'Connect to the internet to manage this class.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      if (archive) {
        if (room.archived) {
          await repository.restore(room.id);
        } else {
          await repository.archive(room.id);
        }
      } else {
        await repository.leave(room.id);
      }
      if (mounted) {
        showMessage(
          context,
          archive ? 'Class updated.' : 'You left the class.',
        );
        if (!archive) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        showMessage(
          context,
          "We couldn't confirm the change. Refresh the class before trying again.",
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _refresh(Widget child) => widget.profile == null
      ? child
      : RefreshIndicator(
          onRefresh: () => ref.read(classSyncProvider.notifier).refresh(),
          child: child,
        );

  Widget _stream(PreviewState state, ClassRoom room) {
    final posts = state.posts.where((post) => post.classId == room.id);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      key: PageStorageKey('stream-${room.id}'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Stream', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'What’s happening in your class.',
          style: TextStyle(color: FiloColors.secondary),
        ),
        const SizedBox(height: 24),
        if (posts.isEmpty)
          const EmptyState(
            title: 'Nothing posted yet.',
            message: 'New ideas and class updates will appear here.',
          ),
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FiloPanel(
              color: FiloColors.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(
                          post.assignment
                              ? Icons.assignment_outlined
                              : post.attachments.isNotEmpty
                              ? Icons.description_outlined
                              : Icons.campaign_outlined,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.instructor,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              post.assignment
                                  ? 'Assignment'
                                  : post.attachments.isNotEmpty
                                  ? 'Material'
                                  : 'Announcement',
                              style: const TextStyle(
                                color: FiloColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.message,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (post.assignment) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.schedule_rounded, size: 16),
                          label: Text(post.dueLabel ?? 'No due date'),
                        ),
                        Chip(label: Text('${post.points} points')),
                      ],
                    ),
                  ],
                  for (final attachment in post.attachments)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FiloPanel(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file_rounded, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachment,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _classwork(PreviewState state, ClassRoom room) {
    final assignments = state.posts.where(
      (post) => post.classId == room.id && post.assignment,
    );
    final assessments = state.assessments.where(
      (assessment) =>
          assessment.classId == room.id &&
          (!assessment.draft || state.role == PreviewRole.instructor),
    );
    final visibleAssignments = _filter == 'All' || _filter == 'Assignments';
    final visibleQuizzes = _filter == 'All' || _filter == 'Quizzes';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      key: PageStorageKey('classwork-${room.id}'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Classwork', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Make space for your next small win.',
          style: TextStyle(color: FiloColors.secondary),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          children: [
            for (final filter in ['All', 'Assignments', 'Quizzes'])
              ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if ((!visibleAssignments || assignments.isEmpty) &&
            (!visibleQuizzes || assessments.isEmpty))
          const EmptyState(
            title: 'No classwork yet.',
            message: 'Your next learning adventure will appear here.',
          ),
        if (visibleAssignments)
          for (final assignment in assignments)
            _workCard(
              title: assignment.title,
              label: assignment.dueLabel ?? 'No due date',
              details: '${assignment.points} points · Assignment',
              icon: Icons.assignment_outlined,
              onTap: () => _detail(assignment.title, assignment.message),
            ),
        if (visibleQuizzes)
          for (final assessment in assessments)
            _workCard(
              title: assessment.title,
              label: assessment.draft
                  ? 'Draft · instructor only'
                  : 'Published in preview',
              details:
                  '${assessment.questions.length} questions · ${assessment.points} points · ${assessment.minutes} min',
              icon: Icons.quiz_outlined,
              onTap: () => _detail(
                assessment.title,
                assessment.questions
                    .map((question) => question.prompt)
                    .join('\n\n'),
              ),
            ),
      ],
    );
  }

  Widget _workCard({
    required String title,
    required String label,
    required String details,
    required IconData icon,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
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
              Icon(icon, size: 28, color: FiloColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details,
                      style: const TextStyle(
                        color: FiloColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: FiloColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );

  void _detail(String title, String message) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(label: Text('Classwork preview')),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            FiloButton(
              label: 'Back to classwork',
              secondary: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
