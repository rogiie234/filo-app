import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bank_question.dart';
import '../domain/quiz_draft.dart';

class QuestionBankRepository {
  QuestionBankRepository(this.client, this.userId, this.isOnline);
  final SupabaseClient client;
  final String userId;
  final bool Function() isOnline;
  Future<void> _access() async {
    if (!isOnline())
      throw StateError("You're offline. Connect to use the question bank.");
    if (client.auth.currentUser?.id != userId)
      throw StateError('The signed-in account changed.');
    final profile = await client
        .from('profiles')
        .select('role,deleted_at')
        .eq('id', userId)
        .single()
        .timeout(const Duration(seconds: 20));
    if (profile['role'] != 'instructor' || profile['deleted_at'] != null) {
      throw StateError('The question bank is available to instructors only.');
    }
  }

  Future<List<BankQuestion>> list() async {
    await _access();
    final result = <BankQuestion>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await client
          .from('bank_questions')
          .select()
          .eq('owner_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199)
          .timeout(const Duration(seconds: 20));
      result.addAll(rows.map(BankQuestion.new));
      if (rows.length < 200) return result;
    }
  }

  Future<void> save(
    String id,
    QuizQuestion question, {
    bool creating = false,
  }) async {
    if (question.validationErrors().isNotEmpty)
      throw StateError('Check this question before saving.');
    final content = BankQuestion.content(question);
    await _access();
    if (creating) {
      // Reuse the same ID after an uncertain response; never overwrite a saved copy.
      final existing = await client
          .from('bank_questions')
          .select('id,deleted_at')
          .eq('id', id)
          .eq('owner_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (existing != null) {
        if (existing['deleted_at'] != null)
          throw StateError('This saved copy was deleted.');
        return;
      }
      await client
          .from('bank_questions')
          .upsert(
            {'id': id, 'owner_id': userId, ...content},
            onConflict: 'id',
            ignoreDuplicates: true,
          )
          .timeout(const Duration(seconds: 20));
      final confirmed = await client
          .from('bank_questions')
          .select('id')
          .eq('id', id)
          .eq('owner_id', userId)
          .single()
          .timeout(const Duration(seconds: 20));
      if (confirmed['id'] != id)
        throw StateError('Save not confirmed. Retry to check again.');
    } else {
      await client
          .from('bank_questions')
          .update(content)
          .eq('id', id)
          .eq('owner_id', userId)
          .isFilter('deleted_at', null)
          .select('id')
          .single()
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<void> delete(String id) async {
    await _access();
    await client
        .from('bank_questions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('owner_id', userId)
        .select('id')
        .single()
        .timeout(const Duration(seconds: 20));
  }
}
