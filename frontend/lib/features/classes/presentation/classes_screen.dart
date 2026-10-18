import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/preview_controller.dart';
import '../application/class_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import 'class_screen.dart';
import '../../grading/presentation/work_queue_screen.dart';
import '../../drive_backup/data/drive_backup_service.dart';
import '../../drive_backup/presentation/drive_backup_screen.dart';
import 'classes_widgets.dart';
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
  String _query = '';
  int _destination = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewProvider);
    final live = widget.profile != null;
    if (live) {
      ref.watch(classSyncLifecycleProvider);
      ref.watch(driveBackupProvider);
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
    final rooms = (cards.asData?.value ?? <ClassRoom>[])
        .where(
          (room) => '${room.section} ${room.course} ${room.instructor}'
              .toLowerCase()
              .contains(_query.trim().toLowerCase()),
        )
        .toList();
    final loading =
        cards.isLoading ||
        (live &&
            online &&
            sync.isLoading &&
            (cards.asData?.value.isEmpty ?? true));
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Brand(),
        toolbarHeight: 76,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const RedDotBadge(
              visible: false,
              child: Icon(Icons.notifications_none_rounded),
            ),
            onPressed: () =>
                showMessage(context, 'Notifications will be available here.'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: live ? 'Your account' : 'Change preview role',
              onPressed: _roleMenu,
              icon: FiloAvatar(
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
      body: live && _destination == 1
          ? WorkQueueScreen(student: student, embedded: true)
          : _refresh(
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 104),
                children: [
                  if (live && !online) const OfflineBanner(),
                  if (live && sync.hasError)
                    FiloPanel(
                      child: Column(
                        children: [
                          const Text(
                            'Could not refresh your classes. Showing saved content.',
                          ),
                          TextButton(
                            onPressed: online
                                ? () => ref
                                      .read(classSyncProvider.notifier)
                                      .refresh()
                                : null,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),

                  if (cards.hasError)
                    const FiloPanel(
                      child: Text(
                        'Could not read saved classes. Try reopening the app.',
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your classes',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'A good place to grow.',
                              style: TextStyle(
                                color: FiloColors.secondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Mascot(size: 92),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Find a class',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        borderSide: BorderSide(color: FiloColors.border),
                      ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 24),
                  if (rooms.isEmpty &&
                      !loading &&
                      !cards.hasError &&
                      !sync.hasError)
                    EmptyState(
                      title: !online
                          ? 'No saved classes found.'
                          : _query.trim().isEmpty
                          ? 'No classes yet.'
                          : 'No classes found.',
                      message: !online
                          ? 'Connect to the internet to refresh your classes.'
                          : _query.trim().isNotEmpty
                          ? 'Try another course, section, or instructor.'
                          : student
                          ? 'Join a class using the code from your instructor.'
                          : 'Create a class to get started.',
                    ),
                  if (loading) ...const [
                    ClassCardSkeleton(),
                    ClassCardSkeleton(),
                    ClassCardSkeleton(),
                  ],
                  for (final room in rooms.where((room) => !room.archived))
                    _classTile(room),
                  if (rooms.any((room) => room.archived)) ...[
                    Text(
                      'Archived',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    for (final room in rooms.where((room) => room.archived))
                      _classTile(room),
                  ],
                  if (live && !student)
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Recently deleted'),
                      subtitle: const Text('Restore classes within 14 days'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RecentlyDeletedScreen(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        size: 18,
                        color: FiloColors.secondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'One class. A world of possibilities.',
                          style: TextStyle(color: FiloColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _destination == 1
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FiloButton(
                label: student ? 'Join class' : 'Create class',
                icon: Icons.add_rounded,
                onPressed: !online
                    ? null
                    : student
                    ? _join
                    : live
                    ? _create
                    : () => context.push('/classes/it119'),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destination,
        onDestinationSelected: (index) {
          if (index <= 1 && live) {
            setState(() => _destination = index);
          } else if (index != 0) {
            showMessage(context, 'This area will be available soon.');
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  live &&
                  !student &&
                  ref.watch(workQueueProvider(false)).entries.isNotEmpty,
              label: Text(
                live && !student
                    ? '${ref.watch(workQueueProvider(false)).entries.length}'
                    : '',
              ),
              child: const Icon(Icons.checklist_rounded),
            ),
            label: student ? 'To-do' : 'To review',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Files',
          ),
          if (student)
            const NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              label: 'AI Study',
            ),
        ],
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
    padding: const EdgeInsets.only(bottom: 16),
    child: ClassCard(
      room: room,
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
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(widget.profile!.name),
                subtitle: Text('${widget.profile!.role.label} account'),
              ),
              ListTile(
                title: const Text('Sign out'),
                leading: const Icon(Icons.logout_rounded),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(supabaseClientProvider).auth.signOut();
                },
              ),
              ListTile(
                title: const Text('Drive backup'),
                leading: const Icon(Icons.cloud_upload_outlined),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DriveBackupScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Student preview'),
              leading: const Icon(Icons.school_rounded),
              onTap: () {
                ref
                    .read(previewProvider.notifier)
                    .chooseRole(PreviewRole.student);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Instructor preview'),
              leading: const Icon(Icons.auto_stories_rounded),
              onTap: () {
                ref
                    .read(previewProvider.notifier)
                    .chooseRole(PreviewRole.instructor);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Back to welcome'),
              leading: const Icon(Icons.logout_rounded),
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
    await showModalBottomSheet<void>(
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
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your classroom.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.preview
                ? 'Enter the code from your instructor.\nPreview code: FILO26'
                : 'Enter the code from your instructor.',
            style: TextStyle(color: FiloColors.secondary),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 16),
          if (!widget.preview &&
              ref.watch(connectivityProvider).asData?.value != true)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Connect to the internet to join a class.'),
            ),
          FiloButton(
            label: _busy ? 'Sending?' : 'Request to join',
            icon: Icons.arrow_forward_rounded,
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
