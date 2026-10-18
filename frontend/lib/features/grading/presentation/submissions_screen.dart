import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/presentation/classes_widgets.dart'
    show OfflineBanner, FiloAvatar;
import '../application/grading_providers.dart';
import '../domain/grading_models.dart';
import 'grade_screen.dart';

String gradingName(Json member) =>
    ((member['profiles'] as Map?)?['display_name'] ?? 'Student').toString();
String gradingDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null
      ? 'No due date'
      : '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class GradeStatusChip extends StatelessWidget {
  const GradeStatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      status.startsWith('Graded')
          ? Icons.check_circle_outline
          : status == 'Late'
          ? Icons.schedule
          : status == 'Missing'
          ? Icons.error_outline
          : Icons.assignment_outlined,
      size: 18,
    ),
    label: Text(status),
  );
}

class GradingSkeleton extends StatelessWidget {
  const GradingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: List.generate(
      6,
      (_) => Container(
        height: 76,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FiloColors.mint,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}

class SubmissionsScreen extends ConsumerStatefulWidget {
  const SubmissionsScreen({
    super.key,
    required this.classId,
    required this.postId,
  });
  final String classId, postId;
  @override
  ConsumerState<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends ConsumerState<SubmissionsScreen> {
  String _search = '', _filter = 'All';
  bool _busy = false;
  String? _error;
  bool get _online => ref.read(connectivityProvider).asData?.value == true;
  Future<void> _refresh() async {
    if (!_online) {
      return;
    }
    try {
      ref.invalidate(gradingSyncProvider(widget.classId));
      await ref.read(gradingSyncProvider(widget.classId).future);
      if (mounted) {
        setState(() => _error = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't load grades. Try again.");
      }
    }
  }

  Future<void> _returnAll() async {
    setState(() => _busy = true);
    try {
      await _refresh();
      if (_error != null || !mounted) {
        return;
      }
      final repository = await ref.read(gradingRepositoryProvider.future);
      final data = await repository?.read(widget.classId);
      if (!mounted || data == null) {
        return;
      }
      final ids = data.submissions
          .where((s) => s['post_id'] == widget.postId)
          .map((s) => s['id'])
          .toSet();
      final count = data.grades
          .where(
            (g) => ids.contains(g['submission_id']) && g['returned_at'] == null,
          )
          .length;
      if (count == 0) {
        _message('No grades to return.');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Return $count graded ${count == 1 ? 'work' : 'works'}?'),
          content: Text(
            count == 1
                ? 'This student will be able to see their score and feedback.'
                : 'These students will be able to see their scores and feedback.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Return'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_online) {
        return;
      }
      final repo = await ref.read(gradingRepositoryProvider.future);
      if (repo == null) {
        throw StateError('No account');
      }
      final changed = await repo.returnAll(widget.classId, widget.postId);
      await _refresh();
      _message(
        changed == 0
            ? 'No grades to return.'
            : '$changed ${changed == 1 ? 'grade' : 'grades'} returned.',
      );
    } on PostgrestException {
      if (mounted) {
        setState(() => _error = "Couldn't return the grades. Try again.");
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = "We couldn't confirm the update. Refresh to check the grade before trying again.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final rooms = ref.watch(classesProvider).asData?.value;
    final archived =
        rooms == null ||
        !rooms.any((c) => c.id == widget.classId && c.archivedAt == null);
    final sync = ref.watch(gradingSyncProvider(widget.classId));
    final state = ref.watch(gradingDataProvider(widget.classId));
    return Scaffold(
      appBar: AppBar(title: const Text('Submissions')),
      body: state.when(
        loading: () => const GradingSkeleton(),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: _refresh,
            child: const Text("Couldn't load grades. Try again."),
          ),
        ),
        data: (data) {
          if (!data.loaded) {
            return sync.isLoading
                ? const GradingSkeleton()
                : Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: Text(
                        online
                            ? "Couldn't load grades. Try again."
                            : 'Connect to the internet to load grades',
                      ),
                    ),
                  );
          }
          final assignment = data.assignment(widget.postId);
          if (assignment == null) {
            return Center(
              child: Text(
                online
                    ? 'This item is no longer available.'
                    : 'Connect to the internet to load grades',
              ),
            );
          }
          final members =
              data.members.where((m) => m['status'] == 'active').toList()
                ..sort((a, b) => gradingName(a).compareTo(gradingName(b)));
          String status(Json member) =>
              data.status(widget.postId, member['student_id'].toString());
          final visible = members.where((m) {
            final s = status(m);
            return gradingName(m)
                    .toLowerCase()
                    .contains(_search.toLowerCase()) &&
                (_filter == 'All' ||
                    (_filter == 'To grade' &&
                        (s == 'Turned in' || s == 'Late')) ||
                    (_filter == 'Graded' && s.startsWith('Graded')) ||
                    _filter == s);
          }).toList();
          final pending = data.submissions
              .where(
                (s) =>
                    s['post_id'] == widget.postId &&
                    data.grade(s['id'].toString())?['returned_at'] == null &&
                    data.grade(s['id'].toString()) != null,
              )
              .length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (!online) const OfflineBanner(),
                if (sync.hasError)
                  TextButton(
                    onPressed: _refresh,
                    child: const Text("Couldn't load grades. Try again."),
                  ),
                if (archived) const Text('This class is archived.'),
                Text(
                  '${assignment['title']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${gradingDate(assignment['due_at'])} · ${assignment['points']} points',
                ),
                Wrap(
                  spacing: 8,
                  children: ['Turned in', 'Late', 'Missing', 'Graded']
                      .map(
                        (s) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '$s: ${members.where((m) => s == 'Graded' ? status(m).startsWith(s) : status(m) == s).length}',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search students',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                Wrap(
                  spacing: 8,
                  children: ['All', 'To grade', 'Late', 'Missing', 'Graded']
                      .map(
                        (s) => FilterChip(
                          label: Text(s),
                          selected: _filter == s,
                          onSelected: (_) => setState(() => _filter = s),
                        ),
                      )
                      .toList(),
                ),
                OutlinedButton(
                  onPressed:
                      online &&
                          !archived &&
                          !_busy &&
                          pending > 0 &&
                          _error == null
                      ? _returnAll
                      : null,
                  child: Text('Return all graded ($pending)'),
                ),
                if (_error != null)
                  ListTile(
                    title: Text(_error!),
                    trailing: TextButton(
                      onPressed: _refresh,
                      child: const Text('Refresh'),
                    ),
                  ),
                if (!data.submissions.any(
                  (s) =>
                      s['post_id'] == widget.postId &&
                      s['submitted_at'] != null,
                ))
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      "No submissions yet.\nStudents' work will appear here after they turn it in.",
                    ),
                  ),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No matching results.'),
                  ),
                ...visible.map((m) {
                  final id = m['student_id'].toString(), s = status(m);
                  final submission = data.submission(widget.postId, id);
                  final grade = submission == null
                      ? null
                      : data.grade(submission['id'].toString());
                  return Card(
                    child: ListTile(
                      leading: FiloAvatar(
                        name: gradingName(m),
                        path:
                            (m['profiles'] as Map?)?['avatar_path'] as String?,
                      ),
                      title: Text(gradingName(m)),
                      subtitle: GradeStatusChip(s),
                      trailing: grade == null
                          ? null
                          : Text(
                              '${grade['score']}/${assignment['points']}${grade['returned_at'] == null ? '\nNot returned' : ''}',
                            ),
                      onTap: () {
                        if (submission == null && s != 'Missing') {
                          _message('No work turned in.');
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GradeScreen(
                              classId: widget.classId,
                              postId: widget.postId,
                              studentId: id,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
