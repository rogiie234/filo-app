import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../files/presentation/class_files.dart';
import '../application/preview_controller.dart';
import '../application/class_providers.dart';
import '../../posts/application/post_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../domain/prototype_models.dart';
import 'class_students_screen.dart';
import 'classwork_list.dart';
import '../../submissions/presentation/assignment_detail_screen.dart';
import 'classes_widgets.dart' show OfflineBanner;
import '../../posts/presentation/stream_post_card.dart';
import '../../posts/presentation/post_detail_screen.dart';
import '../../posts/presentation/create_post_screen.dart';
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
  String? _openedSection;
  bool _checkingAccess = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.profile != null;
    if (live) {
      ref.watch(classSyncLifecycleProvider);
      ref.watch(postSyncLifecycleProvider(widget.classId));
    }
    final cards = live ? ref.watch(classCardsProvider) : null;
    if (live && cards!.isLoading && !cards.hasValue && !cards.hasError) {
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
            posts:
                ref.watch(streamPostsProvider(widget.classId)).asData?.value ??
                const [],
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
          icon: const FiloIcon(FiloIcons.back),
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
              child: const FiloIcon(FiloIcons.more),
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
            child: IndexedStack(
              index: _tab,
              children: [
                _refresh(_stream(state, room)),
                ClassworkList(
                  classId: room.id,
                  instructor: instructor,
                  live: live,
                  previewPosts: state.posts,
                  onOpen: _openStreamPost,
                ),
                _refresh(
                  ClassFiles(
                    hasSamples: !live && room.id == 'it119',
                    classId: live ? room.id : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (instructor && _tab != 2)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: FiloButton(
                  label: _tab == 0 ? 'Create post' : 'New assessment',
                  icon: FiloIcons.add,
                  onPressed:
                      room.archived ||
                          (live &&
                              (_tab != 0 ||
                                  ref
                                          .watch(connectivityProvider)
                                          .asData
                                          ?.value !=
                                      true))
                      ? null
                      : () {
                          if (live && _tab == 0) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CreatePostScreen(classId: room.id),
                              ),
                            );
                          } else {
                            context.push(
                              '/classes/${room.id}/${_tab == 0 ? 'post/new' : 'assessment/new'}',
                            );
                          }
                        },
                ),
              ),
            ),
          if (live && instructor && _tab != 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                room.archived
                    ? 'This class is archived and read-only.'
                    : _tab == 0
                    ? (ref.watch(connectivityProvider).asData?.value == true
                          ? ''
                          : 'Connect to the internet to post or upload files.')
                    : 'Assessments are not available yet.',
              ),
            ),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(
                icon: FiloIcon(FiloIcons.stream),
                selectedIcon: FiloIcon(FiloIcons.streamSelected),
                label: 'Stream',
              ),
              NavigationDestination(
                icon: FiloIcon(FiloIcons.assessment),
                selectedIcon: FiloIcon(FiloIcons.assessmentSelected),
                label: 'Classwork',
              ),
              NavigationDestination(
                icon: FiloIcon(FiloIcons.folder),
                selectedIcon: FiloIcon(FiloIcons.folderSelected),
                label: 'Files',
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _busy = false;

  void _menu(ClassRoom room, bool live, bool instructor, int pendingCount) {
    showFiloBottomSheet<void>(
      title: 'Class options',
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FiloIcon(FiloIcons.info),
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
                  child: const FiloIcon(FiloIcons.people),
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
                leading: FiloIcon(
                  instructor ? FiloIcons.settings : FiloIcons.enter,
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
    showFiloBottomSheet<void>(
      title: 'Class details',
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${room.section}\n${room.course}\n${room.instructor}'),
              if (live) Text('School Year: ${room.schoolYear ?? ''}'),
              if (live && instructor) ...[
                Text('Class code: ${room.joinCode ?? ''}'),
                TextButton.icon(
                  icon: const FiloIcon(FiloIcons.copy),
                  label: const Text('Copy code'),
                  onPressed: room.joinCode == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: room.joinCode!),
                          );
                          if (sheet.mounted) {
                            showMessage(sheet, 'Class code copied.');
                          }
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
    showFiloBottomSheet<void>(
      title: 'Class settings',
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      if (mounted) {
        showMessage(
          context,
          "We couldn't confirm the deletion. Refresh your classes before trying again.",
        );
      }
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
      if (mounted) {
        showMessage(
          context,
          "We couldn't confirm the change. Refresh the class before trying again.",
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _refresh(Widget child) => widget.profile == null
      ? child
      : RefreshIndicator(
          onRefresh: () async {
            try {
              ref.invalidate(postSyncProvider(widget.classId));
              await ref.read(postSyncProvider(widget.classId).future);
            } catch (_) {
              /* Error and Retry are rendered above the cached posts. */
            }
          },
          child: child,
        );

  Widget _stream(PreviewState state, ClassRoom room) {
    final posts = state.posts.where((post) => post.classId == room.id).toList()
      ..sort((a, b) {
        final date = (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        );
        return date != 0 ? date : b.id.compareTo(a.id);
      });
    final live = widget.profile != null;
    final cached = live ? ref.watch(streamPostsProvider(room.id)) : null;
    final sync = live ? ref.watch(postSyncProvider(room.id)) : null;
    final online = ref.watch(connectivityProvider).asData?.value == true;
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
        if (live && ref.watch(connectivityProvider).asData?.value == false)
          const OfflineBanner(),
        if (live && (cached!.hasError || sync!.hasError))
          TextButton(
            onPressed: online
                ? () {
                    ref.invalidate(streamPostsProvider(room.id));
                    ref.invalidate(postSyncProvider(room.id));
                  }
                : null,
            child: const Text('Could not refresh posts. Retry'),
          ),
        if (live &&
            posts.isEmpty &&
            !cached!.hasError &&
            !sync!.hasError &&
            (cached.isLoading || sync.isLoading))
          const StreamPostSkeleton(),
        if (live && posts.isEmpty && !online)
          const Text('Connect to the internet to load posts for this class.'),
        if (live &&
            posts.isEmpty &&
            online &&
            cached!.hasValue &&
            !cached.hasError &&
            sync!.hasValue &&
            !sync.isLoading &&
            !sync.hasError)
          FiloPanel(
            color: FiloColors.tint,
            child: EmptyState(
              title: 'No posts yet',
              message: state.role == PreviewRole.instructor
                  ? 'Share an announcement, material, or assignment with your class.'
                  : 'Announcements, materials, and assignments from your instructor will appear here.',
            ),
          ),
        if (!live && posts.isEmpty)
          const EmptyState(
            title: 'Nothing posted yet.',
            message: 'New ideas and class updates will appear here.',
          ),
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: StreamPostCard(
              post: post,
              instructor: state.role == PreviewRole.instructor,
              onOpen: () => _openStreamPost(post),
              onEdit:
                  live &&
                      online &&
                      !room.archived &&
                      !_deletingPosts.contains(post.id)
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CreatePostScreen(classId: room.id, postId: post.id),
                      ),
                    )
                  : null,
              onDelete:
                  live &&
                      online &&
                      !room.archived &&
                      !_deletingPosts.contains(post.id)
                  ? () => _deleteStreamPost(post)
                  : null,
            ),
          ),
      ],
    );
  }

  final Set<String> _deletingPosts = {};

  Future<void> _deleteStreamPost(ClassPost post) async {
    if (!_deletingPosts.add(post.id)) return;
    setState(() {});
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete this post?'),
          content: const Text(
            'This post will no longer be available in the class. Its attached files will be removed from the server. Files already downloaded to phones will stay on those devices.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete post'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (ref.read(connectivityProvider).asData?.value != true) {
        throw StateError('offline');
      }
      final client = ref.read(supabaseClientProvider);
      final room = await client
          .from('classes')
          .select('owner_id,archived_at,deleted_at')
          .eq('id', post.classId)
          .single();
      if (room['owner_id'] != client.auth.currentUser?.id ||
          room['archived_at'] != null ||
          room['deleted_at'] != null) {
        throw StateError('read only');
      }
      // Remove server objects while the live parent still grants storage access.
      final files = await client
          .from('post_attachments')
          .select('storage_path')
          .eq('post_id', post.id);
      final paths = files
          .map((a) => a['storage_path'])
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        await client.storage.from('materials').remove(paths);
      }
      await client
          .from('posts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', post.id)
          .eq('class_id', post.classId)
          .select('id')
          .single();
      final repository = await ref.read(postRepositoryProvider.future);
      await repository?.sync(post.classId);
      ref.invalidate(postSyncProvider(post.classId));
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Could not confirm deletion. Refresh and try again.',
        );
      }
    } finally {
      _deletingPosts.remove(post.id);
      if (mounted) setState(() {});
    }
  }

  void _openStreamPost(ClassPost post) {
    if (widget.profile != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              widget.profile!.role == AccountRole.student &&
                  post.postType == 'assignment'
              ? AssignmentDetailScreen(classId: post.classId, postId: post.id)
              : PostDetailScreen(classId: post.classId, postId: post.id),
        ),
      );
      return;
    }
    showFiloBottomSheet<void>(
      title: 'Post details',
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(post.message),
              if (post.assignment) ...[
                const SizedBox(height: 16),
                Text(streamDueLabel(sheet, post)),
                if (post.points != null) Text('${post.points} points'),
              ],
              for (final name in post.attachments)
                ListTile(
                  leading: const FiloIcon(FiloIcons.attachment),
                  title: Text(name),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
