import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../classes/application/class_providers.dart';
import '../application/grading_providers.dart';
import '../domain/grading_models.dart';
import 'grade_screen.dart';
import '../../results/presentation/attempt_detail_screen.dart';

String gradebookName(Json member) =>
    ((member['profiles'] as Map?)?['display_name'] ?? 'Student').toString();

String gradebookTotal(GradeTotal total) =>
    '${total.earned}/${total.possible} · ${total.percent == null ? '—' : '${total.percent}%'}';

String gradebookCell(GradingData data, String post, String student) {
  final submission = data.submission(post, student);
  final grade = submission == null
      ? null
      : data.grade(submission['id'].toString());
  if (grade != null) {
    return '${grade['score']}';
  }
  final status = data.status(post, student);
  return status == 'Missing' || status == 'Late' ? status : '—';
}

String gradebookItemCell(GradingData data, Json item, String studentId) {
  if (item['is_quiz'] != true)
    return gradebookCell(data, item['id'] as String, studentId);
  final attempt = data.quizAttempt(item['id'] as String, studentId);
  final value = data.quizCell(item, studentId);
  if (attempt == null ||
      !['submitted', 'auto_submitted'].contains(attempt['status']))
    return value;
  return '$value${item['results_released_at'] == null ? '\nNot released' : ''}${attempt['grading_complete'] != true ? '\nProvisional' : ''}';
}

void openGradebookItem(
  BuildContext context,
  String classId,
  GradingData data,
  Json item,
  String studentId,
) {
  if (item['is_quiz'] != true) {
    openGradebookGrade(context, classId, item['id'] as String, studentId);
    return;
  }
  final attempt = data.quizAttempt(item['id'] as String, studentId);
  if (attempt != null)
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttemptDetailScreen(
          quizId: item['id'] as String,
          sessionId: attempt['id'] as String,
        ),
      ),
    );
}

void openGradebookGrade(
  BuildContext context,
  String classId,
  String post,
  String student,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          GradeScreen(classId: classId, postId: post, studentId: student),
    ),
  );
}

class GradebookScreen extends ConsumerStatefulWidget {
  const GradebookScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends ConsumerState<GradebookScreen> {
  bool _table = false;
  bool _exporting = false;
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_refresh));
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(gradingSyncProvider(widget.classId));
      await ref.read(gradingSyncProvider(widget.classId).future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't load grades. Try again.")),
        );
      }
    }
  }

  Future<void> _export(GradingData data) async {
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    File? file;
    try {
      String cell(Object? value) {
        var text = value?.toString() ?? '';
        if (RegExp(r'^\s*[=+@-]').hasMatch(text)) {
          text = "'$text";
        }
        return '"${text.replaceAll('"', '""')}"';
      }

      final rows = <List<Object?>>[
        [
          'Student name',
          ...data.items.map((a) => a['title']),
          'Total points',
          'Percentage',
        ],
        for (final member in data.members.where(
          (m) => ['active', 'left', 'removed'].contains(m['status']),
        ))
          [
            gradebookName(member),
            ...data.items.map((a) {
              final value = gradebookItemCell(
                data,
                a,
                member['student_id'].toString(),
              );
              return value == '—' || value == 'Late' ? '' : value;
            }),
            '${data.total(member['student_id'].toString()).earned}/${data.total(member['student_id'].toString()).possible}',
            data.total(member['student_id'].toString()).percent == null
                ? ''
                : '${data.total(member['student_id'].toString()).percent}%',
          ],
      ];
      final rooms = ref.read(classesProvider).asData?.value ?? [];
      final room = rooms.where((r) => r.id == widget.classId).firstOrNull;
      final name = room == null ? 'class' : '${room.section}_${room.course}';
      final date = DateTime.now().toIso8601String().split('T').first;
      final directory = await getTemporaryDirectory();
      // Use a dedicated temporary directory; remove only this export after sharing.
      final exportDirectory = await Directory(
        '${directory.path}/filo-grades-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      file = File(
        '${exportDirectory.path}/${name.replaceAll(RegExp(r'[^\w-]'), '_')}_$date.csv',
      );
      await file.writeAsString(
        '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n',
      );
      if (!mounted) {
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Gradebook · $name',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't export grades. Try again.")),
        );
      }
    } finally {
      if (file != null) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
          await file.parent.delete();
        } catch (_) {
          /* OS may retain a share handle. */
        }
      }
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gradingDataProvider(widget.classId));
    final data = state.asData?.value;
    final offline = ref.watch(connectivityProvider).asData?.value != true;
    final sync = ref.watch(gradingSyncProvider(widget.classId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gradebook'),
        actions: [
          PopupMenuButton<String>(
            enabled: data != null && data.loaded && !_exporting,
            onSelected: (_) => _export(data!),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (offline) const GradebookOfflineBanner(),
          if (sync.hasError) GradebookRetry(onRetry: _refresh),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: FiloIcon(FiloIcons.list),
                  label: Text('List'),
                ),
                ButtonSegment(
                  value: true,
                  icon: FiloIcon(FiloIcons.spreadsheet),
                  label: Text('Table'),
                ),
              ],
              selected: {_table},
              onSelectionChanged: (values) =>
                  setState(() => _table = values.first),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const GradebookSkeleton(),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: _refresh,
                  child: const Text("Couldn't load grades. Try again."),
                ),
              ),
              data: (data) {
                if (!data.loaded && !offline && sync.isLoading) {
                  return const GradebookSkeleton();
                }
                if (!data.loaded) {
                  return Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: Text(
                        offline
                            ? 'Connect to the internet to load grades'
                            : "Couldn't load grades. Try again.",
                      ),
                    ),
                  );
                }
                final active =
                    data.members.where((m) => m['status'] == 'active').toList()
                      ..sort(
                        (a, b) => gradebookName(a).compareTo(gradebookName(b)),
                      );
                final former = data.members
                    .where((m) => ['left', 'removed'].contains(m['status']))
                    .toList();
                if (data.members.isEmpty || data.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Your gradebook is empty.'),
                        ),
                      ],
                    ),
                  );
                }
                if (_table) {
                  return Column(
                    children: [
                      TextButton.icon(
                        onPressed: _refresh,
                        icon: const FiloIcon(FiloIcons.refresh),
                        label: const Text('Refresh'),
                      ),
                      Expanded(
                        child: _GradebookTable(
                          data: data,
                          members: active,
                          classId: widget.classId,
                          onRefresh: _refresh,
                        ),
                      ),
                      if (former.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            child: _former(data, former),
                          ),
                        ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      for (final member in active) _student(data, member),
                      if (former.isNotEmpty) _former(data, former),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _former(GradingData data, List<Json> members) => FiloExpansionTile(
    title: Text('Former students (${members.length})'),
    children: [for (final member in members) _student(data, member)],
  );
  Widget _student(GradingData data, Json member) {
    final id = member['student_id'].toString();
    final total = data.total(id);
    return ListTile(
      leading: const CircleAvatar(child: FiloIcon(FiloIcons.person)),
      title: Text(gradebookName(member)),
      subtitle: Text(
        '${gradebookTotal(total)}${total.hasUnreturned ? '\nIncludes grades not returned or quiz scores not released' : ''}${data.quizzesLoaded ? '' : '\nQuiz scores have not finished syncing.'}',
      ),
      trailing: const FiloIcon(FiloIcons.chevronRight),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _StudentGradesScreen(
            classId: widget.classId,
            studentId: id,
            name: gradebookName(member),
          ),
        ),
      ),
    );
  }
}

class _StudentGradesScreen extends ConsumerWidget {
  const _StudentGradesScreen({
    required this.classId,
    required this.studentId,
    required this.name,
  });
  final String classId, studentId, name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(gradingSyncProvider(classId));
    final offline = ref.watch(connectivityProvider).asData?.value != true;
    Future<void> refresh() async {
      try {
        ref.invalidate(gradingSyncProvider(classId));
        await ref.read(gradingSyncProvider(classId).future);
      } catch (_) {
        /* Persistent Retry reports the failure. */
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ref
          .watch(gradingDataProvider(classId))
          .when(
            loading: () => const GradebookSkeleton(),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: refresh,
                child: const Text("Couldn't load grades. Try again."),
              ),
            ),
            data: (data) {
              if (!data.loaded) {
                if (!offline && sync.isLoading) {
                  return const GradebookSkeleton();
                }
                return Center(
                  child: TextButton(
                    onPressed: refresh,
                    child: Text(
                      offline
                          ? 'Connect to the internet to load grades'
                          : "Couldn't load grades. Try again.",
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  if (offline) const GradebookOfflineBanner(),
                  if (sync.hasError) GradebookRetry(onRetry: refresh),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${gradebookTotal(data.total(studentId))}${data.quizzesLoaded ? '' : '\nQuiz scores have not finished syncing.'}',
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: data.items.length,
                        itemBuilder: (context, index) {
                          final assignment = data.items[index];
                          final post = assignment['id'].toString();
                          return ListTile(
                            title: Text(assignment['title'].toString()),
                            subtitle: Text(
                              assignment['is_quiz'] == true
                                  ? data.quizStatus(assignment, studentId)
                                  : data.status(post, studentId),
                            ),
                            trailing: Text(
                              assignment['is_quiz'] == true
                                  ? gradebookItemCell(
                                      data,
                                      assignment,
                                      studentId,
                                    )
                                  : '${gradebookCell(data, post, studentId)}/${assignment['points']}',
                            ),
                            onTap: () => openGradebookItem(
                              context,
                              classId,
                              data,
                              assignment,
                              studentId,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _GradebookTable extends StatefulWidget {
  const _GradebookTable({
    required this.data,
    required this.members,
    required this.classId,
    required this.onRefresh,
  });
  final GradingData data;
  final List<Json> members;
  final String classId;
  final Future<void> Function() onRefresh;
  @override
  State<_GradebookTable> createState() => _GradebookTableState();
}

class _GradebookTableState extends State<_GradebookTable> {
  final _left = ScrollController(),
      _right = ScrollController(),
      _header = ScrollController(),
      _body = ScrollController();
  bool _syncing = false;
  @override
  void initState() {
    super.initState();
    _left.addListener(() => _sync(_left, _right));
    _right.addListener(() => _sync(_right, _left));
    _header.addListener(() => _sync(_header, _body));
    _body.addListener(() => _sync(_body, _header));
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients) {
      return;
    }
    _syncing = true;
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    _syncing = false;
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    _header.dispose();
    _body.dispose();
    super.dispose();
  }

  Widget _cell(String text, {bool mint = false, VoidCallback? tap}) => SizedBox(
    width: 140,
    height: 72 * MediaQuery.textScalerOf(context).scale(1),
    child: Material(
      color: mint ? FiloColors.mint : FiloColors.surface,
      child: InkWell(
        onTap: tap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: FiloColors.border),
              right: BorderSide(color: FiloColors.border),
            ),
          ),
          child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 140,
        child: Column(
          children: [
            _cell('Student', mint: true),
            Expanded(
              child: ListView.builder(
                controller: _left,
                itemExtent: 72 * MediaQuery.textScalerOf(context).scale(1),
                itemCount: widget.members.length,
                itemBuilder: (_, i) =>
                    _cell(gradebookName(widget.members[i]), mint: true),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Column(
          children: [
            SingleChildScrollView(
              controller: _header,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final assignment in widget.data.items)
                    _cell(assignment['title'].toString()),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _body,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: widget.data.items.length * 140.0,
                  child: RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView.builder(
                      controller: _right,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemExtent:
                          72 * MediaQuery.textScalerOf(context).scale(1),
                      itemCount: widget.members.length,
                      itemBuilder: (_, i) => Row(
                        children: [
                          for (final assignment in widget.data.items)
                            _cell(
                              gradebookItemCell(
                                widget.data,
                                assignment,
                                widget.members[i]['student_id'].toString(),
                              ),
                              tap: () => openGradebookItem(
                                context,
                                widget.classId,
                                widget.data,
                                assignment,
                                widget.members[i]['student_id'].toString(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class GradebookOfflineBanner extends StatelessWidget {
  const GradebookOfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: FiloColors.warning,
    padding: const EdgeInsets.all(12),
    child: const Text('Offline · Showing cached grades. Read-only.'),
  );
}

class GradebookRetry extends StatelessWidget {
  const GradebookRetry({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            "Couldn't refresh grades. Cached grades may be out of date.",
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class GradebookSkeleton extends StatelessWidget {
  const GradebookSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: 6,
    itemBuilder: (_, _) => Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FiloColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
