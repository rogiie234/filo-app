import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account_deletion_journal.dart';

class DeletionRejected implements Exception {
  const DeletionRejected();
}

class AccountDeletionRepository {
  AccountDeletionRepository(this.client);
  final SupabaseClient client;
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
    if ({
              400: 'INVALID_REQUEST',
              401: 'NOT_AUTHENTICATED',
              403: 'NOT_ALLOWED',
              405: 'METHOD_NOT_ALLOWED',
              409: 'OWNED_CLASSES_EXIST',
            }[status] ==
            code &&
        code != null) {
      throw const DeletionRejected();
    }
    throw StateError('Deletion outcome unknown');
  }
}
