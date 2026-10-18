import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../application/grading_providers.dart';
import 'gradebook_screen.dart';

class MyGradesScreen extends ConsumerStatefulWidget {
  const MyGradesScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<MyGradesScreen> createState() => _MyGradesScreenState();
}

class _MyGradesScreenState extends ConsumerState<MyGradesScreen> {
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

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final offline = ref.watch(connectivityProvider).asData?.value != true;
    final sync = ref.watch(gradingSyncProvider(widget.classId));
    return Scaffold(
      appBar: AppBar(title: const Text('My grades')),
      body: Column(
        children: [
          if (offline) const GradebookOfflineBanner(),
          if (sync.hasError) GradebookRetry(onRetry: _refresh),
          Expanded(
            child: ref
                .watch(gradingDataProvider(widget.classId))
                .when(
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
                    if (userId == null) {
                      return const Center(
                        child: Text('Sign in to view your grades.'),
                      );
                    }
                    final total = data.total(userId, returnedOnly: true);
                    final hasReturned = data.assignments.any((assignment) {
                      final submission = data.submission(
                        assignment['id'].toString(),
                        userId,
                      );
                      final grade = submission == null
                          ? null
                          : data.grade(submission['id'].toString());
                      return grade?['returned_at'] != null;
                    });
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Overall result'),
                                  Text(
                                    gradebookTotal(total),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                  const Text('Returned grades only'),
                                ],
                              ),
                            ),
                          ),
                          if (!hasReturned)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No grades yet.'),
                            ),
                          for (final assignment in data.assignments)
                            Builder(
                              builder: (context) {
                                final post = assignment['id'].toString();
                                final submission = data.submission(
                                  post,
                                  userId,
                                );
                                final saved = submission == null
                                    ? null
                                    : data.grade(submission['id'].toString());
                                // Keep the presentation boundary defensive even if a stale cache contains an unreturned row.
                                final grade = saved?['returned_at'] == null
                                    ? null
                                    : saved;
                                final feedback =
                                    grade?['feedback']?.toString() ?? '';
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          assignment['title'].toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          data.status(
                                            post,
                                            userId,
                                            student: true,
                                          ),
                                        ),
                                        Text(
                                          grade == null
                                              ? 'Not graded yet'
                                              : '${grade['score']}/${assignment['points']}',
                                        ),
                                        if (feedback.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(feedback),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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
}
