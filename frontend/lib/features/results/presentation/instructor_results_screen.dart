import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/results_providers.dart';
import '../domain/results.dart';
import '../domain/results_csv.dart';
import 'attempt_detail_screen.dart';
import 'results_actions.dart';
import 'results_widgets.dart';

class InstructorResultsScreen extends ConsumerStatefulWidget {
  const InstructorResultsScreen({super.key, required this.quizId});
  final String quizId;
  @override
  ConsumerState<InstructorResultsScreen> createState() =>
      _InstructorResultsScreenState();
}

class _InstructorResultsScreenState
    extends ConsumerState<InstructorResultsScreen> {
  String _search = '', _filter = 'All', _sort = 'Name';
  bool _busy = false;
  bool _exporting = false;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy || ref.read(connectivityProvider).asData?.value != true) return;
    ref.invalidate(quizMonitoringProvider(widget.quizId));
  }

  Future<void> _release() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await releaseQuizResults(context, ref, widget.quizId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(QuizMonitoring data, List<ResultJson> rows) async {
    if (_exporting || rows.isEmpty) return;
    setState(() => _exporting = true);
    Directory? directory;
    try {
      // Capture the displayed snapshot before awaiting platform operations.
      final csv = resultsCsv(data, rows);
      final title = data.quiz['title'] as String? ?? 'Quiz';
      final filename = resultsCsvFilename(title, DateTime.now().toUtc());
      final temporary = await getTemporaryDirectory();
      directory = await temporary.createTemp('filo-results-');
      final file = File('${directory.path}/$filename');
      await file.writeAsString(csv, flush: true);
      if (!mounted) return;
      final current = ref
          .read(quizMonitoringProvider(widget.quizId))
          .asData
          ?.value
          .data;
      if (current == null) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Quiz results · $title',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) showMessage(context, "Couldn't export results. Try again.");
    } finally {
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {
          // The platform may retain the shared file handle temporarily.
        }
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _open(ResultSession session) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AttemptDetailScreen(quizId: widget.quizId, sessionId: session.id),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quizMonitoringProvider(widget.quizId));
    final state = async.asData?.value;
    final data = state?.data;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final readOnly = state?.readOnly != false || _busy;
    final blocked = data?.releaseBlocked(DateTime.now().toUtc());
    final rows = data == null
        ? <ResultJson>[]
        : monitoringStudents(
            data,
            search: _search,
            filter: _filter,
            sort: _sort,
          );
    return Scaffold(
      appBar: AppBar(
        title: Text('${data?.quiz['title'] ?? 'Quiz results'}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Results options',
            onSelected: (_) {
              if (data != null) unawaited(_export(data, rows));
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'csv',
                height: 48,
                enabled: data != null && rows.isNotEmpty && !_exporting,
                child: Text(_exporting ? 'Exporting...' : 'Export CSV'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ResultsListBody(
          onRefresh: _refresh,
          loading: async.isLoading || state?.refreshing == true && data == null,
          offline: !online,
          error:
              state?.error ??
              (async.hasError ? "Couldn't load results. Try again." : null),
          children: [
            if (data != null) ...[
              Text(releasedLine(data.quiz)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ResultSummaryTile(
                    'Submitted',
                    '${data.submittedCount} of ${data.members.length}',
                  ),
                  ResultSummaryTile('In progress', '${data.inProgressCount}'),
                  ResultSummaryTile('Not started', '${data.notStarted.length}'),
                  ResultSummaryTile(
                    'Average score',
                    data.average.points == null
                        ? '—'
                        : '${data.average.points!.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} points',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data.average.points == null)
                Text(
                  data.submittedCount == 0
                      ? 'No submitted scores yet.'
                      : 'Refresh to load submitted scores.',
                ),
              if (data.average.provisional)
                const Text(
                  'Average includes scores with essay answers not graded yet.',
                ),
              Text(
                data.pendingEssays == null
                    ? 'Refresh to load the essay count.'
                    : '${data.pendingEssays} ${data.pendingEssays == 1 ? 'essay' : 'essays'} to grade',
              ),
              if ((data.quiz['class'] as Map?)?['archived_at'] != null)
                const Text('This class is archived.'),
              if (data.quiz['results_released_at'] == null) ...[
                const SizedBox(height: 16),
                FiloButton(
                  label: _busy ? 'Please wait...' : 'Release results',
                  onPressed:
                      readOnly || blocked != null || state?.refreshing == true
                      ? null
                      : _release,
                ),
                if (!online)
                  const Text('Connect to the internet to release results.')
                else if (blocked != null)
                  Text(blocked),
              ],
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search students',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final label in [
                    'All',
                    'To grade',
                    'In progress',
                    'Not started',
                    'Submitted',
                  ])
                    FilterChip(
                      label: Text(label),
                      selected: _filter == label,
                      onSelected: (_) => setState(() => _filter = label),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: const InputDecoration(labelText: 'Sort'),
                items: [
                  for (final label in ['Name', 'Score', 'Most leaves first'])
                    DropdownMenuItem(value: label, child: Text(label)),
                ],
                onChanged: (value) => setState(() => _sort = value ?? 'Name'),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Text(
                  data.members.isEmpty
                      ? 'No active students in this class.'
                      : 'No students match your search or filter.',
                ),
              for (final member in rows)
                Builder(
                  builder: (_) {
                    final id = member['student_id'] as String;
                    final attempt = data.attemptFor(id);
                    final old =
                        data.history.where((s) => s.studentId == id).toList()
                          ..sort((a, b) => b.attempt.compareTo(a.attempt));
                    final name =
                        ((member['profile'] as Map?)?['display_name'] ?? id)
                            .toString();
                    return ResultStudentRow(
                      name: name,
                      status: quizResultStatus(
                        attempt,
                        hasEssay: data.quiz['has_essay'] == true,
                      ).label,
                      score: attempt?.submitted == true
                          ? '${attempt?.score ?? '—'}/${data.quiz['total_points']}'
                          : '—',
                      leaves: attempt?.leaves,
                      unreleased:
                          data.quiz['results_released_at'] == null &&
                          attempt?.submitted == true,
                      provisional:
                          attempt?.submitted == true &&
                          attempt?.gradingComplete != true,
                      history: data.hasHistory(id),
                      onTap: attempt != null
                          ? () => _open(attempt)
                          : old.isNotEmpty
                          ? () => _open(old.first)
                          : null,
                      actionsEnabled: !readOnly,
                      onSecondChance: () =>
                          openSecondChance(context, widget.quizId, id),
                    );
                  },
                ),
              const SizedBox(height: 16),
              const Text(resultsLeaveNote),
            ],
          ],
        ),
      ),
    );
  }
}

class ResultStudentRow extends StatelessWidget {
  const ResultStudentRow({
    super.key,
    required this.name,
    required this.status,
    required this.score,
    this.leaves,
    required this.unreleased,
    required this.provisional,
    required this.history,
    this.onTap,
    this.onSecondChance,
    this.actionsEnabled = true,
  });
  final String name, status, score;
  final int? leaves;
  final bool unreleased, provisional, history;
  final VoidCallback? onTap, onSecondChance;
  final bool actionsEnabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FiloPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ResultStatusChip(status),
                      Text(score),
                      Semantics(
                        label: 'Leave-app count ${leaves ?? 'not available'}',
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.exit_to_app, size: 20),
                              Text(' ${leaves ?? '—'}'),
                            ],
                          ),
                        ),
                      ),
                      if (history)
                        const Chip(
                          avatar: Icon(Icons.history, size: 18),
                          label: Text('Attempts'),
                        ),
                    ],
                  ),
                  if (unreleased) const Text('Not released'),
                  if (provisional) const Text('Provisional score'),
                ],
              ),
            ),
          ),
          if (onSecondChance != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: actionsEnabled ? onSecondChance : null,
                child: const Text('Grant second chance'),
              ),
            ),
        ],
      ),
    ),
  );
}
