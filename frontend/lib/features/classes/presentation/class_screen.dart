import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../files/presentation/class_files.dart';
import '../application/preview_controller.dart';
import '../domain/prototype_models.dart';

class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  int _tab = 0;
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewProvider);
    final matches = state.classes.where(
      (room) => room.id == widget.classId && !room.pending,
    );
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class unavailable')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/classes'),
            child: const Text('Back to classes'),
          ),
        ),
      );
    }
    final room = matches.first;
    final instructor = state.role == PreviewRole.instructor;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to classes',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
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
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Class details',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${room.section}\n${room.course}\n${room.instructor}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      const Text('Preview classroom · sample data'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _stream(state, room),
          ClassFiles(hasSamples: room.id == 'it119'),
          _classwork(state, room),
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
                  onPressed: () => context.push(
                    '/classes/${room.id}/${_tab == 0 ? 'post/new' : 'assessment/new'}',
                  ),
                ),
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

  Widget _stream(PreviewState state, ClassRoom room) {
    final posts = state.posts.where((post) => post.classId == room.id);
    return ListView(
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
