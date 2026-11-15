import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/filo_widgets.dart';
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
  Widget build(BuildContext context) {
    final preset = status.startsWith('Graded')
        ? FiloStatusPreset.graded
        : switch (status) {
            'Turned in' => FiloStatusPreset.turnedIn,
            'Late' => FiloStatusPreset.late,
            'Missing' => FiloStatusPreset.missing,
            'In progress' => FiloStatusPreset.inProgress,
            'Not started' => FiloStatusPreset.notStarted,
            'Assigned' => FiloStatusPreset.assigned,
            _ => null,
          };
    return preset == null
        ? FiloStatusChip(label: status, icon: FiloIcons.assessment)
        : FiloStatusChip.preset(preset, label: status);
  }
}

class GradingSkeleton extends StatelessWidget {
  const GradingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: List.generate(
      6,
      (_) => Container(
        height: 76,
        margin: const EdgeInsets.symmetric(
          horizontal: FiloSpacing.screen,
          vertical: FiloSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: FiloThemeTokens.of(context).mint,
          borderRadius: BorderRadius.circular(FiloRadii.medium),
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
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final _searchController = TextEditingController();
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
      final confirmed = await showFiloConfirmation(
        context,
        animate: false,
        title: 'Return $count graded ${count == 1 ? 'work' : 'works'}?',
        message: count == 1
            ? 'This student will be able to see their score and feedback.'
            : 'These students will be able to see their scores and feedback.',
        confirmLabel: 'Return',
        cancelLabel: 'Cancel',
        cancelIsPrimary: true,
      );
      if (confirmed != true || !_online) {
        return;
      }
      final repo = await ref.read(gradingRepositoryProvider.future);
      if (repo == null) {
        throw StateError('No account');
      }
      final changed = await repo.returnAll(widget.classId, widget.postId);
      if (mounted && changed > 0) FiloHaptics.confirmed(context);
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
    return FiloMotionScope(
      enabled: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Submissions')),
        body: state.when(
          loading: () => const GradingSkeleton(),
          error: (_, _) => Center(
            child: EmptyState(
              title: 'Grades unavailable',
              body: "Couldn't load grades. Try again.",
              showMascot: false,
              primaryAction: EmptyStateAction(
                label: 'Retry',
                onPressed: !online ? null : _refresh,
              ),
            ),
          ),
          data: (data) {
            if (!data.loaded) {
              return sync.isLoading
                  ? const GradingSkeleton()
                  : Center(
                      child: EmptyState(
                        title: 'Grades unavailable',
                        body: online
                            ? "Couldn't load grades. Try again."
                            : 'Connect to the internet to load grades',
                        showMascot: false,
                        primaryAction: EmptyStateAction(
                          label: 'Retry',
                          onPressed: !online ? null : _refresh,
                        ),
                      ),
                    );
            }
            final assignment = data.assignment(widget.postId);
            if (assignment == null) {
              return Center(
                child: EmptyState(
                  title: online ? 'Item unavailable' : 'Grades not saved',
                  body: online
                      ? 'Return to the class and refresh to check this item.'
                      : 'Connect and refresh to load grades.',
                  showMascot: false,
                  primaryAction: online
                      ? null
                      : EmptyStateAction(
                          label: 'Retry',
                          onPressed: !online ? null : _refresh,
                        ),
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
                padding: const EdgeInsets.all(FiloSpacing.screen),
                children: [
                  if (!online) const OfflineBanner(),
                  if (sync.hasError)
                    EmptyState(
                      title: 'Grades unavailable',
                      body: "Couldn't load grades. Try again.",
                      showMascot: false,
                      primaryAction: EmptyStateAction(
                        label: 'Retry',
                        onPressed: !online ? null : _refresh,
                      ),
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
                              padding: const EdgeInsets.all(FiloSpacing.s12),
                              child: Text(
                                '$s: ${members.where((m) => s == 'Graded' ? status(m).startsWith(s) : status(m) == s).length}',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  TextField(
                    controller: _searchController,
                    enabled: members.isNotEmpty || _search.isNotEmpty,
                    decoration: const InputDecoration(
                      labelText: 'Search students',
                      prefixIcon: FiloIcon(FiloIcons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'To grade', 'Late', 'Missing', 'Graded']
                        .map(
                          (s) => FiloAnimatedChip.filter(
                            label: Text(s),
                            selected: _filter == s,
                            onSelected: members.isEmpty
                                ? null
                                : (_) => setState(() => _filter = s),
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
                      padding: EdgeInsets.all(FiloSpacing.s12),
                      child: EmptyState(
                        title: 'No submissions yet',
                        body: 'Student work will appear here after turn-in.',
                        showMascot: false,
                      ),
                    ),
                  if (visible.isEmpty &&
                      (_search.trim().isNotEmpty || _filter != 'All'))
                    Padding(
                      padding: const EdgeInsets.all(FiloSpacing.screen),
                      child: EmptyState(
                        title: 'No matching students',
                        body: _search.trim().isEmpty
                            ? 'Choose another status or show all students.'
                            : 'No matches for "$_search"; check the spelling or clear your search.',
                        showMascot: false,
                        primaryAction: EmptyStateAction(
                          label: 'Clear search and filters',
                          onPressed: () => setState(() {
                            _search = '';
                            _searchController.clear();
                            _filter = 'All';
                          }),
                        ),
                      ),
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
                              (m['profiles'] as Map?)?['avatar_path']
                                  as String?,
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
                            FiloInstantRoute<void>(
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
      ),
    );
  }
}
