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
import 'create_class_screen.dart';
import '../domain/prototype_models.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key, this.profile});
  final AccountProfile? profile;
  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewProvider);
    final live = widget.profile != null;
    if (live) ref.watch(classSyncLifecycleProvider);
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
              .contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Brand(),
        toolbarHeight: 76,
        actions: [
          IconButton(
            tooltip: live ? 'Saved classes' : 'Preview information',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showMessage(
              context,
              live
                  ? 'Your classes are saved on this phone. Pull down to refresh.'
                  : 'Sample classrooms. Changes stay in this preview session.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              tooltip: live ? 'Your account' : 'Change preview role',
              onPressed: _roleMenu,
              icon: Icon(
                student ? Icons.school_rounded : Icons.auto_stories_rounded,
              ),
            ),
          ),
        ],
      ),
      body: _refresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            if (live && !online)
              const FiloPanel(
                child: Text("You're offline. Showing saved content."),
              ),
            if (live && sync.hasError)
              FiloPanel(
                child: Column(
                  children: [
                    const Text(
                      'Could not refresh your classes. Showing saved content.',
                    ),
                    TextButton(
                      onPressed: online
                          ? () => ref.read(classSyncProvider.notifier).refresh()
                          : null,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (cards.isLoading) const LinearProgressIndicator(),
            if (cards.hasError)
              const FiloPanel(
                child: Text(
                  'Could not read saved classes. Try reopening the app.',
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (!live)
                  const Chip(
                    label: Text('Preview · sample data'),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  label: Text(student ? 'Student' : 'Instructor'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 20),
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
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 24),
            if (rooms.isEmpty && !cards.isLoading && !cards.hasError)
              EmptyState(
                title: _query.isEmpty ? 'No classes yet.' : 'No classes found.',
                message: _query.isNotEmpty
                    ? 'Try another course, section, or instructor.'
                    : student
                    ? 'Join a class using the code from your instructor.'
                    : 'Create a class to get started.',
              ),
            for (final room in rooms.where((room) => !room.archived))
              _classTile(room),
            if (rooms.any((room) => room.archived)) ...[
              Text('Archived', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (final room in rooms.where((room) => room.archived))
                _classTile(room),
            ],
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.eco_outlined, size: 18, color: FiloColors.secondary),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!online)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    student
                        ? 'Connect to the internet to join a class.'
                        : 'Connect to the internet to create a class.',
                  ),
                ),
              student
                  ? FiloButton(
                      label: 'Join class',
                      icon: Icons.add_rounded,
                      onPressed: online ? _join : null,
                    )
                  : FiloButton(
                      label: live ? 'Create class' : 'Explore a class',
                      icon: live
                          ? Icons.add_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: !online
                          ? null
                          : live
                          ? _create
                          : () => context.push('/classes/it119'),
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
    padding: const EdgeInsets.only(bottom: 16),
    child: _ClassCard(
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
            'requested' =>
              "Request sent. We'll notify you when your instructor approves.",
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

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.room,
    required this.onTap,
    this.pendingRequests = 0,
  });
  final ClassRoom room;
  final VoidCallback? onTap;
  final int pendingRequests;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Color(room.color),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.section,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.course,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: FiloColors.tint,
                  child: Text(
                    room.instructor.trim().isEmpty
                        ? '?'
                        : room.instructor.trim()[0],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    room.instructor,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Badge(
                  isLabelVisible: pendingRequests > 0,
                  child: Icon(
                    room.pending
                        ? Icons.hourglass_top_rounded
                        : Icons.arrow_forward_rounded,
                    color: FiloColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (room.pending)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Waiting for approval',
                style: TextStyle(color: Color(0xFF8A5200)),
              ),
            ),
        ],
      ),
    ),
  );
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
        setState(
          () => _error = 'Could not send your request. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
