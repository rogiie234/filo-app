import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../data/local/app_database.dart';
import '../../posts/application/post_providers.dart';
import '../data/submission_repository.dart';
import '../data/submission_work_repository.dart';

final submissionWorkRepositoryProvider =
    FutureProvider<SubmissionWorkRepository?>((ref) async {
      final repository = await ref.watch(submissionRepositoryProvider.future);
      return repository == null ? null : SubmissionWorkRepository(repository);
    });

final submissionRepositoryProvider = FutureProvider<SubmissionRepository?>((
  ref,
) async {
  final posts = await ref.watch(postRepositoryProvider.future);
  return posts == null
      ? null
      : SubmissionRepository(
          posts,
          ref.watch(supabaseClientProvider),
          isOnline: () => ref.read(connectivityProvider).asData?.value == true,
        );
});

final classSubmissionsProvider = StreamProvider.autoDispose
    .family<List<CacheSubmission>, String>((ref, classId) async* {
      final repository = await ref.watch(submissionRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchSubmissions(classId);
    });

final submissionItemsProvider = StreamProvider.autoDispose
    .family<List<CacheSubmissionItem>, String>((ref, submissionId) async* {
      final repository = await ref.watch(submissionRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchItems(submissionId);
    });

final returnedGradesProvider = StreamProvider.autoDispose
    .family<List<CacheGrade>, String>((ref, classId) async* {
      final repository = await ref.watch(submissionRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      yield* repository.watchReturnedGrades(classId);
    });

final submissionSyncProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  classId,
) async {
  if (ref.watch(connectivityProvider).asData?.value != true) {
    return;
  }
  final repository = await ref.watch(submissionRepositoryProvider.future);
  if (ref.mounted) {
    await repository?.sync(classId);
  }
});

final submissionSyncLifecycleProvider = Provider.autoDispose
    .family<void, String>((ref, classId) {
      ref.listen(submissionSyncProvider(classId), (_, _) {});
      var foreground = true;
      void pull() => ref.invalidate(submissionSyncProvider(classId));
      final listener = AppLifecycleListener(
        onResume: () {
          foreground = true;
          pull();
        },
        onPause: () => foreground = false,
        onHide: () => foreground = false,
      );
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (foreground &&
            !ref.read(submissionSyncProvider(classId)).isLoading) {
          pull();
        }
      });
      ref.onDispose(() {
        timer.cancel();
        listener.dispose();
      });
    });
