import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../submissions/application/submission_providers.dart';
import '../data/grading_repository.dart';
import '../domain/grading_models.dart';

final gradingRepositoryProvider = FutureProvider<GradingRepository?>((
  ref,
) async {
  final student = await ref.watch(submissionRepositoryProvider.future);
  return student == null
      ? null
      : GradingRepository(
          student,
          isOnline: () => ref.read(connectivityProvider).asData?.value == true,
        );
});

final gradingSyncProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  id,
) async {
  if (ref.watch(connectivityProvider).asData?.value != true) {
    return;
  }
  final repo = await ref.watch(gradingRepositoryProvider.future);
  await repo?.refresh(id);
});

final gradingMembersProvider = Provider.autoDispose
    .family<AsyncValue<List<Json>>, String>(
      (ref, id) =>
          ref.watch(gradingDataProvider(id)).whenData((data) => data.members),
    );
final gradingAssignmentsProvider = Provider.autoDispose
    .family<AsyncValue<List<Json>>, String>(
      (ref, id) => ref
          .watch(gradingDataProvider(id))
          .whenData((data) => data.assignments),
    );
final gradingSubmissionsProvider = Provider.autoDispose
    .family<AsyncValue<List<Json>>, String>(
      (ref, id) => ref
          .watch(gradingDataProvider(id))
          .whenData((data) => data.submissions),
    );
final gradingGradesProvider = Provider.autoDispose
    .family<AsyncValue<List<Json>>, String>(
      (ref, id) =>
          ref.watch(gradingDataProvider(id)).whenData((data) => data.grades),
    );

final gradingDataProvider = StreamProvider.autoDispose
    .family<GradingData, String>((ref, id) async* {
      // Sync has its own error state so a failed refresh cannot hide cached rows.
      ref.listen(gradingSyncProvider(id), (_, _) {});
      final listener = AppLifecycleListener(
        onResume: () => ref.invalidate(gradingSyncProvider(id)),
      );
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!ref.read(gradingSyncProvider(id)).isLoading) {
          ref.invalidate(gradingSyncProvider(id));
        }
      });
      ref.onDispose(() {
        listener.dispose();
        timer.cancel();
      });
      final repo = await ref.watch(gradingRepositoryProvider.future);
      if (repo != null) {
        yield* repo.watch(id);
      }
    });
