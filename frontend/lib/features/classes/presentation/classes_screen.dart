import '../../tutorial/tutorial_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../exams/presentation/exam_dev_screen.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/preview_controller.dart';
import '../application/class_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import 'class_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../grading/presentation/work_queue_screen.dart';
import '../../drive_backup/data/drive_backup_service.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../../notifications/application/notification_providers.dart';
import '../../files/presentation/my_files_screen.dart';
import '../../files/application/files_providers.dart';
import '../../study/presentation/study_home_screen.dart';
import '../../../core/sync/sync_providers.dart';
import 'classes_widgets.dart';
import '../../../core/widgets/entry_background.dart';
import 'create_class_screen.dart';
import 'recently_deleted_screen.dart';
import '../domain/prototype_models.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key, this.profile});
  final AccountProfile? profile;
  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  final _tourTargets = {
    for (final id in [
      'classes',
      'join_empty',
      'join_fab',
      'tasks',
      'files',
      'study',
      'account',
    ])
      id: GlobalKey(),
  };
  int _tutorialReplay = 0;
  final _search = TextEditingController();
  String _query = '';
  int _destination = 0;
  bool _libraryBusy = false;
  bool _libraryHasContent = false;
  final _libraryKey = GlobalKey<MyFilesScreenState>();

  void _onLibraryBusyChanged(bool busy) {
    if (mounted && _destination == 2) setState(() => _libraryBusy = busy);
  }

  void _onLibraryAddVisibilityChanged(bool visible) {
    if (mounted && _destination == 2 && _libraryHasContent != visible) {
      setState(() => _libraryHasContent = visible);
    }
  }

  @override
  void didUpdateWidget(covariant ClassesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id) {
      _libraryBusy = false;
      _libraryHasContent = false;
      _destination = 0;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewProvider);
    final live = widget.profile != null;
    final unread = live
        ? ref.watch(unreadNotificationCountProvider).asData?.value ?? 0
        : 0;
    if (live) {
      ref.watch(classSyncLifecycleProvider);
      ref.watch(driveBackupProvider);
      ref.watch(syncLifecycleProvider);
    }
    final cards = live
        ? ref.watch(classCardsProvider)
        : AsyncData(state.classes);
    final sync = live
        ? ref.watch(classSyncProvider)
        : const AsyncData<void>(null);
    final refreshStatus = live ? ref.watch(classRefreshStatusProvider) : null;
    final classRefreshFailed =
        refreshStatus?.hasError == true ||
        refreshStatus?.asData?.value == ClassRefreshStatus.failed;
    final student = live
        ? widget.profile!.role == AccountRole.student
        : state.role == PreviewRole.student;
    final online =
        !live || ref.watch(connectivityProvider).asData?.value == true;
    final savedRooms = cards.when<List<ClassRoom>?>(
      skipLoadingOnReload: true,
      skipError: true,
      data: (rooms) => rooms,
      loading: () => null,
      error: (_, _) => null,
    );
    final rooms = (savedRooms ?? <ClassRoom>[])
        .where(
          (room) => '${room.section} ${room.course} ${room.instructor}'
              .toLowerCase()
              .contains(_query.trim().toLowerCase()),
        )
        .toList();
    final entranceRooms = [
      ...rooms.where((r) => !r.archived),
      ...rooms.where((r) => r.archived),
    ];
    final loading =
        (cards.isLoading && !cards.hasValue) ||
        (live &&
            online &&
            !classRefreshFailed &&
            (sync.isLoading ||
                refreshStatus?.isLoading == true ||
                refreshStatus?.asData?.value == ClassRefreshStatus.loading) &&
            (cards.asData?.value.isEmpty ?? true));
    final library = live && _destination == 2;
    final fileRepository = library ? ref.watch(filesRepositoryProvider) : null;
    return TutorialHost(
      key: ValueKey('tutorial_${widget.profile?.id}'),
      id: 'main_v1',
      enabled: live,
      ready: !loading && !cards.hasError,
      replay: _tutorialReplay,
      targets: _tourTargets,
      onDestination: (index) => setState(() {
        _destination = index;
        _libraryBusy = false;
        _libraryHasContent = false;
      }),
      steps: [
        const TutorialStep(
          'Meet Filo',
          'Hi! Let me show you around. Next will open the main tabs for you. You can skip at any time.',
          'waving',
          destination: 0,
        ),
        const TutorialStep(
          'Your classes',
          'Your classes appear here. Open a class when you are ready to explore its updates and learning materials.',
          'cheerful',
          target: 'classes',
          destination: 0,
        ),
        TutorialStep(
          student ? 'Join a class' : 'Create a class',
          !online
              ? 'Connect to the internet to join or create a class. You can still explore your saved content.'
              : student
              ? 'Use this button to enter the code from your instructor and request to join. This tour will not send a request.'
              : 'Use this button to create a class. This tour will not create or publish anything.',
          'curious',
          target: online
              ? ((savedRooms?.isNotEmpty ?? false) ? 'join_fab' : 'join_empty')
              : null,
          destination: 0,
        ),
        TutorialStep(
          student ? 'Your to-do list' : 'Work to review',
          student
              ? 'Find class activities and work to turn in here. Next, we will open Files.'
              : 'Find student work that needs your attention here. Next, we will open Files.',
          'thinking',
          target: 'tasks',
          destination: 1,
        ),
        const TutorialStep(
          'Your files',
          'Keep your learning materials here. Downloads already saved on this device can be available offline.',
          'folder',
          target: 'files',
          destination: 2,
        ),
        if (student)
          const TutorialStep(
            'Study with your materials',
            'Open Study to explore the available study tools. Some tools need an internet connection.',
            'reading',
            target: 'study',
            destination: 3,
          ),
        const TutorialStep(
          'Ready to explore',
          'Open your account here for Settings and Replay tutorial. Back on Classes, choose a class for a short class tour.',
          'cheerful_note',
          target: 'account',
          destination: 0,
        ),
      ],
      child: FiloFirstListLoad(
        id: 'classes',
        hasItems: cards.asData?.value.isNotEmpty ?? false,
        ready: !loading && !cards.hasError,
        child: EntryBackground(
          verification: true,
          breeze: true,
          variation: 0,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              title: const Brand(),
              toolbarHeight: 76,
              actions: [
                if (live && student && examDevEnabled)
                  IconButton(
                    tooltip: 'DEV exam data',
                    icon: const Icon(Icons.science_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ExamDevScreen(),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Notifications',
                  icon: RedDotBadge(
                    visible: unread > 0,
                    child: Semantics(
                      label: unread > 0 ? '$unread unread notifications' : null,
                      child: const FiloIcon(FiloIcons.notifications),
                    ),
                  ),
                  onPressed: live
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                InboxScreen(userId: widget.profile!.id),
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: FiloSpacing.s16),
                  child: IconButton(
                    key: _tourTargets['account'],
                    tooltip: live ? 'Your account' : 'Change preview role',
                    onPressed: _roleMenu,
                    icon: FiloAvatar(
                      userId: widget.profile?.id,
                      name:
                          widget.profile?.name ??
                          (student ? 'Student' : 'Instructor'),
                      url: widget.profile?.photoUrl,
                      path: widget.profile?.avatarPath,
                    ),
                  ),
                ),
              ],
            ),
            body: live && student && _destination == 3
                ? const StudyHomeScreen(embedded: true)
                : live && _destination == 2
                ? MyFilesScreen(
                    key: _libraryKey,
                    embedded: true,
                    onBusyChanged: _onLibraryBusyChanged,
                    onAddActionVisibilityChanged:
                        _onLibraryAddVisibilityChanged,
                  )
                : live && _destination == 1
                ? WorkQueueScreen(student: student, embedded: true)
                : _refresh(
                    ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        FiloSpacing.screen,
                        FiloSpacing.s16,
                        FiloSpacing.screen,
                        112,
                      ),
                      children: [
                        if (live && !online) ...const [
                          OfflineBanner(),
                          SizedBox(height: FiloSpacing.s16),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your classes',
                                    key: _tourTargets['classes'],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium!
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: FiloSpacing.s8),
                                  Text(
                                    student ? 'A good place to grow.' : 'Manage your classes and keep learning moving.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (rooms.isNotEmpty || loading) ...[
                              const SizedBox(width: FiloSpacing.s16),
                              const Mascot(size: 72),
                            ],
                          ],
                        ),
                        const SizedBox(height: FiloSpacing.screen),
                        TextField(
                          controller: _search,
                          enabled:
                              (savedRooms?.isNotEmpty ?? false) ||
                              _query.isNotEmpty,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            hintText: 'Find a class',
                            labelText: 'Find a class',
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: const FiloIcon(FiloIcons.search),
                            prefixIconColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const FiloIcon(FiloIcons.close),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(FiloRadii.pill),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(FiloRadii.pill),
                              ),
                              borderSide: BorderSide(
                                color: FiloThemeTokens.of(context)
                                    .controlBorder,
                              ),
                            ),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: FiloSpacing.screen),
                        if (live && classRefreshFailed)
                          EmptyState(
                            title: 'Classes could not refresh',
                            body: 'Could not load the latest classes. Please try again.',
                            pose: 'confused',
                            showMascot: (cards.asData?.value.isEmpty ?? true),
                            action: TextButton(
                              onPressed: online && !sync.isLoading
                                  ? () => ref
                                        .read(classSyncProvider.notifier)
                                        .refresh()
                                  : null,
                              child: Text(
                                sync.isLoading ? 'Refreshing?' : 'Retry',
                              ),
                            ),
                          ),

                        if (cards.hasError)
                          const EmptyState(
                            title: 'Saved classes unavailable',
                            body: 'Reopen the app to retry reading your saved classes.',
                            pose: 'confused',
                          ),
                        if ((live && classRefreshFailed) || cards.hasError)
                          const SizedBox(height: FiloSpacing.s16),
                        if (rooms.isEmpty &&
                            !loading &&
                            !cards.hasError &&
                            !classRefreshFailed)
                          EmptyState(
                            pose: _query.trim().isNotEmpty
                                ? 'curious'
                                : !online
                                ? 'sleepy'
                                : 'waving',
                            title: _query.trim().isNotEmpty
                                ? 'No classes found.'
                                : !online
                                ? 'No saved classes found.'
                                : 'No classes yet.',
                            primaryAction: EmptyStateAction(
                              key: _query.trim().isEmpty && online
                                  ? _tourTargets['join_empty']
                                  : null,
                              label: _query.trim().isNotEmpty
                                  ? 'Clear search'
                                  : !online
                                  ? 'Refresh'
                                  : student
                                  ? 'Join class'
                                  : 'Create class',
                              onPressed: _query.trim().isNotEmpty
                                  ? () => setState(() {
                                      _search.clear();
                                      _query = '';
                                    })
                                  : !online
                                  ? null
                                  : student
                                  ? _join
                                  : live
                                  ? _create
                                  : () => context.push('/classes/it119'),
                            ),
                            message: _query.trim().isNotEmpty
                                ? 'No matches for "${_search.text.trim()}"; check the spelling or clear your search.'
                                : !online
                                ? 'Connect to the internet to refresh your classes.'
                                : student
                                ? 'Join a class using the code from your instructor.'
                                : 'Create your first class to get started.',
                          ),
                        if (loading)
                          for (
                            var index = 0;
                            index < (savedRooms?.length ?? 1);
                            index++
                          )
                            ClassCardSkeleton(compact: !student),
                        for (final room in rooms.where(
                          (room) => !room.archived,
                        ))
                          FiloListItem(
                            index: entranceRooms.indexOf(room),
                            child: _classTile(room),
                          ),
                        if (rooms.any((room) => room.archived)) ...[
                          Text(
                            'Archived',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: FiloSpacing.s16),
                          for (final room in rooms.where(
                            (room) => room.archived,
                          ))
                            FiloListItem(
                              index: entranceRooms.indexOf(room),
                              child: _classTile(room),
                            ),
                        ],
                        if (live && !student) ...[
                          const SizedBox(height: FiloSpacing.screen),
                          FiloPanel(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              leading: const FiloIcon(FiloIcons.delete),
                              title: const Text('Recently deleted'),
                              trailing: const FiloIcon(FiloIcons.chevronRight),
                              subtitle: const Text(
                                'Restore classes within 14 days',
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RecentlyDeletedScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton:
                (_destination == 0 && (savedRooms?.isNotEmpty ?? false)) ||
                    (library && _libraryHasContent)
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 72,
                      child: FiloButton(
                        key: _destination == 0
                            ? _tourTargets['join_fab']
                            : null,
                        label: library
                            ? 'Add files'
                            : student
                            ? 'Join class'
                            : 'Create class',
                        icon: FiloIcons.add,
                        iconOnly: true,
                        minHeight: 72,
                        busy: library && _libraryBusy,
                        onPressed: library
                            ? fileRepository?.asData?.value == null ||
                                      _libraryBusy
                                  ? null
                                  : () => _libraryKey.currentState?.addFiles()
                            : !online
                            ? null
                            : student
                            ? _join
                            : live
                            ? _create
                            : () => context.push('/classes/it119'),
                      ),
                    ),
                  )
                : null,
            bottomNavigationBar: FiloNavigationBar(
              selectedIndex: !student && _destination == 3 ? 0 : _destination,
              onDestinationSelected: (index) {
                if (live && (index <= 2 || (student && index == 3))) {
                  if (index == _destination) return;
                  setState(() {
                    _destination = index;
                    _libraryBusy = false;
                    _libraryHasContent = false;
                  });
                } else if (index != 0) {
                  showMessage(context, 'This area will be available soon.');
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: FiloIcon(FiloIcons.student),
                  selectedIcon: FiloIcon(FiloIcons.studentSelected),
                  label: 'Classes',
                ),
                NavigationDestination(
                  key: _tourTargets['tasks'],
                  icon: _ReviewBadge(live: live && !student, selected: false),
                  selectedIcon: _ReviewBadge(
                    live: live && !student,
                    selected: true,
                  ),
                  label: student ? 'To-do' : 'To review',
                ),
                NavigationDestination(
                  key: _tourTargets['files'],
                  icon: const FiloIcon(FiloIcons.folder),
                  selectedIcon: FiloIcon(FiloIcons.folderSelected),
                  label: 'Files',
                ),
                if (student)
                  NavigationDestination(
                    key: _tourTargets['study'],
                    icon: const FiloIcon(FiloIcons.sparkle),
                    selectedIcon: FiloIcon(FiloIcons.sparkleSelected),
                    label: 'AI Study',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _refresh(Widget child) => widget.profile == null
      ? child
      : RefreshIndicator(
          onRefresh: () => ref.read(classSyncProvider.notifier).refresh(),
          child: child,
        );

  Widget _classTile(ClassRoom room) => Padding(
    padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
    child: ClassCard(
      room: room,
      compact: widget.profile != null
          ? widget.profile!.role == AccountRole.instructor
          : ref.read(previewProvider).role == PreviewRole.instructor,
      pendingRequests: widget.profile?.role == AccountRole.instructor
          ? ref.watch(pendingClassRequestsProvider).asData?.value[room.id] ?? 0
          : 0,
      onTap: room.pending ? null : () => _openClass(room.id),
    ),
  );

  void _openClass(String id) {
    if (widget.profile == null) {
      context.push('/classes/$id');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClassScreen(classId: id, profile: widget.profile),
      ),
    );
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CreateClassScreen()),
    );
    if (!mounted) return;
    if (id != null) {
      _openClass(id);
    } else {
      await ref.read(classSyncProvider.notifier).refresh();
    }
  }

  Future<void> _roleMenu() async {
    if (widget.profile != null) {
      final replay = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(
            profile: widget.profile!,
            allowTutorialReplay: true,
          ),
        ),
      );
      if (mounted && replay == true)
        setState(() {
          _destination = 0;
          _tutorialReplay++;
        });
      return;
    }
    await showFiloBottomSheet<void>(
      title: 'Preview role',
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Student preview'),
              leading: const FiloIcon(FiloIcons.studentSelected),
              onTap: () {
                ref
                    .read(previewProvider.notifier)
                    .chooseRole(PreviewRole.student);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Instructor preview'),
              leading: const FiloIcon(FiloIcons.book),
              onTap: () {
                ref
                    .read(previewProvider.notifier)
                    .chooseRole(PreviewRole.instructor);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Back to welcome'),
              leading: const FiloIcon(FiloIcons.logout),
              onTap: () {
                Navigator.pop(context);
                this.context.go('/sign-in');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join() async {
    await showFiloBottomSheet<void>(
      title: 'Find your classroom.',
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _JoinSheet(
        preview: widget.profile == null,
        submit: (code) async {
          if (widget.profile == null) {
            return ref.read(previewProvider.notifier).joinClass(code);
          }
          final repository = await ref.read(classRepositoryProvider.future);
          if (repository == null) throw StateError('Sign in required');
          final result = await repository.requestJoin(code);
          return switch (result) {
            'requested' => 'Request sent. Your instructor needs to approve it before you can open the class.',
            'not_found' =>
              'Class code not found. Check the code and try again.',
            'already_member' => "You're already in this class.",
            'already_pending' => 'Your request is still waiting for approval.',
            'archived' =>
              'This class is archived and no longer accepts new students.',
            _ => throw StateError('Unknown join result'),
          };
        },
      ),
    );
  }
}

class _JoinSheet extends ConsumerStatefulWidget {
  const _JoinSheet({required this.submit, required this.preview});
  final Future<String> Function(String) submit;
  final bool preview;
  @override
  ConsumerState<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends ConsumerState<_JoinSheet> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: FiloSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.preview
                ? 'Enter the code from your instructor.\nPreview code: FILO26'
                : 'Enter the code from your instructor.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: FiloSpacing.screen),
          TextField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Class code',
              errorText: _error,
            ),
          ),
          const SizedBox(height: FiloSpacing.s16),
          if (!widget.preview &&
              ref.watch(connectivityProvider).asData?.value != true)
            const Padding(
              padding: EdgeInsets.only(bottom: FiloSpacing.s8),
              child: Text('Connect to the internet to join a class.'),
            ),
          FiloButton(
            label: _busy ? 'Sending\u2026' : 'Request to join',
            busy: _busy,
            icon: FiloIcons.forward,
            onPressed:
                _busy ||
                    (!widget.preview &&
                        ref.watch(connectivityProvider).asData?.value != true)
                ? null
                : _submit,
          ),
        ],
      ),
    ),
  );
  Future<void> _submit() async {
    if (_busy ||
        (!widget.preview &&
            ref.read(connectivityProvider).asData?.value != true)) {
      return;
    }
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-character class code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.submit(code);
      if (!mounted) return;
      if (result.startsWith('Class code not found')) {
        setState(() => _error = result);
        showMessage(context, result);
        return;
      }
      showMessage(context, result);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        const message =
            "We couldn't confirm your join request. Refresh your classes before trying again.";
        setState(() => _error = message);
        showMessage(context, message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ReviewBadge extends ConsumerWidget {
  const _ReviewBadge({required this.live, required this.selected});
  final bool live, selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = live ? ref.watch(reviewQueueCountProvider) : 0;
    return Badge(
      isLabelVisible: count > 0,
      label: Text(live ? '$count' : ''),
      child: FiloIcon(
        selected ? FiloIcons.checklistSelected : FiloIcons.checklist,
      ),
    );
  }
}
