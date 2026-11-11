import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
import '../application/class_providers.dart';
import '../data/class_member_repository.dart';

class ClassStudentsScreen extends ConsumerStatefulWidget {
  const ClassStudentsScreen({
    super.key,
    required this.classId,
    this.focusRequests = false,
  });
  final String classId;
  final bool focusRequests;

  @override
  ConsumerState<ClassStudentsScreen> createState() =>
      _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends ConsumerState<ClassStudentsScreen> {
  bool _busy = false;
  String? _busyAction;
  String? _message;
  final _requestsKey = GlobalKey();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(() async {
        if (mounted) await _refresh();
      }),
    );
  }

  Future<void> _refresh() => ref.read(classSyncProvider.notifier).refresh();

  Future<void> _decide({ClassStudent? student, bool approve = true}) async {
    if (_busy || ref.read(connectivityProvider).asData?.value != true) return;
    final rooms = ref.read(classCardsProvider).asData?.value ?? [];
    final matches = rooms.where((room) => room.id == widget.classId);
    if (matches.isEmpty || matches.first.archived) return;
    setState(() {
      _busy = true;
      _busyAction = student == null
          ? 'all'
          : '${student.membership.id}:$approve';
      _message = null;
    });
    try {
      final repository = await ref.read(classMemberRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      String message;
      if (student == null) {
        final count = await repository.approveAll(widget.classId);
        message = count is int
            ? '$count ${count == 1 ? 'request approved.' : 'requests approved.'}'
            : 'Pending requests approved.';
      } else {
        await repository.decide(student.membership.id, approve);
        message = approve
            ? '${student.name} approved.'
            : '${student.name}\'s request declined.';
      }
      if (mounted) {
        setState(() => _message = message);
        showMessage(context, message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not confirm the update. Pull down to refresh before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ClassStudent student, String section) async {
    if (_busy || ref.read(connectivityProvider).asData?.value != true) return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Remove ${student.name} from $section?',
      message: 'They will lose access to this class. Their submissions and grades will be kept, and downloaded files will stay on their device. To rejoin, they will need to send a new request for approval.',
      confirmLabel: 'Remove student',
      cancelLabel: 'Cancel',
      cancelIsPrimary: true,
      confirmDestructive: true,
      confirmOutlined: true,
      icon: FiloIcons.people,
    );
    if (confirmed != true ||
        !mounted ||
        _busy ||
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
    final rooms = ref.read(classCardsProvider).asData?.value ?? [];
    if (!rooms.any((room) => room.id == widget.classId && !room.archived)) {
      return;
    }
    setState(() {
      _busy = true;
      _busyAction = '${student.membership.id}:remove';
      _message = null;
    });
    try {
      final repository = await ref.read(classMemberRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      await repository.remove(widget.classId, student.membership.studentId);
      if (mounted) showMessage(context, '${student.name} removed.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = "We couldn't confirm the change. Refresh the class before trying again.",
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(classStudentsProvider(widget.classId));
    final rooms = ref.watch(classCardsProvider);
    final matches = rooms.asData?.value.where(
      (room) => room.id == widget.classId,
    );
    final room = matches != null && matches.isNotEmpty ? matches.first : null;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final sync = ref.watch(classSyncProvider);
    final canDecide = online && !_busy && room != null && !room.archived;
    final rows = students.asData?.value ?? <ClassStudent>[];
    if (widget.focusRequests && !_focused && students.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focused || _requestsKey.currentContext == null) return;
        _focused = true;
        Scrollable.ensureVisible(_requestsKey.currentContext!, alignment: 0);
      });
    }
    final pending = rows
        .where((s) => s.membership.status == 'pending')
        .toList();
    final active = rows.where((s) => s.membership.status == 'active').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return EntryBackground(
      verification: true,
      breeze: true,
      variation: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Students'),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FiloSpacing.screen),
                children: [
                  if (room != null)
                    FiloPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.section,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: FiloSpacing.s4),
                          Text(
                            room.course,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: FiloSpacing.s12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text('${pending.length} pending requests'),
                              Text('${active.length} enrolled students'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: FiloSpacing.s16),
                  if (!online)
                    const FiloPanel(
                      child: Text(
                        "You're offline. Connect to manage students and requests.",
                      ),
                    ),
                  if (room?.archived == true)
                    const FiloPanel(
                      child: Text('This class is archived and read-only.'),
                    ),
                  if (rooms.asData != null && room == null)
                    const FiloPanel(
                      child: Text('This class is no longer available.'),
                    ),
                  if (students.isLoading && !students.hasValue)
                    const Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: FiloCircularProgressIndicator(
                          semanticsLabel: 'Loading students',
                        ),
                      ),
                    ),
                  if (students.hasError || (online && sync.hasError))
                    FiloPanel(
                      child: Column(
                        children: [
                          const Text(
                            'Could not refresh students. Showing saved information.',
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    ref.invalidate(
                                      classStudentsProvider(widget.classId),
                                    );
                                    unawaited(_refresh());
                                  },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: FiloSpacing.s12,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: FiloPanel(child: Text(_message!)),
                      ),
                    ),
                  const SizedBox(height: FiloSpacing.screen),
                  Text(
                    'Requests (${pending.length})',
                    key: _requestsKey,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: FiloSpacing.s12),
                  if (pending.isNotEmpty)
                    FiloButton(
                      label: 'Approve all',
                      busy: _busy && _busyAction == 'all',
                      icon: FiloIcons.checks,
                      onPressed: canDecide ? () => _decide() : null,
                    ),
                  if (pending.isEmpty &&
                      !students.isLoading &&
                      !students.hasError &&
                      online &&
                      !sync.isLoading &&
                      !sync.hasError)
                    const FiloPanel(child: Text('No pending requests.')),
                  for (final student in pending)
                    Padding(
                      padding: const EdgeInsets.only(top: FiloSpacing.s16),
                      child: FiloPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: FiloSpacing.s8),
                            const Text('Waiting for approval'),
                            const SizedBox(height: FiloSpacing.s12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: canDecide
                                      ? () => _decide(student: student)
                                      : null,
                                  icon:
                                      _busy &&
                                          _busyAction ==
                                              '${student.membership.id}:true'
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: FiloCircularProgressIndicator(
                                            strokeWidth: 2,
                                            semanticsLabel: 'Approving student',
                                          ),
                                        )
                                      : const FiloIcon(FiloIcons.check),
                                  label: const Text('Approve'),
                                ),
                                OutlinedButton(
                                  onPressed: canDecide
                                      ? () => _decide(
                                          student: student,
                                          approve: false,
                                        )
                                      : null,
                                  child:
                                      _busy &&
                                          _busyAction ==
                                              '${student.membership.id}:false'
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: FiloCircularProgressIndicator(
                                            strokeWidth: 2,
                                            semanticsLabel: 'Declining request',
                                          ),
                                        )
                                      : const Text('Decline'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: FiloSpacing.s32),
                  Text(
                    'Enrolled students (${active.length})',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: FiloSpacing.s12),
                  if (active.isEmpty &&
                      !students.isLoading &&
                      !students.hasError &&
                      online &&
                      !sync.isLoading &&
                      !sync.hasError)
                    const FiloPanel(child: Text('No enrolled students yet.')),
                  for (final student in active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
                      child: FiloPanel(
                        padding: const EdgeInsets.all(FiloSpacing.s8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: FiloSpacing.s12,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              student.name.trim().isEmpty
                                  ? '?'
                                  : student.name.trim()[0],
                            ),
                          ),
                          title: Text(student.name),
                          subtitle: const Text('Enrolled'),
                          trailing: TextButton(
                            onPressed: canDecide
                                ? () => _remove(student, room.section)
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                            child:
                                _busy &&
                                    _busyAction ==
                                        '${student.membership.id}:remove'
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: FiloCircularProgressIndicator(
                                      strokeWidth: 2,
                                      semanticsLabel: 'Removing student',
                                    ),
                                  )
                                : const Text('Remove'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
