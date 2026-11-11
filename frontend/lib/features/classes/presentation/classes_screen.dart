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
import 'classes_empty_state.dart';
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
  final _search = TextEditingController();
  String _query = '';
  int _destination = 0;
  bool _hasShownClasses = false;
  bool _libraryBusy = false;
  final _libraryKey = GlobalKey<MyFilesScreenState>();

  void _onLibraryBusyChanged(bool busy) {
    if (mounted && _destination == 2) setState(() => _libraryBusy = busy);
  }

  @override
  void didUpdateWidget(covariant ClassesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id) {
      _hasShownClasses = false;
      _libraryBusy = false;
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
        (!_hasShownClasses &&
            live &&
            online &&
            sync.isLoading &&
            (cards.asData?.value.isEmpty ?? true));
    if (!loading && !cards.hasError && !sync.hasError) _hasShownClasses = true;
    final library = live && _destination == 2;
    final fileRepository = library ? ref.watch(filesRepositoryProvider) : null;
    return FiloFirstListLoad(
      id: 'classes',
      hasItems: cards.asData?.value.isNotEmpty ?? false,
      ready: !loading && !cards.hasError,
      child: EntryBackground(
        verification: true,
        breeze: true,
        variation: 0,
        enabled: !student || _destination != 3,
        child: Scaffold(
          backgroundColor: student && _destination == 3
              ? Theme.of(context).scaffoldBackgroundColor
              : Colors.transparent,
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
              ? const StudyHomeScreen()
              : live && _destination == 2
              ? MyFilesScreen(
                  key: _libraryKey,
                  embedded: true,
                  onBusyChanged: _onLibraryBusyChanged,
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
                      24,
                    ),
                    children: [
                      if (live && !online) ...const [
                        OfflineBanner(),
                        SizedBox(height: FiloSpacing.s16),
                      ],
                      if (live && sync.hasError)
                        EmptyState(
                          title: 'Could not refresh your classes. Showing saved content.',
                          pose: 'confused',
                          showMascot: (cards.asData?.value.isEmpty ?? true),
                          bob: false,
                          action: TextButton(
                            onPressed: online
                                ? () => ref
                                      .read(classSyncProvider.notifier)
                                      .refresh()
                                : null,
                            child: const Text('Retry'),
                          ),
                        ),

                      if (cards.hasError)
                        const EmptyState(
                          title: 'Could not read saved classes. Try reopening the app.',
                          pose: 'confused',
                          bob: false,
                        ),
                      if ((live && sync.hasError) || cards.hasError)
                        const SizedBox(height: FiloSpacing.s16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your classes',
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
                                  style: Theme.of(context).textTheme.bodyLarge!
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
                              color: FiloThemeTokens.of(context).controlBorder,
                            ),
                          ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: FiloSpacing.screen),
                      if (live) _SyncErrorStatus(),
                      if (rooms.isEmpty &&
                          !loading &&
                          !cards.hasError &&
                          !sync.hasError)
                        ClassesEmptyState(
                          illustrated:
                              !student && online && _query.trim().isEmpty,
                          pose: _query.trim().isNotEmpty
                              ? 'curious'
                              : !online
                              ? 'sleepy'
                              : 'waving',
                          bob: online,
                          title: _query.trim().isNotEmpty
                              ? 'No classes found.'
                              : !online
                              ? 'No saved classes found.'
                              : 'No classes yet.',
                          message: _query.trim().isNotEmpty
                              ? 'Try another course, section, or instructor.'
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
                      for (final room in rooms.where((room) => !room.archived))
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
                        for (final room in rooms.where((room) => room.archived))
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
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_destination == 0 || library)
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 72,
                        child: FiloButton(
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
                    ),
                  ),
                ),
              FiloNavigationBar(
                selectedIndex: !student && _destination == 3 ? 0 : _destination,
                onDestinationSelected: (index) {
                  if (live && (index <= 2 || (student && index == 3))) {
                    if (index == _destination) return;
                    setState(() {
                      _destination = index;
                      _libraryBusy = false;
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
                    icon: _ReviewBadge(live: live && !student, selected: false),
                    selectedIcon: _ReviewBadge(
                      live: live && !student,
                      selected: true,
                    ),
                    label: student ? 'To-do' : 'To review',
                  ),
                  const NavigationDestination(
                    icon: FiloIcon(FiloIcons.folder),
                    selectedIcon: FiloIcon(FiloIcons.folderSelected),
                    label: 'Files',
                  ),
                  if (student)
                    const NavigationDestination(
                      icon: FiloIcon(FiloIcons.sparkle),
                      selectedIcon: FiloIcon(FiloIcons.sparkleSelected),
                      label: 'AI Study',
                    ),
                ],
              ),
            ],
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(profile: widget.profile!),
        ),
      );
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
      title: null,
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
          Semantics(
            header: true,
            child: Text(
              'Find your classroom.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: FiloSpacing.s8),
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

class _SyncErrorStatus extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final sync = ref.watch(syncCoordinatorProvider).asData?.value;
    if (sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        // Routine timestamps/sync activity stay out of the navigation area.
        if (sync.errors.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: FiloSpacing.s16),
          child: Semantics(
            liveRegion: true,
            child: FiloPanel(
              padding: const EdgeInsets.symmetric(
                horizontal: FiloSpacing.s16,
                vertical: FiloSpacing.s8,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: FiloIcon(
                      FiloIcons.info,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: FiloSpacing.s8),
                  Expanded(
                    child: Text(
                      !online
                          ? "You're offline. Some changes haven't synced."
                          : 'Some changes could not sync.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: sync.syncing || !online
                        ? null
                        : () => sync.run(retryFailed: true),
                    child: const Text('Retry sync'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
