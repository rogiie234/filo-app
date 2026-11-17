import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../files/data/account_temporary_file.dart';
import '../../../core/supabase/auth_providers.dart';

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
  final _searchController = TextEditingController();
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
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final owner = ref.read(authUserIdProvider).asData?.value;
    if (owner == null) {
      setState(() => _exporting = false);
      return;
    }
    AccountTemporaryFile? temporary;
    try {
      // Capture the displayed snapshot before awaiting platform operations.
      final csv = resultsCsv(data, rows);
      final title = data.quiz['title'] as String? ?? 'Quiz';
      final filename = resultsCsvFilename(title, DateTime.now().toUtc());
      temporary = await AccountTemporaryFile.create(
        owner,
        filename,
        isCurrent: () =>
            mounted && ref.read(authUserIdProvider).asData?.value == owner,
      );
      final file = temporary.file;
      await file.writeAsString(csv, flush: true);
      if (!mounted || ref.read(authUserIdProvider).asData?.value != owner) {
        return;
      }
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
      if (temporary != null) {
        try {
          await temporary.close();
        } catch (_) {
          // The platform may retain the shared file handle temporarily.
        }
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _open(ResultSession session) => Navigator.of(context).push(
    FiloInstantRoute<void>(
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
    return FiloMotionScope(
      enabled: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${data?.quiz['title'] ?? 'Quiz results'}'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Results options',
              onSelected: (scope) {
                if (data != null) {
                  unawaited(
                    _export(
                      data,
                      scope == 'csv'
                          ? monitoringStudents(data, sort: _sort)
                          : rows,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'csv',
                  height: 48,
                  enabled:
                      data != null && data.members.isNotEmpty && !_exporting,
                  child: Text(
                    _exporting ? 'Exporting...' : 'Export CSV - All students',
                  ),
                ),
                PopupMenuItem(
                  value: 'visible',
                  height: 48,
                  enabled: data != null && rows.isNotEmpty && !_exporting,
                  child: Text('Export CSV - Current view (${rows.length})'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.file_download_outlined),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ResultsListBody(
            onRefresh: _refresh,
            loading:
                async.isLoading || state?.refreshing == true && data == null,
            offline: !online,
            error:
                state?.error ??
                (async.hasError ? "Couldn't load results. Try again." : null),
            children: [
              if (data != null) ...[
                Text(
                  'Results overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: FiloSpacing.s16),
                FiloPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            data.quiz['results_released_at'] == null
                                ? Icons.lock_outline
                                : Icons.check_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data.quiz['results_released_at'] != null
                                  ? 'Results released'
                                  : blocked == null
                                  ? 'Ready to release'
                                  : 'Before you release',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FiloSpacing.s12),
                      Text(releasedLine(data.quiz)),
                      if (state?.cached == true) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Saved results snapshot. Refresh online for the latest changes.',
                        ),
                      ],
                      if ((data.quiz['class'] as Map?)?['archived_at'] != null)
                        const Text('This class is archived.'),
                      if (data.quiz['results_released_at'] == null) ...[
                        const SizedBox(height: FiloSpacing.s12),
                        Text(
                          data.pendingEssays == null
                              ? 'Refresh to load the essay count.'
                              : '${data.pendingEssays} ${data.pendingEssays == 1 ? 'essay' : 'essays'} to grade',
                        ),
                        if (!online)
                          const Text(
                            'Connect to the internet to release results.',
                          )
                        else if (blocked != null)
                          Text(blocked),
                        const SizedBox(height: FiloSpacing.s12),
                        const Text(
                          'Releasing results closes this quiz for anyone who has not started.',
                        ),
                        const SizedBox(height: FiloSpacing.s16),
                        FiloButton(
                          label: _busy ? 'Please wait...' : 'Release results',
                          onPressed:
                              !online ||
                                  readOnly ||
                                  blocked != null ||
                                  state?.refreshing == true
                              ? null
                              : _release,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: FiloSpacing.s16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 360
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final metric in [
                          (
                            'Submitted',
                            '${data.submittedCount} of ${data.members.length}',
                          ),
                          ('In progress', '${data.inProgressCount}'),
                          ('Not started', '${data.notStarted.length}'),
                          (
                            'Average score',
                            data.average.points == null
                                ? '\u2014'
                                : '${data.average.points!.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')} points',
                          ),
                        ])
                          SizedBox(
                            width: width,
                            child: FiloPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    metric.$2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(metric.$1),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
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
                const SizedBox(height: FiloSpacing.screen),
                Text('Students', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: FiloSpacing.s12),
                TextField(
                  controller: _searchController,
                  enabled: data.members.isNotEmpty || _search.isNotEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Search students',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: FiloSpacing.s12),
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
                      FiloAnimatedChip.filter(
                        label: Text(label),
                        selected: _filter == label,
                        onSelected: data.members.isEmpty
                            ? null
                            : (_) => setState(() => _filter = label),
                      ),
                  ],
                ),
                const SizedBox(height: FiloSpacing.s12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _sort,
                  decoration: const InputDecoration(labelText: 'Sort'),
                  items: [
                    for (final label in ['Name', 'Score', 'Most leaves first'])
                      DropdownMenuItem(value: label, child: Text(label)),
                  ],
                  onChanged: data.members.isEmpty
                      ? null
                      : (value) => setState(() => _sort = value ?? 'Name'),
                ),
                const SizedBox(height: FiloSpacing.s16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${rows.length} of ${data.members.length} students shown',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Text('Open an attempt to review answers and grades.'),
                  ],
                ),
                const SizedBox(height: FiloSpacing.s12),
                if (rows.isEmpty)
                  EmptyState(
                    showMascot: false,
                    title: data.members.isEmpty
                        ? 'No active students'
                        : 'No matching students',
                    body: data.members.isEmpty
                        ? 'Results will appear after students join and take this assessment.'
                        : _search.trim().isNotEmpty
                        ? 'No matches for "$_search"; check the spelling or clear your search.'
                        : 'Choose another status or show all students.',
                    primaryAction: data.members.isEmpty
                        ? null
                        : EmptyStateAction(
                            label: 'Clear search and filters',
                            onPressed: () => setState(() {
                              _search = '';
                              _searchController.clear();
                              _filter = 'All';
                            }),
                          ),
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
                const SizedBox(height: FiloSpacing.s16),
                const Text(resultsLeaveNote),
              ],
            ],
          ),
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
    padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
    child: FiloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(status, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (onSecondChance != null)
                PopupMenuButton<String>(
                  tooltip: 'Options for $name',
                  onSelected: (_) => onSecondChance?.call(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'second-chance',
                      height: 48,
                      enabled: actionsEnabled,
                      child: const Text('Grant second chance'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(FiloRadii.medium),
            ),
            child: Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(score, style: Theme.of(context).textTheme.titleLarge),
                    if (provisional) const Text('Provisional score'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave-app count',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${leaves ?? 'Not available'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (unreleased || history) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (unreleased) const Text('Not released'),
                if (history) const Text('Previous attempt or second chance'),
              ],
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Review attempt for $name',
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('Review attempt'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
