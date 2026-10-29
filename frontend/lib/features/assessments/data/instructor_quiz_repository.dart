import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import '../../../data/local/app_database.dart';
import '../domain/quiz_draft.dart';
import '../domain/ai_sources.dart';
import 'file_text_cache.dart';

class QuizReconciliationRequired implements Exception {
  const QuizReconciliationRequired(this.cause);
  final Object cause;
  @override
  String toString() =>
      'The save may be partially complete. Reload and reconcile before saving again. ($cause)';
}

class AiDraftSaveReport {
  const AiDraftSaveReport(this.saved, this.added, this.pending, this.uncertain);
  final InstructorQuiz saved;
  final int added, pending, uncertain;
}

class AiDraftSaveFailure implements Exception {
  const AiDraftSaveFailure(this.staged, this.cause);
  final bool staged;
  final Object cause;
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

  Future<AiDraftSaveReport> saveAiBatch(
    String classId,
    String quizId,
    List<QuizQuestion> questions,
    AiSourceContext? context,
  ) async {
    if (!_saving.add(classId))
      throw StateError('A save is already in progress.');
    final cache = FileTextCache(database);
    var added = 0;
    var staged = questions.isEmpty;
    try {
      await _authorize(classId, writing: true);
      if (client.auth.currentUser?.id != userId)
        throw StateError('The signed-in account changed.');
      if (context != null) {
        if ((await cache.pending(quizId)).isNotEmpty)
          throw StateError('Reconcile pending AI drafts first.');
        var position = 0;
        await database.transaction(() async {
          for (final question in questions) {
            await cache.putContext(
              question.localId,
              quizId,
              context,
              state: 'failed',
              payload: jsonEncode(question.toJson()),
              position: position++,
            );
          }
        });
        staged = true;
      }
      await _remoteAccess(classId, writing: true);
      var fresh = await refreshQuiz(classId, quizId);
      if (fresh.locked || fresh.row['status'] == 'published')
        throw StateError('AI questions require an unlocked draft assessment.');
      final pending = await cache.pending(quizId);
      for (final row in pending) {
        _connection();
        final key = row['question_key'] as String;
        final question = QuizQuestion.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        );
        final ctx = AiSourceContext.fromJson(
          jsonDecode(row['context'] as String) as Map<String, dynamic>,
        );
        var position = row['position'] as int;
        if (row['state'] == 'uncertain') {
          fresh = await refreshQuiz(classId, quizId);
          final atPosition = await client
              .from('questions')
              .select('id')
              .eq('quiz_id', quizId)
              .eq('position', position);
          final ids = atPosition.map((q) => q['id']).toSet();
          final matches = fresh.questions
              .where(
                (q) =>
                    ids.contains(q.id) &&
                    q.aiGenerated &&
                    quizValuesEqual(q.payload, question.payload),
              )
              .toList();
          if (matches.length == 1) {
            await cache.bind(key, matches.single.id!);
            added++;
          }
          // No match does not prove an in-flight insert cannot still commit.
          continue;
        }
        await _remoteAccess(classId, writing: true);
        fresh = await refreshQuiz(classId, quizId);
        if (fresh.locked || fresh.row['status'] == 'published') break;
        final lastPosition = await client
            .from('questions')
            .select('position')
            .eq('quiz_id', quizId)
            .order('position', ascending: false)
            .limit(1);
        position = lastPosition.isEmpty
            ? 0
            : (lastPosition.first['position'] as int) + 1;
        await cache.putContext(
          key,
          quizId,
          ctx,
          state: 'uncertain',
          payload: row['payload'] as String,
          position: position,
        );
        try {
          final response = await client
              .rpc(
                'save_question',
                params: {
                  'p_quiz': quizId,
                  'p_question': {
                    ...question.payload,
                    'id': null,
                    'position': position,
                    'ai_generated': true,
                  },
                },
              )
              .timeout(const Duration(seconds: 30));
          final id = (response as Map)['question_id'] as String;
          await cache.bind(key, id);
          added++;
        } on PostgrestException catch (error) {
          if (RegExp(r'^(22|23|42)').hasMatch(error.code ?? '') ||
              ['PGRST301', 'PGRST302'].contains(error.code)) {
            await cache.putContext(
              key,
              quizId,
              ctx,
              state: 'failed',
              payload: row['payload'] as String,
              position: position,
            );
          }
          if (['42501', 'PGRST301', 'PGRST302'].contains(error.code) ||
              error.message.toLowerCase().contains('locked') ||
              error.message.toLowerCase().contains('started'))
            break;
        } catch (_) {
          // Keep the uncertain record; a later refresh can bind it without a new insert.
        }
      }
      fresh = await refreshQuiz(classId, quizId);
      await refreshList(classId);
      final remaining = await cache.pending(quizId);
      return AiDraftSaveReport(
        fresh,
        added,
        remaining.length,
        remaining.where((r) => r['state'] == 'uncertain').length,
      );
    } catch (error) {
      // Once journaled, retry from the journal, even if the final refresh failed.
      throw AiDraftSaveFailure(staged, error);
    } finally {
      _saving.remove(classId);
    }
  }

  Future<InstructorQuiz> replaceAiQuestion(
    String classId,
    String quizId,
    String questionId,
    QuizQuestion replacement,
    AiSourceContext context,
  ) async {
    if (!_saving.add(classId))
      throw StateError('A save is already in progress.');
    try {
      await _remoteAccess(classId, writing: true);
      final fresh = await refreshQuiz(classId, quizId);
      if (fresh.locked || fresh.row['status'] == 'published')
        throw StateError('AI questions require an unlocked draft assessment.');
      final original = fresh.questions
          .where((q) => q.id == questionId)
          .firstOrNull;
      if (original == null || !original.aiGenerated)
        throw StateError('This question is no longer available.');
      if (replacement.type != original.type ||
          replacement.validationErrors().isNotEmpty)
        throw StateError('The replacement question is invalid.');
      replacement.payload['points'] = original.points;
      final position = await client
          .from('questions')
          .select('position')
          .eq('id', questionId)
          .eq('quiz_id', quizId)
          .single();
      await client
          .rpc(
            'save_question',
            params: {
              'p_quiz': quizId,
              'p_question': {
                ...replacement.payload,
                'id': questionId,
                'position': position['position'],
                'ai_generated': true,
              },
            },
          )
          .timeout(const Duration(seconds: 30));
      await FileTextCache(database).putContext(questionId, quizId, context);
      return await refreshQuiz(classId, quizId);
    } catch (e) {
      // Existing-ID updates are atomic; never remove the displayed original on failure.
      throw QuizReconciliationRequired(e);
    } finally {
      _saving.remove(classId);
    }
  }

  final Map<String, int> _listRevisions = {};
  void _changedList(String classId) =>
      _listRevisions.update(classId, (value) => value + 1, ifAbsent: () => 1);

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
    if (writing && room.archivedAt != null) {
      throw StateError('This class is archived.');
    }
  }

  void _connection() {
    if (!isOnline()) {
      throw StateError("You're offline. Connect to save changes.");
    }
    if (client.auth.currentUser?.id != userId) {
      throw StateError('The signed-in account changed.');
    }
  }

  Future<void> _remoteAccess(String classId, {bool writing = false}) async {
    await _authorize(classId, writing: writing);
    _connection();
    final row = await client
        .from('classes')
        .select('owner_id,archived_at,deleted_at')
        .eq('id', classId)
        .single()
        .timeout(const Duration(seconds: 20));
    if (row['owner_id'] != userId || row['deleted_at'] != null) {
      throw StateError('This class is no longer available.');
    }
    if (writing && row['archived_at'] != null) {
      throw StateError('This class is archived.');
    }
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
    final revision = _listRevisions[classId] ?? 0;
    await _remoteAccess(classId);
    final all = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final page = await client
          .from('quizzes')
          .select('*,questions(count)')
          .eq('class_id', classId)
          .eq('author_id', userId)
          .isFilter('deleted_at', null)
          .order('id')
          .range(offset, offset + 199)
          .timeout(const Duration(seconds: 20));
      all.addAll(
        page.map((item) {
          final row = Map<String, dynamic>.from(item);
          final counts = row.remove('questions') as List;
          row['question_count'] = counts.isEmpty
              ? 0
              : (counts.single as Map)['count'];
          return row;
        }),
      );
      if (page.length < 200) break;
    }
    await _authorize(classId);
    var committed = false;
    await database.transaction(() async {
      // A detail refresh or confirmed delete may have superseded this network
      // response while it was in flight. Never resurrect an older list row.
      if (revision != (_listRevisions[classId] ?? 0)) return;
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
        if (!ids.contains(row.read<String>('id'))) {
          await database.customStatement(
            'DELETE FROM instructor_quiz_details WHERE id=?',
            [row.read<String>('id')],
          );
        }
      }
      committed = true;
    });
    if (!committed) return refreshList(classId);
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
            .range(offset, offset + 199)
            .timeout(const Duration(seconds: 20));
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
      row['question_count'] = questions.length;
      final quiz = InstructorQuiz(row, questions);
      await database.transaction(() async {
        _changedList(classId);
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
      if (row['status'] == 'published')
        await FileTextCache(database).deleteForDraft(quizId);
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
    if (draft.id == null) {
      throw StateError(
        'Refresh the quiz list and identify the created draft before retrying.',
      );
    }
    final saved = await refreshQuiz(draft.classId, draft.id!);
    draft.locked = saved.locked;
    return saved;
  }

  Future<InstructorQuiz> save(
    QuizDraft draft, {
    void Function(String localId, String status)? onQuestionProgress,
  }) async {
    if (draft.id != null &&
        (await FileTextCache(database).pending(draft.id!))
            .any((p) => p['state'] == 'uncertain')) {
      throw const QuizReconciliationRequired(
        'An AI insert must be reconciled before saving more changes.',
      );
    }
    if (draft.reconciliationRequired) {
      throw const QuizReconciliationRequired('Reload required');
    }
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
    String? activeQuestion;
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
          if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
            throw ArgumentError('Dates must contain a UTC offset.');
          }
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
            activeQuestion = q.localId;
            onQuestionProgress?.call(q.localId, 'Saving...');
            wrote = true;
            final result = await client.rpc(
              'save_question',
              params: {
                'p_quiz': draft.id,
                'p_question': {
                  ...q.payload,
                  'id': q.id,
                  'position': i,
                  'ai_generated': q.aiGenerated,
                },
              },
            );
            q.id = (result as Map)['question_id'] as String;
            await FileTextCache(database).bind(q.localId, q.id!);
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
      for (final q in draft.questions) {
        onQuestionProgress?.call(q.localId, 'Saved');
      }
      return saved;
    } catch (error) {
      if (activeQuestion != null) {
        onQuestionProgress?.call(activeQuestion, 'Save not confirmed');
      }
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

  Future<void> deleteQuiz(String classId, String quizId) async {
    await _remoteAccess(classId, writing: true);
    final current = await client
        .from('quizzes')
        .select('locked_at')
        .eq('id', quizId)
        .eq('class_id', classId)
        .eq('author_id', userId)
        .isFilter('deleted_at', null)
        .single();
    if (current['locked_at'] != null) {
      try {
        await refreshList(classId);
      } catch (_) {
        /* The lock refusal remains authoritative. */
      }
      throw StateError(
        'A student has already started this assessment. It cannot be deleted.',
      );
    }
    try {
      await client
          .from('quizzes')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', quizId)
          .eq('class_id', classId)
          .eq('author_id', userId)
          .isFilter('locked_at', null)
          .select('id')
          .single();
    } catch (error) {
      InstructorQuiz? latest;
      try {
        await refreshList(classId);
        latest = await refreshQuiz(classId, quizId);
      } catch (_) {
        /* Keep confirmed cache. */
      }
      if (latest?.locked == true) {
        throw StateError(
          'A student has already started this assessment. It cannot be deleted.',
        );
      }
      throw QuizReconciliationRequired(error);
    }
    await FileTextCache(database).deleteForDraft(quizId);
    await database.transaction(() async {
      _changedList(classId);
      await database.customStatement(
        'DELETE FROM instructor_quiz_details WHERE id=?',
        [quizId],
      );
      final cached = await database
          .customSelect(
            'SELECT payload FROM instructor_quiz_lists WHERE class_id=?',
            variables: [Variable.withString(classId)],
          )
          .getSingleOrNull();
      if (cached != null) {
        final list = (jsonDecode(cached.read<String>('payload')) as List)
            .where((q) => q['id'] != quizId)
            .toList();
        await database.customStatement(
          'UPDATE instructor_quiz_lists SET payload=? WHERE class_id=?',
          [jsonEncode(list), classId],
        );
      }
    });
    _notify();
  }

  Future<InstructorQuiz> publish(String classId, String quizId) async {
    await _remoteAccess(classId, writing: true);
    try {
      await client.rpc('publish_quiz', params: {'p_quiz': quizId});
      await FileTextCache(database).deleteForDraft(quizId);
    } on PostgrestException {
      // An explicit RPC rejection has a known outcome; retain its validation message.
      rethrow;
    } catch (error) {
      try {
        final saved = await refreshQuiz(classId, quizId);
        if (saved.row['status'] == 'published') {
          await FileTextCache(database).deleteForDraft(quizId);
          await refreshList(classId);
          return saved;
        }
      } catch (_) {
        /* Require explicit reconciliation below. */
      }
      throw QuizReconciliationRequired(error);
    }
    try {
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
