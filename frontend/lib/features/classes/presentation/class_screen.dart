import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/filo_widgets.dart';
import '../../files/presentation/class_files.dart';
import '../application/preview_controller.dart';
import '../application/class_providers.dart';
import '../../posts/application/post_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../domain/prototype_models.dart';
import 'class_students_screen.dart';
import 'classwork_list.dart';
import '../../assessments/presentation/instructor_classwork_list.dart';
import '../../assessments/presentation/assessment_form_screen.dart';
import '../../submissions/presentation/assignment_detail_screen.dart';
import 'classes_widgets.dart' show OfflineBanner, classImageProvider;
import 'class_banner.dart';
import '../domain/class_banner.dart';
import '../../posts/presentation/stream_post_card.dart';
import '../../posts/presentation/post_detail_screen.dart';
import '../../posts/presentation/create_post_screen.dart';
import 'class_classmates_screen.dart';
import 'class_banner_screen.dart';
import '../../../core/widgets/entry_background.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../notifications/presentation/notification_settings_screen.dart';

class ClassScreen extends ConsumerStatefulWidget {
  const ClassScreen({super.key, required this.classId, this.profile});
  final AccountProfile? profile;
  final String classId;
  @override
  ConsumerState<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends ConsumerState<ClassScreen> {
  int _tab = 0;
  String? _streamFilter;
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
        body: ListView(
          padding: const EdgeInsets.all(FiloSpacing.screen),
          children: const [StreamPostSkeleton()],
        ),
      );
    }
    final state = !live
        ? ref.watch(previewProvider)
        : PreviewState(
            role: widget.profile!.role == AccountRole.instructor
                ? PreviewRole.instructor
                : PreviewRole.student,
            classes: cards!.value ?? [],
            posts:
                ref.watch(streamPostsProvider(widget.classId)).value ??
                const [],
            assessments: const [],
          );
    final matches = state.classes.where(
      (room) => room.id == widget.classId && !room.pending,
    );
    if (matches.isEmpty) {
      if (live &&
          cards!.hasValue &&
          !cards.isLoading &&
          !cards.hasError &&
          _openedSection != null &&
          !_checkingAccess &&
          !_busy) {
        _checkingAccess = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _accessLost());
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Class unavailable')),
        body: Center(
          child: SingleChildScrollView(
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
    final classAction = SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 72,
            child: FiloButton(
              label: _tab == 0 ? 'Create post' : 'New assessment',
              iconOnly: true,
              minHeight: 72,
              icon: FiloIcons.add,
              onPressed:
                  room.archived ||
                      (live &&
                          (ref.watch(connectivityProvider).asData?.value !=
                              true))
                  ? null
                  : () {
                      if (live && _tab == 0) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CreatePostScreen(classId: room.id),
                          ),
                        );
                      } else if (live) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AssessmentFormScreen(classId: room.id),
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
      ),
    );
    return EntryBackground(
      verification: true,
      breeze: true,
      variation: 1,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight:
              64.0 +
              (MediaQuery.textScalerOf(context).scale(20) - 20).clamp(
                0,
                double.infinity,
              ),
          titleSpacing: FiloSpacing.s8,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Back to classes',
            icon: const FiloIcon(FiloIcons.back),
            onPressed: () => live ? Navigator.pop(context) : context.pop(),
          ),
          title: Text(
            const ['Stream', 'Classwork', 'Class files'][_tab],
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 24),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: FiloSpacing.s12),
              child: IconButton.filledTonal(
                tooltip: 'Class menu',
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                ),
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  child: const FiloIcon(FiloIcons.moreVertical),
                ),
                onPressed: () => _menu(room, live, instructor, pendingCount),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (room.archived)
              const Padding(
                padding: EdgeInsets.all(FiloSpacing.s12),
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
                  if (live && instructor)
                    InstructorClassworkList(
                      classId: room.id,
                      showHeading: false,
                      archived: room.archived,
                      active: _tab == 1,
                    )
                  else
                    ClassworkList(
                      classId: room.id,
                      showHeading: false,
                      instructor: instructor,
                      live: live,
                      previewPosts: state.posts,
                      onOpen: _openStreamPost,
                    ),
                  _refresh(
                    ClassFiles(
                      showHeading: false,
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
            if (live &&
                instructor &&
                _tab != 2 &&
                (room.archived ||
                    ref.watch(connectivityProvider).asData?.value != true))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FiloSpacing.screen,
                ),
                child: Text(
                  room.archived
                      ? 'This class is archived and read-only.'
                      : _tab == 0
                      ? (ref.watch(connectivityProvider).asData?.value == true
                            ? ''
                            : 'Connect to the internet to post or upload files.')
                      : (ref.watch(connectivityProvider).asData?.value == true
                            ? ''
                            : 'Connect to the internet to create an assessment.'),
                ),
              ),
            if (instructor && _tab != 2) classAction,
            FiloNavigationBar(
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
      ),
    );
  }

  bool _busy = false;

  void _menu(ClassRoom room, bool live, bool instructor, int pendingCount) {
    var copyingCode = false;
    showFiloBottomSheet<void>(
      title: 'Class options',
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FiloSpacing.screen,
              ),
              child: FiloPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FiloRadii.medium),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final path = room.bannerPath;
                          final hasImage = path != null && path.isNotEmpty;
                          final url = hasImage
                              ? ref
                                    .watch(
                                      classImageProvider(('banners', path)),
                                    )
                                    .asData
                                    ?.value
                              : null;
                          return ClassBanner(
                            section: room.section,
                            instructor: room.instructor,
                            compact: true,
                            color: hasImage
                                ? classBannerColor(null)
                                : room.color,
                            image: url == null ? null : NetworkImage(url),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: FiloSpacing.s12),
                    Text(
                      room.course,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: FiloSpacing.s8),
                    if (room.schoolYear?.isNotEmpty == true)
                      Text('School year: ${room.schoolYear}'),
                    if (room.archived) const Text('Archived - read-only'),
                    if (live &&
                        instructor &&
                        room.joinCode?.isNotEmpty == true) ...[
                      const SizedBox(height: FiloSpacing.s12),
                      SelectableText(
                        'Class code: ${room.joinCode}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: FiloSpacing.s12,
                        runSpacing: FiloSpacing.s8,
                        children: [
                          TextButton.icon(
                            icon: const FiloIcon(FiloIcons.copy, size: 20),
                            label: const Text('Copy code'),
                            onPressed: () async {
                              if (copyingCode) return;
                              copyingCode = true;
                              var message = 'Class code copied.';
                              try {
                                await Clipboard.setData(
                                  ClipboardData(text: room.joinCode!),
                                );
                              } catch (_) {
                                message =
                                    'Could not copy the class code. Try again.';
                              }
                              copyingCode = false;
                              if (sheet.mounted) showMessage(sheet, message);
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.share_outlined, size: 20),
                            label: const Text('Share class'),
                            onPressed: room.archived
                                ? null
                                : () => _shareClass(sheet, room),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: FiloSpacing.s12),
            if (live)
              ListTile(
                leading: const FiloIcon(FiloIcons.notifications),
                title: const Text('Notification settings'),
                trailing: const FiloIcon(FiloIcons.chevronRight),
                onTap: () {
                  Navigator.pop(sheet);
                  showFiloBottomSheet<void>(
                    context: context,
                    title: 'Notification settings',
                    scrollBody: false,
                    builder: (context) => SizedBox(
                      height: MediaQuery.sizeOf(context).height * .78,
                      child: NotificationSettingsScreen(
                        initialClassId: room.id,
                        embedded: true,
                      ),
                    ),
                  );
                },
              ),
            if (live)
              ListTile(
                leading: Badge(
                  isLabelVisible: instructor && pendingCount > 0,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  child: const FiloIcon(FiloIcons.people),
                ),
                title: Text(instructor ? 'Students' : 'Classmates'),
                subtitle: instructor && pendingCount > 0
                    ? Text('$pendingCount pending requests')
                    : null,
                trailing: const FiloIcon(FiloIcons.chevronRight),
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
                trailing: const FiloIcon(FiloIcons.chevronRight),
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

  bool _sharingCode = false;

  Future<void> _shareClass(BuildContext sheet, ClassRoom room) async {
    if (_sharingCode ||
        room.archived ||
        room.joinCode?.isNotEmpty != true ||
        widget.profile?.role != AccountRole.instructor) {
      return;
    }
    _sharingCode = true;
    try {
      final box = sheet.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Join ${room.section} on Filo',
          text:
              'Join my class on Filo!\n\nCourse: ${room.course}\nSection: ${room.section}\nClass code: ${room.joinCode}\n\nOpen Filo, tap Join class, and enter the code and section exactly as shown. Your request will need instructor approval.',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (sheet.mounted) {
        showMessage(sheet, 'Could not open sharing. Try again.');
      }
    } finally {
      _sharingCode = false;
    }
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
              leading: const FiloIcon(FiloIcons.addImage),
              trailing: const FiloIcon(FiloIcons.chevronRight),
              title: const Text('Change banner'),
              subtitle: room.archived
                  ? const Text('Restore this class before changing its banner.')
                  : null,
              onTap: _busy || room.archived
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      showFiloBottomSheet<void>(
                        context: context,
                        title: 'Change banner',
                        scrollBody: false,
                        builder: (context) => SizedBox(
                          height: MediaQuery.sizeOf(context).height * .78,
                          child: ClassBannerScreen(
                            classId: room.id,
                            embedded: true,
                          ),
                        ),
                      );
                    },
            ),
            ListTile(
              leading: FiloIcon(
                FiloIcons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete class',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Move this class to Recently deleted'),
              onTap: _busy
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      _deleteClass(room);
                    },
            ),
            ListTile(
              leading: const FiloIcon(FiloIcons.archive),
              title: Text(room.archived ? 'Restore class' : 'Archive class'),
              subtitle: Text(
                room.archived
                    ? 'Reopen class activities'
                    : 'Keep the class as read-only',
              ),
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
    final confirmed = await showFiloDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          icon: FiloIcon(
            FiloIcons.delete,
            size: 32,
            color: Theme.of(context).colorScheme.error,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FiloRadii.large),
          ),
          title: Text('Delete ${room.section}?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This class will be hidden from you and your students. You can restore it within 14 days. After that, the class, posts, submissions, quizzes, grades, and server files will be permanently deleted. Files already downloaded to devices will stay.',
                ),
                const SizedBox(height: FiloSpacing.s16),
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
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FiloButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(dialog, false),
                  ),
                  const SizedBox(height: FiloSpacing.s8),
                  FiloButton(
                    label: 'Delete class',
                    outlined: true,
                    destructive: true,
                    onPressed: input.text == room.section
                        ? () => Navigator.pop(dialog, true)
                        : null,
                  ),
                ],
              ),
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
    final confirmed = await showFiloConfirmation(
      context,
      title: archive
          ? '${room.archived ? 'Restore' : 'Archive'} ${room.section}?'
          : 'Leave ${room.section}?',
      message: archive
          ? (room.archived
                ? 'Students will regain access to class activities.'
                : 'Students will keep read-only access to materials and grades. No one can post, submit new work, or take quizzes. New join requests will be closed. You can restore this class later.')
          : 'You will lose access to this class. Your downloaded files will stay on your device. Your submissions and grades will stay with your instructor. To rejoin, you will need to send a new request for approval.',
      confirmLabel: label,
      cancelLabel: 'Cancel',
      icon: archive ? FiloIcons.archive : FiloIcons.enter,
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
              final online = await ref
                  .read(connectivityMonitorProvider)
                  .recheck();
              if (!mounted || !online) return;
              ref.invalidate(postSyncProvider(widget.classId));
              await ref.read(postSyncProvider(widget.classId).future);
            } catch (_) {
              /* Error and Retry are rendered above the cached posts. */
            }
          },
          child: child,
        );

  Widget _stream(PreviewState state, ClassRoom room) {
    final allPosts =
        state.posts
            .where(
              (post) =>
                  post.classId == room.id && !_hiddenPosts.contains(post.id),
            )
            .toList()
          ..sort((a, b) {
            final date = (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            );
            return date != 0 ? date : b.id.compareTo(a.id);
          });
    final posts = allPosts
        .where(
          (post) => _streamFilter == null || post.postType == _streamFilter,
        )
        .toList();
    final live = widget.profile != null;
    final cached = live ? ref.watch(streamPostsProvider(room.id)) : null;
    final sync = live ? ref.watch(postSyncProvider(room.id)) : null;
    final confirmation = live && allPosts.isEmpty
        ? ref.watch(streamLoadedProvider(room.id))
        : null;
    final loaded =
        confirmation?.asData?.value == true ||
        (live &&
            sync!.hasValue &&
            !sync.isLoading &&
            !sync.hasError &&
            ref.watch(connectivityProvider).asData?.value == true);
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final bannerPath = room.bannerPath;
    final hasBanner = bannerPath != null && bannerPath.isNotEmpty;
    final bannerUrl = live && hasBanner
        ? ref.watch(classImageProvider(('banners', bannerPath))).asData?.value
        : null;
    final headers = <Widget>[
      Text(
        'What’s happening in your class.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: FiloSpacing.s16),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FiloRadii.large),
        ),
        child: ClassBanner(
          course: room.course,
          section: room.section,
          instructor: room.instructor,
          compact: true,
          color: hasBanner ? classBannerColor(null) : room.color,
          image: bannerUrl == null ? null : NetworkImage(bannerUrl),
        ),
      ),
      const SizedBox(height: FiloSpacing.screen),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in <String?, String>{
              null: 'All',
              'announcement': 'Announcements',
              'material': 'Materials',
              'assignment': 'Assignments',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: FiloSpacing.s8),
                child: FiloAnimatedChip(
                  label: Text(filter.value),
                  selected: _streamFilter == filter.key,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _streamFilter = filter.key),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: FiloSpacing.s16),
      if (allPosts.isNotEmpty && posts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s16),
          child: Column(
            children: [
              Text(
                online
                    ? 'No posts match this filter.'
                    : 'No saved posts match this filter.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => setState(() => _streamFilter = null),
                child: const Text('Show all posts'),
              ),
            ],
          ),
        ),
      if (live && ref.watch(connectivityProvider).asData?.value == false)
        const OfflineBanner(),
      if (live &&
          (cached!.hasError ||
              sync!.hasError ||
              confirmation?.hasError == true))
        EmptyState(
          title: 'Could not refresh posts. Retry',
          pose: 'confused',
          showMascot: allPosts.isEmpty,
          bob: false,
          action: TextButton(
            onPressed: online
                ? () {
                    if (cached.hasError) {
                      ref.invalidate(streamPostsProvider(room.id));
                    }
                    if (confirmation?.hasError == true) {
                      ref.invalidate(streamLoadedProvider(room.id));
                    }
                    ref.invalidate(postSyncProvider(room.id));
                  }
                : null,
            child: const Text('Retry'),
          ),
        ),
      if (live &&
          allPosts.isEmpty &&
          !cached!.hasError &&
          !sync!.hasError &&
          !loaded &&
          (cached.isLoading ||
              sync.isLoading ||
              confirmation?.isLoading == true))
        const StreamPostSkeleton(),
      if (live &&
          allPosts.isEmpty &&
          !online &&
          !loaded &&
          !cached!.isLoading &&
          !cached.hasError &&
          !sync!.hasError)
        const EmptyState(
          title: 'Connect to the internet to load posts for this class.',
          pose: 'sleepy',
          bob: false,
        ),
      if (allPosts.isEmpty &&
          (!live ||
              (loaded &&
                  cached!.hasValue &&
                  !cached.isLoading &&
                  !cached.hasError &&
                  !sync!.hasError)))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s16),
          child: Column(
            children: [
              ExcludeSemantics(
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      12,
                      -2700,
                    ]),
                    child: Image.asset(
                      'assets/illustrations/stream-empty.png',
                      fit: BoxFit.contain,
                      cacheWidth: (360 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.campaign_outlined, size: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FiloSpacing.s16),
              Text(
                'No posts yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: FiloSpacing.s8),
              Text(
                state.role == PreviewRole.instructor
                    ? 'Share an announcement, material, or assignment with your class.'
                    : 'Announcements, materials, and assignments from your instructor will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
    ];
    final postIndices = {for (var i = 0; i < posts.length; i++) posts[i].id: i};
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      key: PageStorageKey('stream-${room.id}'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            FiloSpacing.screen,
            FiloSpacing.screen,
            FiloSpacing.screen,
            0,
          ),
          sliver: SliverList(delegate: SliverChildListDelegate(headers)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            FiloSpacing.screen,
            0,
            FiloSpacing.screen,
            FiloSpacing.screen,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = posts[index];
                return Padding(
                  key: ValueKey(post.id),
                  padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
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
                              builder: (_) => CreatePostScreen(
                                classId: room.id,
                                postId: post.id,
                              ),
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
                );
              },
              childCount: posts.length,
              findChildIndexCallback: (key) =>
                  key is ValueKey<String> ? postIndices[key.value] : null,
            ),
          ),
        ),
      ],
    );
  }

  final Set<String> _deletingPosts = {};
  final Set<String> _hiddenPosts = {};

  Future<void> _deleteStreamPost(ClassPost post) async {
    if (!_deletingPosts.add(post.id)) return;
    setState(() {});
    var deleted = false;
    try {
      final confirmed = await showFiloConfirmation(
        context,
        title: 'Delete this post?',
        message: 'This post will no longer be available in the class. Its attached files will be removed from the server. Files already downloaded to phones will stay on those devices.',
        confirmLabel: 'Delete post',
        cancelLabel: 'Cancel',
        confirmDestructive: true,
        icon: FiloIcons.delete,
      );
      if (confirmed != true || !mounted) return;
      if (ref.read(connectivityProvider).asData?.value != true) {
        throw StateError('offline');
      }
      setState(() => _hiddenPosts.add(post.id));
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
      deleted = true;
      final repository = await ref.read(postRepositoryProvider.future);
      await repository?.markDeleted(post.classId, post.id);
      await repository?.sync(post.classId);
      ref.invalidate(postSyncProvider(post.classId));
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          deleted
              ? 'Post deleted. Could not refresh the Stream. Refresh to retry.'
              : 'Could not confirm deletion. Refresh and try again.',
        );
      }
    } finally {
      if (!deleted) _hiddenPosts.remove(post.id);
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
          padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: FiloSpacing.s16),
              Text(post.message),
              if (post.assignment) ...[
                const SizedBox(height: FiloSpacing.s16),
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
