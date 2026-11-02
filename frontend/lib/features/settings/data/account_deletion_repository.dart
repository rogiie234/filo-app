import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account_deletion_journal.dart';

class DeletionRejected implements Exception {
  const DeletionRejected();
}

class OwnedClassesExist extends DeletionRejected {
  const OwnedClassesExist(this.count);
  final int? count;
}

class InstructorDeletionEligibility {
  const InstructorDeletionEligibility(
    this.count, {
    this.hasRecoveryClasses = false,
  });
  final int count;
  final bool hasRecoveryClasses;
}

class AccountDeletionRepository {
  AccountDeletionRepository(this.client);
  final SupabaseClient client;
  Future<InstructorDeletionEligibility> eligibility(
    String id, {
    bool Function()? isCurrent,
  }) async {
    final count = await client
        .rpc('owned_class_count')
        .timeout(const Duration(seconds: 20));
    if (isCurrent != null && !isCurrent())
      throw StateError('Obsolete eligibility');
    if (count is! int || count < 0)
      throw const FormatException('Invalid class count');
    if (count > 0) return InstructorDeletionEligibility(count);
    final rows = await client
        .from('classes')
        .select('id')
        .eq('owner_id', id)
        .not('deleted_at', 'is', null)
        .limit(1)
        .timeout(const Duration(seconds: 20));
    return InstructorDeletionEligibility(
      0,
      hasRecoveryClasses: rows.isNotEmpty,
    );
  }

  Future<DeletionStage> request() async {
    int status;
    dynamic data;
    try {
      final response = await client.functions
          .invoke(
            'delete-account',
            body: <String, dynamic>{},
            method: HttpMethod.post,
          )
          .timeout(const Duration(seconds: 100));
      status = response.status;
      data = response.data;
    } on FunctionException catch (error) {
      status = error.status;
      data = error.details;
    }
    if (status == 200 && data is Map && data['status'] == 'deleted')
      return DeletionStage.cleanup;
    if (status == 202 && data is Map && data['status'] == 'pending')
      return DeletionStage.pending;
    final error = data is Map ? data['error'] : null;
    final code = error is Map ? error['code'] : null;
    if (status == 409 && code == 'OWNED_CLASSES_EXIST') {
      final count = error['count'];
      throw OwnedClassesExist(count is int && count > 0 ? count : null);
    }
    if ({
              400: 'INVALID_REQUEST',
              401: 'NOT_AUTHENTICATED',
              403: 'NOT_ALLOWED',
              405: 'METHOD_NOT_ALLOWED',
            }[status] ==
            code &&
        code != null) {
      throw const DeletionRejected();
    }
    throw StateError('Deletion outcome unknown');
  }
}
