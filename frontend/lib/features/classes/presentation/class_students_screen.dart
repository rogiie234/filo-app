import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/class_providers.dart';
import '../data/class_member_repository.dart';

class ClassStudentsScreen extends ConsumerStatefulWidget {
  const ClassStudentsScreen({super.key, required this.classId});
  final String classId;

  @override
  ConsumerState<ClassStudentsScreen> createState() =>
      _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends ConsumerState<ClassStudentsScreen> {
  bool _busy = false;
  String? _message;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove ${student.name} from $section?'),
        content: const Text(
          'They will lose access to this class. Their submissions and grades will be kept, and downloaded files will stay on their device. To rejoin, they will need to send a new request for approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove student'),
          ),
        ],
      ),
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
    final pending = rows
        .where((s) => s.membership.status == 'pending')
        .toList();
    final active = rows.where((s) => s.membership.status == 'active').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (room != null)
              Text(room.section, style: Theme.of(context).textTheme.titleLarge),
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
            if (students.isLoading || sync.isLoading || _busy)
              const LinearProgressIndicator(),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            const SizedBox(height: 24),
            Text(
              'Requests (${pending.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (pending.isNotEmpty)
              FiloButton(
                label: 'Approve all',
                icon: Icons.done_all_rounded,
                onPressed: canDecide ? () => _decide() : null,
              ),
            if (pending.isEmpty &&
                !students.isLoading &&
                !students.hasError &&
                online &&
                !sync.isLoading &&
                !sync.hasError)
              const Text('No pending requests.'),
            for (final student in pending)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FiloPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('Waiting for approval'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: canDecide
                                ? () => _decide(student: student)
                                : null,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve'),
                          ),
                          OutlinedButton(
                            onPressed: canDecide
                                ? () =>
                                      _decide(student: student, approve: false)
                                : null,
                            child: const Text('Decline'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Enrolled students (${active.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (active.isEmpty &&
                !students.isLoading &&
                !students.hasError &&
                online &&
                !sync.isLoading &&
                !sync.hasError)
              const Text('No enrolled students yet.'),
            for (final student in active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    student.name.trim().isEmpty ? '?' : student.name.trim()[0],
                  ),
                ),
                title: Text(student.name),
                subtitle: const Text('Enrolled'),
                trailing: TextButton(
                  onPressed: canDecide
                      ? () => _remove(student, room.section)
                      : null,
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
