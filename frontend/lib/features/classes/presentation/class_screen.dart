import '../../tutorial/tutorial_host.dart';

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
import 'class_stream_assessments.dart';
import '../../assessments/application/instructor_quiz_providers.dart';
import '../../exams/application/exam_providers.dart';
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
  final _tourTargets = {
    for (final id in ['stream', 'classwork', 'files', 'menu']) id: GlobalKey(),
  };
  int _tutorialReplay = 0;
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
      ref.watch(
        classStreamRetryProvider((
          classId: widget.classId,
          student: widget.profile!.role == AccountRole.student,
        )),
      );
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
            child: EmptyState(
              title: 'Unable to open class',
              body: 'Refresh to check your access or return to your classes.',
              pose: 'confused',
              primaryAction: live
                  ? EmptyStateAction(
                      label: 'Refresh',
                      onPressed: () async {
                        await ref.read(classSyncProvider.notifier).refresh();
                        if (mounted) setState(() {});
                      },
                    )
                  : null,
              secondaryAction: EmptyStateAction(
                label: 'Back to classes',
                onPressed: () =>
                    live ? Navigator.pop(context) : context.go('/classes'),
              ),
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
    final classPosts = state.posts
        .where(
          (post) => post.classId == room.id && !_hiddenPosts.contains(post.id),
        )
        .toList();
    final streamAssessments = live && instructor
        ? ref
              .watch(
                assessmentStreamProvider((classId: room.id, student: false)),
              )
              .items
        : <StreamAssessment>[];
    final hasStreamContent = classStreamItems(
      classPosts,
      streamAssessments,
      room.id,
    ).isNotEmpty;
    final hasClassworkContent =
        classPosts.any((post) => post.postType == 'assignment') ||
        (live &&
            instructor &&
            (ref.watch(instructorQuizzesProvider(room.id)).value?.isNotEmpty ??
                false));
    final showClassAction =
        !live || (_tab == 0 ? hasStreamContent : hasClassworkContent);
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
                  : () => _createContent(room, post: _tab == 0),
            ),
          ),
        ),
      ),
    );
    return TutorialHost(
      key: ValueKey('class_tutorial_${widget.profile?.id}'),
      id: 'class_v1',
      enabled: live,
      replay: _tutorialReplay,
      targets: _tourTargets,
      onDestination: (index) => setState(() => _tab = index),
      steps: [
        const TutorialStep(
          'Inside your class',
          'Let me show you the main class sections. This tour only explains the controls.',
          'waving',
          destination: 0,
        ),
        const TutorialStep(
          'Class stream',
          'Read class updates and posts here. Next, we will open Classwork.',
          'cheerful',
          target: 'stream',
          destination: 0,
        ),
        TutorialStep(
          'Classwork',
          instructor
              ? 'Manage assignments, quizzes and exams here. Creating and publishing are separate actions you choose yourself.'
              : 'Find your assignments, quizzes and exams here. Open an activity to read its instructions before starting.',
          'thinking',
          target: 'classwork',
          destination: 1,
        ),
        const TutorialStep(
          'Class files',
          'Find materials shared in this class here. Internet access is needed for files that have not been downloaded.',
          'folder',
          target: 'files',
          destination: 2,
        ),
        TutorialStep(
          'Class options',
          instructor
              ? 'Open this menu for class details, students and join requests. Archived classes remain read-only.'
              : 'Open this menu for class details and your classmates. Archived classes remain read-only.',
          'curious',
          target: 'menu',
          destination: 0,
        ),
        const TutorialStep(
          'You are ready',
          'Explore at your own pace. You can replay this class tour from the class menu.',
          'cheerful_note',
        ),
      ],
      child: EntryBackground(
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
                  key: _tourTargets['menu'],
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
                  onPressed: () =>
                      ref.read(classSyncProvider.notifier).refresh(),
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
                        onCreate: () => _createContent(room, post: false),
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
                        onAddFiles: instructor && !room.archived
                            ? () => _createContent(room, post: true)
                            : null,
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
              if (instructor && _tab != 2 && showClassAction) classAction,
              FiloNavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                destinations: [
                  NavigationDestination(
                    key: _tourTargets['stream'],
                    icon: FiloIcon(FiloIcons.stream),
                    selectedIcon: FiloIcon(FiloIcons.streamSelected),
                    label: 'Stream',
                  ),
                  NavigationDestination(
                    key: _tourTargets['classwork'],
                    icon: const FiloIcon(FiloIcons.assessment),
                    selectedIcon: FiloIcon(FiloIcons.assessmentSelected),
                    label: 'Classwork',
                  ),
                  NavigationDestination(
                    key: _tourTargets['files'],
                    icon: const FiloIcon(FiloIcons.folder),
                    selectedIcon: FiloIcon(FiloIcons.folderSelected),
                    label: 'Files',
                  ),
                ],
              ),
            ],
          ),
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
            if (live)
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Replay class tutorial'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _tutorialReplay++);
                },
              ),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FiloSpacing.screen,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FiloSheetAction(
                      icon: FiloIcons.notifications,
                      label: 'Notification settings',
                      description: 'Choose updates for this class',
                      onTap: () {
                        Navigator.pop(sheet);
                        showFiloBottomSheet<void>(
                          context: context,
                          title: 'Notification settings',
                          scrollBody: false,
                          builder: (_) => NotificationSettingsScreen(
                            initialClassId: room.id,
                            embedded: true,
                          ),
                        );
                      },
                    ),
                    FiloSheetAction(
                      icon: FiloIcons.people,
                      label: instructor ? 'Students' : 'Classmates',
                      description: instructor && pendingCount > 0
                          ? '$pendingCount pending requests'
                          : null,
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
                    FiloSheetAction(
                      icon: instructor ? FiloIcons.settings : FiloIcons.enter,
                      label: instructor ? 'Class settings' : 'Leave class',
                      destructive: !instructor,
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
      builder: (sheet) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FiloSheetAction(
              icon: FiloIcons.addImage,
              label: 'Change banner',
              description: room.archived
                  ? 'Restore this class before changing its banner.'
                  : 'Choose a color or upload a photo',
              onTap: _busy || room.archived
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      showFiloBottomSheet<void>(
                        context: context,
                        title: 'Change banner',
                        scrollBody: false,
                        builder: (_) =>
                            ClassBannerScreen(classId: room.id, embedded: true),
                      );
                    },
            ),
            FiloSheetAction(
              icon: FiloIcons.archive,
              label: room.archived ? 'Restore class' : 'Archive class',
              description: room.archived
                  ? 'Reopen class activities'
                  : 'Keep the class as read-only',
              onTap: _busy
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      _classAction(room, archive: true);
                    },
            ),
            FiloSheetAction(
              icon: FiloIcons.delete,
              label: 'Delete class',
              destructive: true,
              description: 'Move this class to Recently deleted',
              onTap: _busy
                  ? null
                  : () {
                      Navigator.pop(sheet);
                      _deleteClass(room);
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
        builder: (dialog, update) => FiloModalDialog(
          title: 'Delete ${room.section}?',
          icon: FiloIcons.delete,
          destructive: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This class will be hidden from you and your students. You can restore it within 14 days. After that, the class, posts, submissions, quizzes, grades, and server files will be permanently deleted. Files already downloaded to devices will stay.',
              ),
              const SizedBox(height: FiloSpacing.s16),
              Text(
                'Type the section name exactly as shown to confirm: ${room.section}',
              ),
              const SizedBox(height: FiloSpacing.s8),
              TextField(
                controller: input,
                onChanged: (_) => update(() {}),
                decoration: InputDecoration(
                  labelText: 'Section name',
                  errorText: input.text.isNotEmpty && input.text != room.section
                      ? "The section name doesn't match. Type it exactly as shown."
                      : null,
                ),
              ),
            ],
          ),
          actions: [
            FiloButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(dialog, false),
            ),
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
      confirmDestructive: !archive,
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

  void _createContent(ClassRoom room, {required bool post}) {
    final live = widget.profile != null;
    if (room.archived ||
        (live && ref.read(connectivityProvider).asData?.value != true)) {
      return;
    }
    if (live) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => post
              ? CreatePostScreen(classId: room.id)
              : AssessmentFormScreen(classId: room.id),
        ),
      );
    } else {
      context.push(
        '/classes/${room.id}/${post ? 'post/new' : 'assessment/new'}',
      );
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
              final refreshes = <Future<void>>[
                ref.refresh(postSyncProvider(widget.classId).future),
              ];
              if (_tab == 0) {
                if (widget.profile?.role == AccountRole.instructor) {
                  refreshes.add(
                    ref.refresh(
                      instructorQuizListRefreshProvider(widget.classId).future,
                    ),
                  );
                } else {
                  ref.invalidate(studentQuizCatalogProvider);
                  refreshes.add(
                    ref.read(studentQuizCatalogProvider.future).then((_) {}),
                  );
                }
              }
              await Future.wait(refreshes);
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
    final live = widget.profile != null;
    final assessmentData = live
        ? ref.watch(
            assessmentStreamProvider((
              classId: room.id,
              student: state.role == PreviewRole.student,
            )),
          )
        : const AssessmentStreamData([], loaded: true);
    final allItems = classStreamItems(allPosts, assessmentData.items, room.id);
    final items = classStreamItems(
      allPosts,
      assessmentData.items,
      room.id,
      filter: _streamFilter,
    );
    final cached = live ? ref.watch(streamPostsProvider(room.id)) : null;
    final sync = live ? ref.watch(postSyncProvider(room.id)) : null;
    final confirmation = live && allPosts.isEmpty
        ? ref.watch(streamLoadedProvider(room.id))
        : null;
    final postsLoaded =
        confirmation?.asData?.value == true ||
        (live &&
            sync!.hasValue &&
            !sync.isLoading &&
            !sync.hasError &&
            ref.watch(connectivityProvider).asData?.value == true);
    final loaded = postsLoaded && assessmentData.loaded;
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
              'assessment': 'Assessments',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: FiloSpacing.s8),
                child: FiloAnimatedChip(
                  label: Text(filter.value),
                  selected: _streamFilter == filter.key,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: allItems.isEmpty
                      ? null
                      : (_) => setState(() => _streamFilter = filter.key),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: FiloSpacing.s16),
      if (allItems.isNotEmpty &&
          items.isEmpty &&
          assessmentData.loaded &&
          !assessmentData.loading &&
          !assessmentData.failed)
        EmptyState(
          title: 'No matching updates',
          body: 'Choose another category or show all updates.',
          primaryAction: EmptyStateAction(
            label: 'Show all updates',
            onPressed: () => setState(() => _streamFilter = null),
          ),
        ),
      if (live && ref.watch(connectivityProvider).asData?.value == false)
        const OfflineBanner(),
      if (live &&
          items.isEmpty &&
          !cached!.hasError &&
          !assessmentData.failed &&
          !sync!.hasError &&
          (!loaded || assessmentData.loading) &&
          (cached.isLoading ||
              sync.isLoading ||
              confirmation?.isLoading == true ||
              assessmentData.loading))
        const StreamPostSkeleton(),
      if (live &&
          allItems.isEmpty &&
          !online &&
          !loaded &&
          !cached!.isLoading &&
          !cached.hasError &&
          !assessmentData.failed &&
          !sync!.hasError)
        const EmptyState(
          title: 'No saved class updates',
          body: 'Connect and refresh to load class updates.',
          pose: 'sleepy',
        ),
      if (allItems.isEmpty &&
          (!live ||
              (loaded &&
                  cached!.hasValue &&
                  !cached.isLoading &&
                  !cached.hasError &&
                  !sync!.hasError &&
                  !assessmentData.failed)))
        EmptyState(
          title: live && !online
              ? 'No saved class updates'
              : 'No class updates yet',
          primaryAction: state.role == PreviewRole.instructor && !room.archived
              ? EmptyStateAction(
                  label: 'Create post',
                  onPressed: online
                      ? () => _createContent(room, post: true)
                      : null,
                )
              : null,
          body: live && !online
              ? 'Connect and refresh to load class updates.'
              : state.role == PreviewRole.instructor
              ? 'Share a post or publish an assessment for your class.'
              : 'Posts and published assessments will appear here.',
          pose: 'waiting',
        ),
    ];
    final itemIndices = {for (var i = 0; i < items.length; i++) items[i].id: i};
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
                final item = items[index];
                final post = item.post;
                if (post == null) {
                  return Padding(
                    key: ValueKey(item.id),
                    padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
                    child: StreamAssessmentCard(
                      assessment: item.assessment!,
                      archived: room.archived,
                      student: state.role == PreviewRole.student,
                    ),
                  );
                }
                return Padding(
                  key: ValueKey(item.id),
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
              childCount: items.length,
              findChildIndexCallback: (key) =>
                  key is ValueKey<String> ? itemIndices[key.value] : null,
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
