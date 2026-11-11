import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bank_question.dart';
import '../domain/quiz_draft.dart';

class QuestionBankRepository {
  QuestionBankRepository(this.client, this.userId, this.isOnline);
  final SupabaseClient client;
  final String userId;
  final bool Function() isOnline;
  Future<void> _access() async {
    if (!isOnline()) {
      throw StateError("You're offline. Connect to use the question bank.");
    }
    if (client.auth.currentUser?.id != userId) {
      throw StateError('The signed-in account changed.');
    }
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

  Future<List<BankQuestion>> list({String? course}) async {
    await _access();
    final result = <BankQuestion>[];
    String? afterCreated, afterId;
    while (true) {
      var query = client
          .from('bank_questions')
          .select()
          .eq('owner_id', userId)
          .isFilter('deleted_at', null);
      if (course != null) {
        if (course.trim().isEmpty) throw StateError('Choose a course.');
        query = query.eq('course_key', course.trim().toLowerCase());
      }
      if (afterId != null) {
        query = query.or(
          'created_at.lt.$afterCreated,and(created_at.eq.$afterCreated,id.gt.$afterId)',
        );
      }
      final rows = await query
          .order('created_at', ascending: false)
          .order('id', ascending: true)
          .limit(200)
          .timeout(const Duration(seconds: 20));
      result.addAll(rows.map(BankQuestion.new));
      if (rows.isEmpty) return result;
      afterCreated = rows.last['created_at'] as String;
      afterId = rows.last['id'] as String;
    }
  }

  Future<void> save(
    String id,
    QuizQuestion question, {
    bool creating = false,
    String? course,
  }) async {
    if (question.validationErrors().isNotEmpty) {
      throw StateError('Check this question before saving.');
    }
    if ((creating && course == null) ||
        (course != null &&
            (course.trim().isEmpty || course.trim().length > 120))) {
      throw StateError('Choose a course of 1 to 120 characters.');
    }
    final content = {
      ...BankQuestion.content(question),
      if (course != null) 'course': course.trim(),
    };
    await _access();
    if (creating) {
      // Reuse the same ID after an uncertain response; never overwrite a saved copy.
      final existing = await client
          .from('bank_questions')
          .select('id,deleted_at,course_key')
          .eq('id', id)
          .eq('owner_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (existing != null) {
        if (existing['deleted_at'] != null) {
          throw StateError('This saved copy was deleted.');
        }
        if (existing['course_key'] != course!.trim().toLowerCase()) {
          throw StateError('Saved question belongs to another course.');
        }
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
          .select('id,course_key')
          .eq('id', id)
          .eq('owner_id', userId)
          .single()
          .timeout(const Duration(seconds: 20));
      if (confirmed['id'] != id ||
          confirmed['course_key'] != course!.trim().toLowerCase()) {
        throw StateError('Save not confirmed. Retry to check again.');
      }
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
