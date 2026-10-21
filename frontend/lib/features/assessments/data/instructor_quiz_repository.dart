import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import '../../../data/local/app_database.dart';
import '../domain/quiz_draft.dart';

class QuizReconciliationRequired implements Exception {
  const QuizReconciliationRequired(this.cause);
  final Object cause;
  @override
  String toString() =>
      'The save may be partially complete. Reload and reconcile before saving again. ($cause)';
}

class InstructorQuizRepository {
  InstructorQuizRepository(
    this.database,
    this.client,
    this.userId,
    this.isOnline,
  );
  final AppDatabase database;
  final SupabaseClient client;
  final String userId;
  final bool Function() isOnline;
  final Set<String> _saving = {};

  Future<void> _authorize(String classId, {bool writing = false}) async {
    final profile = await database.readProfile(userId);
    final room = await (database.select(
      database.cacheClasses,
    )..where((c) => c.id.equals(classId))).getSingleOrNull();
    if (profile?.role != 'instructor' ||
        profile?.deletedAt != null ||
        room == null ||
        room.ownerId != userId ||
        room.deletedAt != null) {
      throw StateError('This assessment is not available to this instructor.');
    }
    if (writing && room.archivedAt != null)
      throw StateError('This class is archived.');
  }

  void _connection() {
    if (!isOnline())
      throw StateError("You're offline. Connect to save changes.");
    if (client.auth.currentUser?.id != userId)
      throw StateError('The signed-in account changed.');
  }

  Future<void> _remoteAccess(String classId, {bool writing = false}) async {
    await _authorize(classId, writing: writing);
    _connection();
    final row = await client
        .from('classes')
        .select('owner_id,archived_at,deleted_at')
        .eq('id', classId)
        .single();
    if (row['owner_id'] != userId || row['deleted_at'] != null)
      throw StateError('This class is no longer available.');
    if (writing && row['archived_at'] != null)
      throw StateError('This class is archived.');
  }

  void _notify() =>
      database.notifyUpdates({TableUpdate.onTable(database.cacheClasses)});

  /// Null means not cached; [] is a confirmed empty list.
  Stream<List<InstructorQuizSummary>?> watchList(String classId) => database
      .customSelect(
        'SELECT payload FROM instructor_quiz_lists WHERE class_id=?',
        variables: [Variable.withString(classId)],
        readsFrom: {database.cacheClasses, database.cacheProfiles},
      )
      .watch()
      .asyncMap((rows) async {
        await _authorize(classId);
        return rows.isEmpty
            ? null
            : (jsonDecode(rows.single.read<String>('payload')) as List)
                  .map(
                    (r) => InstructorQuizSummary(
                      Map<String, dynamic>.from(r as Map),
                    ),
                  )
                  .toList();
      });
  Stream<InstructorQuiz?> watchQuiz(String classId, String quizId) => database
      .customSelect(
        'SELECT payload FROM instructor_quiz_details WHERE id=? AND class_id=?',
        variables: [Variable.withString(quizId), Variable.withString(classId)],
        readsFrom: {database.cacheClasses, database.cacheProfiles},
      )
      .watch()
      .asyncMap((rows) async {
        await _authorize(classId);
        return rows.isEmpty
            ? null
            : InstructorQuiz.fromJson(
                jsonDecode(rows.single.read<String>('payload'))
                    as Map<String, dynamic>,
              );
      });

  Future<List<Map<String, dynamic>>> refreshList(String classId) async {
    await _remoteAccess(classId);
    final all = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final page = await client
          .from('quizzes')
          .select()
          .eq('class_id', classId)
          .eq('author_id', userId)
          .isFilter('deleted_at', null)
          .order('id')
          .range(offset, offset + 199);
      all.addAll(page);
      if (page.length < 200) break;
    }
    await _authorize(classId);
    await database.transaction(() async {
      await database.customStatement(
        'INSERT OR REPLACE INTO instructor_quiz_lists(class_id,payload) VALUES (?,?)',
        [classId, jsonEncode(all)],
      );
      final details = await database
          .customSelect(
            'SELECT id FROM instructor_quiz_details WHERE class_id=?',
            variables: [Variable.withString(classId)],
          )
          .get();
      final ids = all.map((r) => r['id']).toSet();
      for (final row in details) {
        if (!ids.contains(row.read<String>('id')))
          await database.customStatement(
            'DELETE FROM instructor_quiz_details WHERE id=?',
            [row.read<String>('id')],
          );
      }
    });
    _notify();
    return all;
  }

  Future<InstructorQuiz> refreshQuiz(String classId, String quizId) async {
    await _remoteAccess(classId);
    try {
      final row = await client
          .from('quizzes')
          .select()
          .eq('id', quizId)
          .eq('class_id', classId)
          .eq('author_id', userId)
          .isFilter('deleted_at', null)
          .maybeSingle();
      if (row == null) {
        await database.customStatement(
          'DELETE FROM instructor_quiz_details WHERE id=?',
          [quizId],
        );
        _notify();
        throw StateError('This assessment is no longer available.');
      }
      final questions = <QuizQuestion>[];
      for (var offset = 0; ; offset += 200) {
        final page = await client
            .from('questions')
            .select('*,question_options(*),answer_keys(*)')
            .eq('quiz_id', quizId)
            .order('position')
            .order('id')
            .range(offset, offset + 199);
        for (final q in page) {
          final options =
              (q['question_options'] as List)
                  .map((o) => Map<String, dynamic>.from(o as Map))
                  .toList()
                ..sort(
                  (a, b) =>
                      (a['position'] as int).compareTo(b['position'] as int),
                );
          final raw = q['answer_keys'];
          final key = raw is List
              ? (raw.isEmpty
                    ? <String, dynamic>{}
                    : Map<String, dynamic>.from(raw.single as Map))
              : Map<String, dynamic>.from(raw as Map? ?? {});
          final type = q['type'];
          final index = options.indexWhere(
            (o) => o['id'] == key['correct_option_id'],
          );
          questions.add(
            QuizQuestion(
              localId: q['id'] as String,
              id: q['id'] as String,
              aiGenerated: q['ai_generated'] == true,
              options: options
                  .map(
                    (o) => QuizOption(o['id'] as String, o['text'] as String),
                  )
                  .toList(),
              payload: {
                'type': type,
                'prompt': q['prompt'],
                'points': q['points'],
                'explanation': q['explanation'],
                if (type == 'multiple_choice') ...{
                  'options': options.map((o) => o['text']).toList(),
                  'correct_option_index': index < 0 ? null : index,
                },
                if (type == 'true_false')
                  'correct_boolean': key['correct_boolean'],
                if (type == 'identification')
                  'accepted_answers': key['accepted_answers'],
              },
            ),
          );
        }
        if (page.length < 200) break;
      }
      // Refuse a mixed snapshot when settings/content changed during the reads.
      final end = await client
          .from('quizzes')
          .select('updated_at,locked_at,deleted_at')
          .eq('id', quizId)
          .single();
      if (end['updated_at'] != row['updated_at'] ||
          end['locked_at'] != row['locked_at'] ||
          end['deleted_at'] != null) {
        throw StateError(
          'The assessment changed while loading. Refresh again.',
        );
      }
      await _authorize(classId);
      final quiz = InstructorQuiz(row, questions);
      await database.transaction(() async {
        await database.customStatement(
          'INSERT OR REPLACE INTO instructor_quiz_details(id,class_id,payload) VALUES (?,?,?)',
          [quizId, classId, jsonEncode(quiz.toJson())],
        );
        final cached = await database
            .customSelect(
              'SELECT payload FROM instructor_quiz_lists WHERE class_id=?',
              variables: [Variable.withString(classId)],
            )
            .getSingleOrNull();
        if (cached != null) {
          final list = (jsonDecode(
            cached.read<String>('payload'),
          ) as List).where((r) => r['id'] != quizId).toList()..add(row);
          await database.customStatement(
            'UPDATE instructor_quiz_lists SET payload=? WHERE class_id=?',
            [jsonEncode(list), classId],
          );
        }
      });
      _notify();
      return quiz;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        await database.customStatement(
          'DELETE FROM instructor_quiz_details WHERE id=?',
          [quizId],
        );
        _notify();
      }
      rethrow;
    }
  }

  /// A failed aggregate save must be reconciled explicitly. This method never
  /// clears that guard; acceptSaved() replaces edits only after caller review.
  Future<InstructorQuiz> reconcile(QuizDraft draft) async {
    if (draft.id == null)
      throw StateError(
        'Refresh the quiz list and identify the created draft before retrying.',
      );
    final saved = await refreshQuiz(draft.classId, draft.id!);
    draft.locked = saved.locked;
    return saved;
  }

  Future<InstructorQuiz> save(QuizDraft draft) async {
    if (draft.reconciliationRequired)
      throw const QuizReconciliationRequired('Reload required');
    final token = draft.classId;
    if (!_saving.add(token)) throw StateError('A save is already in progress.');
    final snapshot = draft.editSnapshot;
    final requestSettings = copyQuizJson({
      for (final key in quizSettingFields) key: draft.settings[key],
    });
    final requestQuestions = draft.questions.map((q) => q.copy()).toList();
    final removed = draft.deletedQuestionIds;
    final changes = draft.changes;
    var wrote = false;
    try {
      await _remoteAccess(draft.classId, writing: true);

      final fresh = draft.id == null
          ? null
          : await refreshQuiz(draft.classId, draft.id!);
      draft.locked = fresh?.locked ?? false;
      if (draft.locked &&
          (changes.settings.difference({'title', 'closes_at'}).isNotEmpty ||
              changes.added.isNotEmpty ||
              changes.edited.isNotEmpty ||
              changes.deleted.isNotEmpty ||
              changes.ordering)) {
        throw StateError(
          'This quiz has already been started. Only the title and closing time can change.',
        );
      }
      final settings = requestSettings;
      for (final key in ['opens_at', 'closes_at']) {
        if (settings[key] != null) {
          final value = settings[key] as String;
          if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value))
            throw ArgumentError('Dates must contain a UTC offset.');
          settings[key] = DateTime.parse(value).toUtc().toIso8601String();
        }
      }
      if (draft.id == null) {
        wrote = true;
        final row = await client
            .from('quizzes')
            .insert({
              ...settings,
              'class_id': draft.classId,
              'author_id': userId,
            })
            .select('id')
            .single();
        draft.id = row['id'] as String;
      } else if (changes.settings.isNotEmpty) {
        wrote = true;
        await client
            .from('quizzes')
            .update({for (final key in changes.settings) key: settings[key]})
            .eq('id', draft.id!)
            .eq('author_id', userId)
            .select('id')
            .single();
      }
      if (!draft.locked) {
        for (final id in removed) {
          wrote = true;
          await client
              .from('questions')
              .delete()
              .eq('id', id)
              .eq('quiz_id', draft.id!);
        }
        for (var i = 0; i < requestQuestions.length; i++) {
          final q = requestQuestions[i];
          if (q.id == null || changes.edited.contains(q.localId)) {
            wrote = true;
            final result = await client.rpc(
              'save_question',
              params: {
                'p_quiz': draft.id,
                'p_question': {...q.payload, 'id': q.id, 'position': i},
              },
            );
            q.id = (result as Map)['question_id'] as String;
            for (final current in draft.questions) {
              if (current.localId == q.localId) current.id = q.id;
            }
          }
        }
        if (changes.ordering ||
            changes.added.isNotEmpty ||
            changes.deleted.isNotEmpty) {
          wrote = true;
          await client.rpc(
            'reorder_questions',
            params: {
              'p_quiz': draft.id,
              'p_ordered_ids': requestQuestions.map((q) => q.id!).toList(),
            },
          );
        }
      }
      final saved = await refreshQuiz(draft.classId, draft.id!);
      await refreshList(draft.classId);
      if (!quizValuesEqual(snapshot, draft.editSnapshot)) {
        draft.reconciliationRequired = true;
        throw const QuizReconciliationRequired(
          'Edits changed during saving; review the saved version before continuing.',
        );
      }
      draft.acceptSaved(saved);
      return saved;
    } catch (error) {
      if (wrote) {
        draft.reconciliationRequired = true;
        if (draft.id != null) {
          try {
            await reconcile(draft);
          } catch (_) {
            /* Preserve original failure and edits. */
          }
        }
        throw QuizReconciliationRequired(error);
      }
      rethrow;
    } finally {
      _saving.remove(token);
    }
  }

  Future<InstructorQuiz> publish(String classId, String quizId) async {
    await _remoteAccess(classId, writing: true);
    try {
      await client.rpc('publish_quiz', params: {'p_quiz': quizId});
      final saved = await refreshQuiz(classId, quizId);
      await refreshList(classId);
      return saved;
    } catch (error) {
      // Publication is server-idempotent, but first reconcile its visible state.
      try {
        await refreshQuiz(classId, quizId);
      } catch (_) {
        /* Keep cached state. */
      }
      throw QuizReconciliationRequired(error);
    }
  }
}
