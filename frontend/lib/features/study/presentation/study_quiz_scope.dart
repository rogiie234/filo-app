import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../application/study_providers.dart';
import '../data/study_repositories.dart';
import 'study_widgets.dart';

/// Unmounts quiz UI while its account database is unavailable or changing.
class StudyQuizScope extends ConsumerWidget {
  const StudyQuizScope({
    super.key,
    required this.notebookId,
    required this.builder,
  });
  final String notebookId;
  final Widget Function(StudyQuizRepository) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(accountDatabaseProvider);
    final repo = ref.watch(studyQuizRepositoryProvider);
    final notebooks = ref.watch(studyNotebooksProvider);
    if (!db.isLoading &&
        !db.hasError &&
        db.asData?.value != null &&
        !repo.isLoading &&
        !repo.hasError &&
        repo.asData?.value?.db == db.requireValue &&
        !notebooks.isLoading &&
        !notebooks.hasError &&
        notebooks.requireValue.any((n) => n.id == notebookId)) {
      return builder(repo.requireValue!);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Practice quiz')),
      body: studyAsync(
        db,
        (database) => database == null
            ? const Center(child: Text('Sign in again to open your quizzes.'))
            : studyAsync(
                repo,
                (_) => studyAsync(
                  notebooks,
                  (_) => const Center(
                    child: Text('This notebook is no longer available.'),
                  ),
                  retry: () => ref.invalidate(studyNotebooksProvider),
                ),
                retry: () => ref.invalidate(studyQuizRepositoryProvider),
              ),
        retry: () => ref.invalidate(accountDatabaseProvider),
      ),
    );
  }
}
