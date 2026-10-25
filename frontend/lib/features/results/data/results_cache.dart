import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import '../domain/results.dart';
import 'results_failure.dart';

class ResultsCache {
  ResultsCache(this.db, this.userId, this.isCurrent);
  final AppDatabase db;
  final String userId;
  final bool Function() isCurrent;

  void checkAccount() {
    if (!isCurrent()) throw resultsUnavailable;
  }

  Future<bool> authorize(String classId, {required bool instructor}) async {
    checkAccount();
    final profile = await db.readProfile(userId);
    final room = await (db.select(
      db.cacheClasses,
    )..where((c) => c.id.equals(classId))).getSingleOrNull();
    var allowed =
        profile != null &&
        profile.deletedAt == null &&
        room != null &&
        room.deletedAt == null;
    if (instructor) {
      allowed =
          allowed && profile?.role == 'instructor' && room?.ownerId == userId;
    } else {
      final member =
          await (db.select(db.cacheClassMembers)..where(
                (m) =>
                    m.classId.equals(classId) &
                    m.studentId.equals(userId) &
                    m.status.equals('active'),
              ))
              .getSingleOrNull();
      allowed = allowed && profile?.role == 'student' && member != null;
    }
    checkAccount();
    if (!allowed) {
      await evictClass(classId);
      throw resultsUnavailable;
    }
    return room!.archivedAt != null;
  }

  Future<ResultJson?> read(String key, {required bool instructor}) async {
    checkAccount();
    final rows = await db
        .customSelect(
          'SELECT class_id,payload FROM results_snapshots WHERE id=?',
          variables: [Variable(key)],
        )
        .get();
    if (rows.isEmpty) return null;
    await authorize(
      rows.single.read<String>('class_id'),
      instructor: instructor,
    );
    return resultJson(jsonDecode(rows.single.read<String>('payload')));
  }

  Future<void> put(String key, String classId, ResultJson payload) async {
    checkAccount();
    await db.customStatement(
      'INSERT INTO results_snapshots(id,class_id,payload) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET class_id=excluded.class_id,payload=excluded.payload',
      [key, classId, jsonEncode(payload)],
    );
    notify();
  }

  void notify() => db.notifyUpdates({TableUpdate.onTable(db.cacheResults)});

  Stream<int> get changes => db
      .customSelect(
        'SELECT id FROM results_snapshots',
        readsFrom: {
          db.cacheResults,
          db.cacheClasses,
          db.cacheClassMembers,
          db.cacheProfiles,
          db.cacheQuizzes,
        },
      )
      .watch()
      .map((rows) => rows.length);

  Future<void> evictClass(String classId) async {
    checkAccount();
    await db.transaction(() async {
      final rows = await db
          .customSelect(
            'SELECT id,payload FROM results_snapshots WHERE class_id=?',
            variables: [Variable(classId)],
          )
          .get();
      for (final row in rows) {
        if (!row.read<String>('id').startsWith('student:')) continue;
        final session = resultJson(
          jsonDecode(row.read<String>('payload')),
        )['session'];
        if (session != null)
          await removeResult(ResultSession(resultJson(session)).id);
      }
      await db.customStatement(
        'DELETE FROM results_snapshots WHERE class_id=?',
        [classId],
      );
    });
    notify();
  }

  Future<void> remove(String key) async {
    checkAccount();
    await db.customStatement('DELETE FROM results_snapshots WHERE id=?', [key]);
    notify();
  }

  Future<void> removeResult(String sessionId) async {
    checkAccount();
    await (db.delete(
      db.cacheResults,
    )..where((r) => r.sessionId.equals(sessionId))).go();
  }

  Future<ReleasedResult?> result(String sessionId) async {
    checkAccount();
    final row = await (db.select(
      db.cacheResults,
    )..where((r) => r.sessionId.equals(sessionId))).getSingleOrNull();
    return row == null
        ? null
        : ReleasedResult(
            score: row.score,
            totalPoints: row.totalPoints,
            percent: row.percent,
            passed: row.passed,
            review: row.review == null
                ? null
                : resultRows(jsonDecode(row.review!)),
          );
  }

  Future<void> saveResult(String sessionId, ReleasedResult result) async {
    checkAccount();
    await db
        .into(db.cacheResults)
        .insertOnConflictUpdate(
          CacheResult(
            sessionId: sessionId,
            score: result.score,
            totalPoints: result.totalPoints,
            percent: result.percent,
            passed: result.passed,
            review: result.review == null ? null : jsonEncode(result.review),
          ),
        );
  }

  Future<StudentResultData?> student(String quizId) async {
    final snapshot = await read('student:$quizId', instructor: false);
    if (snapshot == null) return null;
    final session = snapshot['session'] == null
        ? null
        : ResultSession(resultJson(snapshot['session']));
    // Catalog refresh may have observed a replacement before this feature refreshes.
    final catalog = await db
        .customSelect(
          'SELECT payload FROM student_quiz_catalog WHERE id=?',
          variables: [Variable(quizId)],
        )
        .get();
    if (catalog.isNotEmpty) {
      final value = resultJson(
        jsonDecode(catalog.single.read<String>('payload')),
      );
      final current = value['session'] as Map?;
      final signature = jsonEncode({
        'known': value['known'],
        'session': current,
      });
      if (signature != snapshot['catalog_session'] &&
          value['known'] == true &&
          session != null &&
          (current == null ||
              current['session_id'] != session.id ||
              current['status'] == 'voided' ||
              current['results_released'] != true)) {
        await removeResult(session.id);
        await remove('student:$quizId');
        return null;
      }
    }
    final eligible =
        session != null &&
        !session.voided &&
        session.submitted &&
        session.released;
    return StudentResultData(
      resultJson(snapshot['quiz']),
      session?.voided == true ? null : session,
      eligible ? await result(session.id) : null,
    );
  }

  Future<void> saveStudent(
    ResultJson quiz,
    ResultSession? session,
    ReleasedResult? result,
  ) async {
    await db.transaction(() async {
      checkAccount();
      final key = 'student:${quiz['id']}';
      final old = await read(key, instructor: false);
      if (old?['session'] != null) {
        final previous = ResultSession(resultJson(old!['session']));
        if (previous.id != session?.id || result == null)
          await removeResult(previous.id);
      }
      if (session != null && result != null)
        await saveResult(session.id, result);
      // Observe catalog changes without overwriting the exam repository's state.
      final rows = await db
          .customSelect(
            'SELECT payload FROM student_quiz_catalog WHERE id=?',
            variables: [Variable(quiz['id'] as String)],
          )
          .get();
      final catalog = rows.isEmpty
          ? null
          : resultJson(jsonDecode(rows.single.read<String>('payload')));
      await put(key, quiz['class_id'] as String, {
        'quiz': quiz,
        'session': session?.json,
        'catalog_session': catalog == null
            ? null
            : jsonEncode({
                'known': catalog['known'],
                'session': catalog['session'],
              }),
      });
    });
    notify();
  }
}
