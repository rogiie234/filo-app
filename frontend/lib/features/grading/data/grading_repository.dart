import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import '../../../data/local/app_database.dart';
import '../../submissions/data/submission_repository.dart';
import '../domain/grading_models.dart';
import '../../results/data/results_cache.dart';
import '../../results/data/results_remote.dart';
import '../../results/data/quiz_grades_repository.dart';

class GradingRepository {
  GradingRepository(this.studentRepository, {required this.isOnline});
  final SubmissionRepository studentRepository;
  final bool Function() isOnline;
  AppDatabase get db => studentRepository.database;
  SupabaseClient get client => studentRepository.client;
  String get userId => studentRepository.userId;
  final Map<String, Future<void>> _pulls = {};
  bool _busy = false;
  final Set<String> _uncertain = {};

  Stream<GradingData> watch(String classId) => db
      .customSelect(
        'SELECT id FROM cache_classes WHERE id = ?',
        variables: [Variable.withString(classId)],
        readsFrom: {
          db.cacheClasses,
          db.cacheClassMembers,
          db.cachePosts,
          db.cacheSubmissions,
          db.cacheGrades,
          db.syncState,
          db.cacheResults,
          db.cacheQuizzes,
        },
      )
      .watch()
      .asyncMap((_) => read(classId));

  Future<GradingData> read(String classId) async {
    final room =
        await (db.select(db.cacheClasses)
              ..where((c) => c.id.equals(classId) & c.deletedAt.isNull()))
            .getSingleOrNull();
    if (room == null) {
      return GradingData(userId: userId);
    }
    final quizCache = QuizGradesRepository(
      ResultsCache(db, userId, () => client.auth.currentUser?.id == userId),
      SupabaseResultsRemote(client, userId),
    );
    final quizData = await quizCache.read(
      classId,
      instructor: room.ownerId == userId,
    );
    if (room.ownerId == userId) {
      final row = await db
          .customSelect(
            'SELECT payload FROM instructor_grading_snapshots WHERE class_id = ?',
            variables: [Variable.withString(classId)],
          )
          .getSingleOrNull();
      if (row == null) {
        return GradingData(userId: userId);
      }
      final payload = row.read<String>('payload');
      final data = GradingData.fromJson(
        Json.from(jsonDecode(payload) as Map),
        userId,
      );
      // Repair an existing duplicate snapshot as well as protecting new pulls.
      // This works offline and never changes server submissions or answers.
      if (jsonEncode(data.toJson()) != payload) {
        await _store(classId, data);
      }
      return GradingData.fromJson({
        ...data.toJson(),
        'quizzes': quizData?['quizzes'] ?? [],
        'quiz_attempts': quizData?['quiz_attempts'] ?? [],
        'quizzes_loaded': quizData != null,
      }, userId);
    }
    final membership =
        await (db.select(db.cacheClassMembers)..where(
              (m) =>
                  m.classId.equals(classId) &
                  m.studentId.equals(userId) &
                  m.status.equals('active'),
            ))
            .getSingleOrNull();
    if (membership == null) {
      return GradingData(userId: userId);
    }
    final posts =
        await (db.select(db.cachePosts)..where(
              (p) =>
                  p.classId.equals(classId) &
                  p.kind.equals('assignment') &
                  p.deletedAt.isNull(),
            ))
            .get();
    final work =
        await (db.select(db.cacheSubmissions)..where(
              (s) =>
                  s.studentId.equals(userId) &
                  s.postId.isIn(posts.map((p) => p.id)),
            ))
            .get();
    final grades =
        await (db.select(db.cacheGrades)..where(
              (g) =>
                  g.submissionId.isIn(work.map((s) => s.id)) &
                  g.returnedAt.isNotNull(),
            ))
            .get();
    final checkpoint =
        await (db.select(db.syncState)
              ..where((s) => s.syncedTableName.equals('submissions:$classId')))
            .getSingleOrNull();
    return GradingData(
      userId: userId,
      loaded: checkpoint != null,
      quizzes: (quizData?['quizzes'] as List? ?? [])
          .map((q) => Json.from(q as Map))
          .toList(),
      quizAttempts: (quizData?['quiz_attempts'] as List? ?? [])
          .map((q) => Json.from(q as Map))
          .toList(),
      quizzesLoaded: quizData != null,
      assignments: posts
          .map(
            (p) => <String, dynamic>{
              'id': p.id,
              'class_id': p.classId,
              'title': p.title,
              'points': p.points,
              'due_at': p.dueAt?.toIso8601String(),
            },
          )
          .toList(),
      submissions: work
          .map(
            (s) => <String, dynamic>{
              'id': s.id,
              'post_id': s.postId,
              'student_id': s.studentId,
              'status': s.status,
              'submitted_at': s.submittedAt?.toIso8601String(),
              'is_late': s.isLate,
            },
          )
          .toList(),
      grades: grades
          .map(
            (g) => <String, dynamic>{
              'submission_id': g.submissionId,
              'score': g.score,
              'feedback': g.feedback,
              'returned_at': g.returnedAt?.toIso8601String(),
            },
          )
          .toList(),
    );
  }

  // `gt` cursors require ascending order. postgrest-dart defaults to descending;
  // relying on that default rereads overlapping suffixes (6 rows become 21).
  // Keyset pages avoid both the server row cap and one request per table cell.
  Future<List<Json>> _pages(
    String key,
    dynamic Function(String? after) query,
  ) async {
    final rows = <String, Json>{};
    final cursors = <String>{};
    String? after;
    while (true) {
      final List<dynamic> page = await query(after)
          .order(key, ascending: true)
          .limit(500)
          .timeout(const Duration(seconds: 25));
      if (page.isEmpty) {
        break;
      }
      var added = false;
      for (final raw in page) {
        final row = Json.from(raw as Map);
        final id = row[key] as String;
        added |= !rows.containsKey(id);
        rows[id] = row;
      }
      final next = page.last[key] as String;
      if (!added || !cursors.add(next)) {
        throw StateError(
          'Could not finish loading grades. Refresh to try again.',
        );
      }
      after = next;
    }
    return rows.values.toList();
  }

  Future<void> refresh(String classId) => _busy
      ? Future<void>.value()
      : _pulls[classId] ??= _refresh(classId).whenComplete(() {
          _pulls.remove(classId);
        });

  Future<void> _refresh(String classId) async {
    if (!isOnline()) {
      return;
    }
    await studentRepository.posts.classes.sync();
    final room =
        await (db.select(db.cacheClasses)
              ..where((c) => c.id.equals(classId) & c.deletedAt.isNull()))
            .getSingleOrNull();
    if (room == null) {
      await _clear(classId);
      return;
    }
    if (room.ownerId != userId) {
      await _clear(classId);
      await studentRepository.sync(classId);
      await QuizGradesRepository(
        ResultsCache(db, userId, () => client.auth.currentUser?.id == userId),
        SupabaseResultsRemote(client, userId),
      ).refresh(classId);
      return;
    }
    final members = await _pages('student_id', (after) {
      var q = client
          .from('class_members')
          .select(
            'student_id,status,profiles!class_members_student_id_fkey(display_name,avatar_path)',
          )
          .eq('class_id', classId)
          .inFilter('status', ['active', 'left', 'removed']);
      if (after != null) {
        q = q.gt('student_id', after);
      }
      return q;
    });
    members.sort(
      (a, b) => '${a['profiles']?['display_name'] ?? ''}'
          .toLowerCase()
          .compareTo('${b['profiles']?['display_name'] ?? ''}'.toLowerCase()),
    );
    final posts = await _pages('id', (after) {
      var q = client
          .from('posts')
          .select('id,class_id,title,points,due_at,created_at')
          .eq('class_id', classId)
          .eq('kind', 'assignment')
          .isFilter('deleted_at', null);
      if (after != null) {
        q = q.gt('id', after);
      }
      return q;
    });
    posts.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    final work = await _pages('id', (after) {
      var q = client
          .from('submissions')
          .select(
            'id,post_id,student_id,status,submitted_at,is_late,private_comment,posts!inner(class_id,kind,deleted_at)',
          )
          .eq('posts.class_id', classId)
          .eq('posts.kind', 'assignment')
          .isFilter('posts.deleted_at', null)
          .eq('status', 'turned_in');
      if (after != null) {
        q = q.gt('id', after);
      }
      return q;
    });
    final items = await _pages('id', (after) {
      var q = client
          .from('submission_items')
          .select(
            '*,submissions!inner(status,posts!inner(class_id,kind,deleted_at))',
          )
          .eq('submissions.posts.class_id', classId)
          .eq('submissions.posts.kind', 'assignment')
          .isFilter('submissions.posts.deleted_at', null)
          .eq('submissions.status', 'turned_in')
          .isFilter('deleted_at', null);
      if (after != null) {
        q = q.gt('id', after);
      }
      return q;
    });
    final grades = await _pages('submission_id', (after) {
      var q = client
          .from('submission_grades')
          .select(
            'submission_id,score,feedback,graded_at,returned_at,submissions!inner(post_id,status,posts!inner(class_id,kind,deleted_at))',
          )
          .eq('submissions.posts.class_id', classId)
          .eq('submissions.posts.kind', 'assignment')
          .isFilter('submissions.posts.deleted_at', null)
          .eq('submissions.status', 'turned_in');
      if (after != null) {
        q = q.gt('submission_id', after);
      }
      return q;
    });
    for (final s in work) {
      s.remove('posts');
      s['comment'] = s['private_comment'];
      s['items'] =
          items
              .where((i) => i['submission_id'] == s['id'])
              .map((i) => Json.from(i)..remove('submissions'))
              .toList()
            ..sort(
              (a, b) =>
                  (a['sort_order'] as int).compareTo(b['sort_order'] as int),
            );
    }
    for (final g in grades) {
      g.remove('submissions');
    }
    await _store(
      classId,
      GradingData(
        userId: userId,
        loaded: true,
        members: members,
        assignments: posts,
        submissions: work,
        grades: grades,
      ),
    );
    await QuizGradesRepository(
      ResultsCache(db, userId, () => client.auth.currentUser?.id == userId),
      SupabaseResultsRemote(client, userId),
    ).refresh(classId);
    _uncertain.remove(classId);
  }

  Future<void> _clear(String id) async {
    await db.customStatement(
      'DELETE FROM instructor_grading_snapshots WHERE class_id = ?',
      [id],
    );
    db.notifyUpdates({TableUpdate.onTable(db.cacheClasses)});
  }

  Future<void> _store(String id, GradingData data) async {
    await db.customStatement(
      'INSERT OR REPLACE INTO instructor_grading_snapshots(class_id,payload) VALUES (?,?)',
      [id, jsonEncode(data.toJson())],
    );
    db.notifyUpdates({TableUpdate.onTable(db.cacheClasses)});
  }

  Future<T> _write<T>(String classId, Future<T> Function() action) async {
    if (!isOnline()) {
      throw StateError('Connect to the internet to save grades.');
    }
    if (_busy) {
      throw StateError('A grade update is already in progress.');
    }
    _busy = true;
    try {
      // Finish any earlier snapshot before committing a mutation.
      await _pulls[classId];
      if (_uncertain.contains(classId)) {
        await _refresh(classId);
        throw StateError('Grade refreshed. Review it before trying again.');
      }
      final room = await (db.select(
        db.cacheClasses,
      )..where((c) => c.id.equals(classId))).getSingleOrNull();
      if (room == null || room.ownerId != userId || room.deletedAt != null) {
        throw StateError('This item is no longer available.');
      }
      if (room.archivedAt != null) {
        throw StateError('This class is archived.');
      }
      final result = await action();
      return result;
    } on PostgrestException {
      rethrow;
    } on StateError {
      rethrow;
    } catch (_) {
      _uncertain.add(classId);
      throw StateError(
        "We couldn't confirm the update. Refresh to check the grade before trying again.",
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> save(
    String classId,
    String postId,
    String studentId,
    int score,
    String feedback,
  ) => _write(classId, () async {
    final data = await read(classId);
    final post = data.assignment(postId);
    if (post == null) {
      throw StateError('This item is no longer available.');
    }
    if (score < 0 || score > (post['points'] as num)) {
      throw StateError('Score must be between 0 and ${post['points']}');
    }
    if (feedback.length > 2000) {
      throw StateError('Feedback must be at most 2000 characters.');
    }
    final work = data.submission(postId, studentId);
    final result = await client
        .rpc(
          work == null ? 'grade_missing' : 'save_grade',
          params: {
            if (work == null) ...{
              'p_post': postId,
              'p_student': studentId,
            } else
              'p_submission': work['id'],
            'p_score': score,
            'p_feedback': feedback,
          },
        )
        .timeout(const Duration(seconds: 25));
    final raw = result is List ? result.single : result;
    final saved = Json.from(raw as Map);
    if (work != null) {
      data.grades.removeWhere((g) => g['submission_id'] == work['id']);
      data.grades.add(saved);
      await _store(classId, data);
    } else {
      data.submissions.add({
        'id': saved['submission_id'],
        'post_id': postId,
        'student_id': studentId,
        'status': 'turned_in',
        'submitted_at': null,
        'is_late': false,
        'items': <Json>[],
        'comment': null,
      });
      data.grades.add(saved);
      await _store(classId, data);
    }
    await _refresh(classId);
  });

  Future<int> returnOne(String classId, String submissionId) =>
      _write(classId, () async {
        final data = await read(classId);
        if (!data.submissions.any((s) => s['id'] == submissionId)) {
          throw StateError('This item is no longer available.');
        }
        final result = await client
            .rpc(
              'return_grades',
              params: {
                'p_ids': [submissionId],
              },
            )
            .timeout(const Duration(seconds: 25));
        await _refresh(classId);
        return (result as num).toInt();
      });

  Future<int> returnAll(String classId, String postId) =>
      _write(classId, () async {
        if ((await read(classId)).assignment(postId) == null) {
          throw StateError('This item is no longer available.');
        }
        final result = await client
            .rpc('return_all_graded', params: {'p_post': postId})
            .timeout(const Duration(seconds: 25));
        await _refresh(classId);
        return (result as num).toInt();
      });
}
