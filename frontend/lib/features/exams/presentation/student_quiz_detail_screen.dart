import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../application/exam_providers.dart';
import '../domain/student_quiz_status.dart';
import 'student_quiz_widgets.dart';

class StudentQuizDetailScreen extends ConsumerStatefulWidget {
  const StudentQuizDetailScreen({
    super.key,
    required this.classId,
    required this.quizId,
  });
  final String classId, quizId;
  @override
  ConsumerState<StudentQuizDetailScreen> createState() =>
      _StudentQuizDetailScreenState();
}

class _StudentQuizDetailScreenState
    extends ConsumerState<StudentQuizDetailScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    try {
      if (!await ref.read(connectivityMonitorProvider).recheck() || !mounted)
        return;
      await ref.read(classSyncProvider.notifier).refresh();
      if (!mounted) return;
      ref.invalidate(studentQuizCatalogProvider);
      final repository = await ref.read(studentExamRepositoryProvider.future);
      await repository?.refreshCatalog();
    } catch (_) {
      if (mounted)
        showMessage(
          context,
          'Could not refresh. Saved work is shown. Please retry.',
        );
    }
  }

  Future<void> _handoff() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await ref.read(connectivityMonitorProvider).recheck() || !mounted)
        return;
      await ref.read(classSyncProvider.notifier).refresh();
      if (!mounted) return;
      final repository = await ref.read(studentExamRepositoryProvider.future);
      final catalog = await repository?.refreshCatalog();
      if (!mounted) return;
      ref.invalidate(studentQuizCatalogProvider);
      final quiz = catalog?.quizzes
          .where((q) => q.id == widget.quizId && q.classId == widget.classId)
          .firstOrNull;
      final room = ref
          .read(classCardsProvider)
          .asData
          ?.value
          .where((r) => r.id == widget.classId && !r.pending)
          .firstOrNull;
      if (quiz == null || room == null || catalog!.failed) {
        showMessage(context, 'Refresh to check your exam status.');
        return;
      }
      final reason = studentQuizDisabledReason(
        quiz,
        DateTime.now().toUtc(),
        archived: room.archived || quiz.json['class_archived'] == true,
        online: ref.read(connectivityProvider).asData?.value == true,
      );
      if (reason != null) {
        showMessage(context, reason);
        return;
      }
      final handler = ref.read(studentExamHandoffProvider);
      if (handler == null) {
        showMessage(
          context,
          'The exam-taking screen is not available yet. No attempt was started.',
        );
        return;
      }
      await handler(
        StudentExamHandoff(
          quizId: quiz.id,
          sessionId: quiz.session?.inProgress == true ? quiz.session!.id : null,
        ),
      );
    } catch (_) {
      if (mounted)
        showMessage(context, 'Could not check this quiz. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(studentQuizCatalogProvider);
    final rooms = ref.watch(classCardsProvider);
    final room = rooms.value
        ?.where((r) => r.id == widget.classId && !r.pending)
        .firstOrNull;
    final quiz = catalog.value?.quizzes
        .where((q) => q.id == widget.quizId && q.classId == widget.classId)
        .firstOrNull;
    final now =
        ref.watch(studentQuizNowProvider).asData?.value ??
        DateTime.now().toUtc();
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final failed =
        catalog.hasError || rooms.hasError || catalog.value?.failed == true;
    final reason = quiz == null
        ? null
        : studentQuizDisabledReason(
            quiz,
            now,
            archived:
                room?.archived == true || quiz.json['class_archived'] == true,
            online: online,
          );
    final canShow = room != null && quiz != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz detail')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (!online) ...[
                const OfflineBanner(),
                const SizedBox(height: 16),
              ],
              if (failed) ...[
                const Text(
                  'Could not refresh this quiz. Saved information is shown when available.',
                ),
                TextButton(
                  onPressed: online ? _refresh : null,
                  child: const Text('Retry'),
                ),
              ],
              if (!canShow &&
                  !failed &&
                  (catalog.isLoading ||
                      rooms.isLoading ||
                      catalog.value?.refreshing == true))
                const StudentQuizSkeleton()
              else if (!canShow)
                Text(
                  !online && catalog.value?.loaded != true
                      ? 'No saved quiz on this device. Connect to the internet and refresh.'
                      : 'This quiz is unavailable.',
                )
              else if (quiz != null && room != null) ...[
                Semantics(
                  header: true,
                  child: Text(
                    quiz.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(quiz.typeLabel)),
                    StudentQuizStatusChip(state: studentQuizState(quiz, now)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  quiz.instructions.isEmpty
                      ? 'No instructions provided.'
                      : quiz.instructions,
                ),
                const SizedBox(height: 24),
                FiloPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Time limit: ${quiz.minutes} ${quiz.minutes == 1 ? 'minute' : 'minutes'}',
                      ),
                      const SizedBox(height: 12),
                      Text('Opens: ${philippineQuizDate(quiz.opensAt)}'),
                      const SizedBox(height: 12),
                      Text('Closes: ${philippineQuizDate(quiz.closesAt)}'),
                      const SizedBox(height: 12),
                      Text('Points: ${quiz.points}'),
                    ],
                  ),
                ),
                if (studentQuizState(quiz, now).pending) ...[
                  const SizedBox(height: 16),
                  const Text('Refresh to check your exam status.'),
                  TextButton(
                    onPressed: online && !_busy ? _refresh : null,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: quiz == null || room == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (reason != null || failed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            reason ?? 'Refresh to check your exam status.',
                          ),
                        ),
                      ),
                    FiloButton(
                      onPressed: reason == null && !failed && !_busy
                          ? _handoff
                          : null,
                      busy: _busy,
                      label: _busy
                          ? 'Checking...'
                          : studentQuizState(quiz, now).action,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
