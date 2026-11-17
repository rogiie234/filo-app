import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../application/results_providers.dart';
import '../domain/results.dart';
import 'results_widgets.dart';

class StudentResultsScreen extends ConsumerWidget {
  const StudentResultsScreen({super.key, required this.quizId});
  final String quizId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentResultProvider(quizId));
    final data = state.asData?.value;
    final result = data?.data?.result;
    final quiz = data?.data?.quiz;
    Future<void> refresh() async {
      ref.invalidate(studentResultProvider(quizId));
    }

    return FiloMotionScope(
      enabled: false,
      child: Scaffold(
        appBar: AppBar(title: Text('${quiz?['title'] ?? 'Results'}')),
        body: SafeArea(
          child: ResultsListBody(
            onRefresh: refresh,
            offline: ref.watch(connectivityProvider).asData?.value != true,
            loading:
                state.isLoading ||
                data?.refreshing == true && data?.data == null,
            error:
                data?.error ??
                (state.hasError ? "Couldn't load results. Try again." : null),
            children: [
              if (result != null) ...[
                Semantics(
                  header: true,
                  child: Text(
                    '${result.score} of ${result.totalPoints} ${result.totalPoints == 1 ? 'point' : 'points'}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Text(
                  '${result.percent}%',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (quiz?['passing_percent'] != null && result.passed != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ResultStatusChip(
                      result.passed! ? 'Passed' : 'Not passed',
                    ),
                  ),
                const SizedBox(height: FiloSpacing.screen),
                if (result.review == null)
                  const Text(resultsScoreOnly)
                else
                  for (final entry in result.review!.indexed)
                    ResultQuestionCard(
                      question: entry.$2,
                      number: entry.$1 + 1,
                    ),
              ] else if (data?.data != null)
                Text(studentResultMessage(data!.data!)),
            ],
          ),
        ),
      ),
    );
  }
}

String studentResultMessage(StudentResultData data) {
  final closes = DateTime.tryParse('${data.quiz['closes_at'] ?? ''}');
  return data.session == null &&
          closes != null &&
          !closes.isAfter(DateTime.now().toUtc())
      ? 'You did not take this quiz.'
      : resultsWaiting;
}

class StudentResultsEntry extends ConsumerWidget {
  const StudentResultsEntry({super.key, required this.quizId});
  final String quizId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentResultProvider(quizId));
    final data = state.asData?.value;
    if (data?.data?.result != null) {
      return FiloButton(
        label: 'View results',
        onPressed: () => Navigator.of(context).push(
          FiloInstantRoute<void>(
            builder: (_) => StudentResultsScreen(quizId: quizId),
          ),
        ),
      );
    }
    final loading = state.isLoading || data?.refreshing == true;
    final failed = state.hasError || data?.error != null;
    final message =
        data?.error ??
        (state.hasError ? "Couldn't load results. Try again." : null) ??
        (data?.data == null
            ? resultsWaiting
            : studentResultMessage(data!.data!));
    return Padding(
      padding: const EdgeInsets.only(top: FiloSpacing.s16),
      child: FiloPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ExcludeSemantics(
                child: Icon(
                  failed ? Icons.info_outline : Icons.hourglass_bottom_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: FiloSpacing.s16),
            Semantics(
              header: true,
              child: Text(
                loading
                    ? 'Checking results'
                    : failed
                    ? 'Results unavailable'
                    : 'Results not available yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: FiloSpacing.s8),
            Semantics(
              liveRegion: true,
              child: Text(loading ? 'Loading results...' : message),
            ),
            const SizedBox(height: FiloSpacing.s16),
            FiloButton(
              secondary: true,
              label: loading ? 'Checking...' : 'Refresh',
              icon: Icons.refresh,
              onPressed: loading
                  ? null
                  : () => ref.invalidate(studentResultProvider(quizId)),
            ),
          ],
        ),
      ),
    );
  }
}
