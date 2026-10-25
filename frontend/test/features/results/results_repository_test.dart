import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/features/results/application/results_providers.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/results/domain/results.dart';
import 'package:filo/features/results/data/results_cache.dart';
import 'package:filo/features/results/data/results_failure.dart';
import 'package:filo/features/results/data/results_remote.dart';
import 'package:filo/features/results/data/student_results_repository.dart';
import 'package:filo/features/results/data/instructor_results_repository.dart';

class ResultsV8Database extends AppDatabase {
  ResultsV8Database(super.executor);
  @override
  int get schemaVersion => 8;
}

class FakeResultsRemote implements ResultsRemote {
  ResultJson quizRow = {
    'id': 'quiz',
    'class_id': 'class',
    'has_essay': true,
    'results_released_at': '2026-10-25T01:00:00Z',
    'class': {'archived_at': null},
  };
  ResultJson? session = {
    'session_id': 'session',
    'status': 'submitted',
    'attempt_no': 1,
    'results_released': true,
  };
  ResultJson attempt = {
    'id': 'session',
    'quiz_id': 'quiz',
    'student_id': 'student',
    'status': 'submitted',
    'attempt_no': 1,
    'grading_complete': false,
    'total_score': 7,
    'leave_count': 2,
    'profile': {'display_name': 'Ada'},
  };
  ResultJson resultRow = {
    'score': 7,
    'total_points': 10,
    'percent': 70,
    'passed': true,
    'review': null,
  };
  final calls = <(String, ResultJson)>[];
  Object? readError, writeError, resultError, monitoringError;
  Completer<void>? writeGate;
  final writeEntered = Completer<void>();
  int resultReads = 0;
  @override
  Future<ResultJson> quiz(String id, {required bool instructor}) async {
    if (readError != null) throw readError!;
    return {...quizRow};
  }

  @override
  Future<ResultJson?> mySession(String id) async {
    calls.add(('get_my_session', {'p_quiz': id}));
    return session;
  }

  @override
  Future<ResultJson> result(String id) async {
    calls.add(('get_result', {'p_session': id}));
    resultReads++;
    if (resultError != null) throw resultError!;
    return resultRow;
  }

  @override
  Future<List<ResultJson>> members(String id) async => [
    {'student_id': 'student'},
    {'student_id': 'not-started'},
  ];
  @override
  Future<ResultJson> monitoring(ResultJson quiz) async {
    if (monitoringError != null) throw monitoringError!;
    return {
      'quiz': quiz,
      'sessions': [attempt],
      'members': await members('class'),
      'second_chances': [],
    };
  }

  @override
  Future<ResultJson> detail(ResultJson quiz, String id) async => {
    'quiz': quiz,
    'session': attempt,
    'questions': [
      {
        'id': 'question',
        'type': 'essay',
        'points': 5,
        'question_options': [],
        'answer_keys': null,
        'answer': {
          'id': 'answer',
          'text_answer': 'Essay answer',
          'graded_by': null,
          'points_awarded': null,
        },
      },
    ],
  };
  @override
  Future<void> extendClosing(String quizId, DateTime closesAt) async {
    quizRow['closes_at'] = closesAt.toUtc().toIso8601String();
  }

  @override
  Future<void> write(String name, ResultJson params) async {
    calls.add((name, params));
    if (!writeEntered.isCompleted) writeEntered.complete();
    if (writeGate != null) await writeGate!.future;
    if (writeError != null) throw writeError!;
    if (name == 'grant_second_chance')
      attempt = {...attempt, 'status': 'voided'};
  }
}

void expectCall(
  (String, ResultJson) call,
  String function,
  ResultJson parameters,
) {
  expect(call.$1, function);
  expect(call.$2, parameters);
}

Future<void> seed(AppDatabase db) async {
  await db.customStatement(
    "INSERT INTO cache_profiles(id,role,display_name) VALUES ('teacher','instructor','Teacher'),('student','student','Ada')",
  );
  await db.customStatement(
    "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','teacher','Course','Section','2026','CODE')",
  );
  await db.customStatement(
    "INSERT INTO cache_class_members(id,class_id,student_id,status) VALUES ('member','class','student','active')",
  );
}

void main() {
  late AppDatabase db;
  late FakeResultsRemote remote;
  late bool online, current;
  late bool fixtureClosed;
  late StudentResultsRepository student;
  late InstructorResultsRepository instructor;
  setUp(() async {
    fixtureClosed = false;
    db = AppDatabase(NativeDatabase.memory());
    await seed(db);
    online = true;
    current = true;
    remote = FakeResultsRemote();
    student = StudentResultsRepository(
      ResultsCache(db, 'student', () => current),
      remote,
      () => online,
    );
    instructor = InstructorResultsRepository(
      ResultsCache(db, 'teacher', () => current),
      remote,
      () => online,
    );
  });
  tearDown(() async {
    if (!fixtureClosed) await db.close();
  });

  test(
    'student RPC parameters, first cache, offline read and online refresh',
    () async {
      await student.refresh('quiz');
      expect(remote.calls.length, 2);
      expectCall(remote.calls[0], 'get_my_session', {'p_quiz': 'quiz'});
      expectCall(remote.calls[1], 'get_result', {'p_session': 'session'});
      online = false;
      expect((await student.cached('quiz'))!.result!.score, 7);
      expect(remote.resultReads, 1);
      online = true;
      remote.resultRow = {...remote.resultRow, 'score': 8, 'percent': 80};
      await student.refresh('quiz');
      expect((await student.cached('quiz'))!.result!.score, 8);
    },
  );

  test(
    'unreleased, absent and voided attempts cannot expose cached results',
    () async {
      for (final session in [
        null,
        {'session_id': 'session', 'status': 'voided'},
        {
          'session_id': 'session',
          'status': 'submitted',
          'results_released': false,
        },
      ]) {
        remote.session = {
          'session_id': 'session',
          'status': 'submitted',
          'results_released': true,
        };
        await student.refresh('quiz');
        remote.session = session;
        final data = await student.refresh('quiz');
        expect(data.result, isNull);
        expect(await student.cache.result('session'), isNull);
      }
    },
  );

  test(
    'transient read failure retains cache; access denial evicts it',
    () async {
      await student.refresh('quiz');
      remote.readError = TimeoutException('connection');
      await expectLater(
        student.refresh('quiz'),
        throwsA(isA<ResultsFailure>()),
      );
      expect((await student.cached('quiz'))!.result, isNotNull);
      remote.readError = const PostgrestException(
        message: 'Class access denied',
        code: '42501',
      );
      await expectLater(
        student.refresh('quiz'),
        throwsA(isA<ResultsFailure>()),
      );
      expect(await student.cached('quiz'), isNull);
      expect(await student.cache.result('session'), isNull);
    },
  );

  test('account switch prevents writes into old account database', () async {
    current = false;
    await expectLater(student.refresh('quiz'), throwsA(isA<ResultsFailure>()));
    expect(remote.calls, isEmpty);
  });

  test('instructor lists/detail cache offline, with distinct missing and empty states', () async {
    expect(await instructor.cachedQuiz('quiz'), isNull);
    await instructor.refreshQuiz('quiz');
    await instructor.refreshDetail('quiz', 'session');
    online = false;
    expect(
      (await instructor.cachedQuiz('quiz'))!.notStarted.single['student_id'],
      'not-started',
    );
    expect(
      (await instructor.cachedDetail('quiz', 'session'))!.pendingEssays,
      1,
    );
    expect(await instructor.readOnly('class'), isTrue);
    expect((await instructor.cachedMembers('class'))!.length, 2);
  });

  test('grade RPC uses exact parameters and fractional/invalid grades never dispatch', () async {
    expect(
      await instructor.gradeEssay(
        'quiz',
        'session',
        'answer',
        0,
        feedback: 'Reviewed',
      ),
      'Grade saved.',
    );
    expectCall(remote.calls.last, 'grade_essay', {
      'p_answer': 'answer',
      'p_points': 0,
      'p_feedback': 'Reviewed',
    });
    for (final score in [1.5, -1, 6]) {
      await expectLater(
        instructor.gradeEssay('quiz', 'session', 'answer', score),
        throwsA(isA<ResultsFailure>()),
      );
    }
    expect(remote.calls.length, 1);
  });

  test(
    'release uses p_quiz and confirms refreshed release timestamp',
    () async {
      expect(await instructor.releaseResults('quiz'), 'Results released.');
      expectCall(remote.calls.single, 'release_results', {'p_quiz': 'quiz'});
      remote.quizRow['results_released_at'] = null;
      await expectLater(
        instructor.releaseResults('quiz'),
        throwsA(
          isA<ResultsFailure>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
    },
  );

  test('second chance archives current attempt and old confirmation cannot reset a new one', () async {
    expect(
      await instructor.grantSecondChance(
        'quiz',
        'student',
        expectedSessionId: 'session',
        reason: '  Phone restarted  ',
        proof: 'Shown',
      ),
      'Another attempt allowed.',
    );
    expectCall(remote.calls.single, 'grant_second_chance', {
      'p_quiz': 'quiz',
      'p_student': 'student',
      'p_reason': 'Phone restarted',
      'p_proof': 'Shown',
    });
    expect((await instructor.cachedQuiz('quiz'))!.history.length, 1);
    await expectLater(
      instructor.gradeEssay('quiz', 'session', 'answer', 1),
      throwsA(isA<ResultsFailure>()),
    );
    remote.attempt = {
      ...remote.attempt,
      'id': 'new-session',
      'status': 'in_progress',
    };
    await expectLater(
      instructor.grantSecondChance(
        'quiz',
        'student',
        expectedSessionId: 'session',
        reason: 'Phone restarted',
      ),
      throwsA(isA<ResultsFailure>()),
    );
    expect(remote.calls.length, 1);
  });

  test('offline writes do not dispatch and uncertain writes require explicit reconciliation', () async {
    online = false;
    await expectLater(
      instructor.releaseResults('quiz'),
      throwsA(
        isA<ResultsFailure>().having(
          (e) => e.message,
          'message',
          resultsOffline(ResultsAction.release),
        ),
      ),
    );
    expect(remote.calls, isEmpty);
    online = true;
    remote.writeError = TimeoutException('lost reply');
    await expectLater(
      instructor.grantSecondChance(
        'quiz',
        'student',
        expectedSessionId: 'session',
        reason: 'Phone restarted',
      ),
      throwsA(
        isA<ResultsFailure>().having((e) => e.uncertain, 'uncertain', true),
      ),
    );
    final restarted = InstructorResultsRepository(
      instructor.cache,
      remote,
      () => online,
    );
    await expectLater(
      restarted.releaseResults('quiz'),
      throwsA(isA<ResultsFailure>()),
    );
    expect(remote.calls.length, 1);
    await restarted.refreshQuiz('quiz');
    remote.writeError = null;
    await restarted.releaseResults('quiz');
    expect(remote.calls.length, 2);
  });
  test(
    'server release refusal clears an otherwise eligible cached result',
    () async {
      await student.refresh('quiz');
      remote.resultError = const PostgrestException(
        message: 'Results are not available yet',
      );
      await expectLater(
        student.refresh('quiz'),
        throwsA(isA<ResultsFailure>()),
      );
      expect((await student.cached('quiz'))!.result, isNull);
      expect((await student.cached('quiz'))!.session!.released, isFalse);
    },
  );

  test(
    'class cascade removes student snapshots and released result rows',
    () async {
      await student.refresh('quiz');
      await db.customStatement("DELETE FROM cache_classes WHERE id='class'");
      expect(await student.cached('quiz'), isNull);
      expect(await student.cache.result('session'), isNull);
    },
  );

  test(
    'failed instructor refresh preserves the last complete snapshot',
    () async {
      await instructor.refreshQuiz('quiz');
      remote.attempt = {...remote.attempt, 'total_score': 9};
      remote.monitoringError = TimeoutException('partial fetch');
      await expectLater(
        instructor.refreshQuiz('quiz'),
        throwsA(isA<ResultsFailure>()),
      );
      expect((await instructor.cachedQuiz('quiz'))!.current.single.score, 7);
    },
  );

  test(
    'provider emits cache before fresh data and offline data is read-only',
    () async {
      await student.refresh('quiz');
      remote.resultRow = {...remote.resultRow, 'score': 8, 'percent': 80};
      final container = ProviderContainer(
        overrides: [
          studentResultsRepositoryProvider.overrideWith((ref) async => student),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);
      final connection = container.listen(connectivityProvider, (_, _) {});
      addTearDown(connection.close);
      await container.read(connectivityProvider.future);
      final states = <ResultsState<StudentResultData>>[];
      final fresh = Completer<void>();
      final subscription = container.listen(studentResultProvider('quiz'), (
        _,
        next,
      ) {
        final failure = next.asError;
        if (failure != null && !fresh.isCompleted) {
          fresh.completeError(failure.error, failure.stackTrace);
          return;
        }
        final data = next.asData?.value;
        if (data == null) return;
        states.add(data);
        if (data.data?.result?.score == 8 && !fresh.isCompleted)
          fresh.complete();
      });
      addTearDown(subscription.close);
      await fresh.future;
      expect(states.first.data!.result!.score, 7);
      expect(states.first.cached, isTrue);
      expect(states.first.refreshing, isTrue);
      expect(states.last.readOnly, isTrue);
      online = false;
      final offline = ProviderContainer(
        overrides: [
          instructorResultsRepositoryProvider.overrideWith(
            (ref) async => instructor,
          ),
          connectivityProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );
      addTearDown(offline.dispose);
      final offlineSubscription = offline.listen(
        quizMonitoringProvider('quiz'),
        (_, _) {},
      );
      addTearDown(offlineSubscription.close);
      final empty = await offline.read(quizMonitoringProvider('quiz').future);
      expect(empty.loaded, isFalse);
      expect(empty.error, resultsOffline(ResultsAction.load));
      expect(empty.readOnly, isTrue);
    },
  );
  test('a pending write blocks duplicate dispatch for the quiz', () async {
    remote.writeGate = Completer<void>();
    final saving = instructor.releaseResults('quiz');
    await remote.writeEntered.future;
    await expectLater(
      instructor.releaseResults('quiz'),
      throwsA(isA<ResultsFailure>()),
    );
    expect(remote.calls.length, 1);
    remote.writeGate!.complete();
    expect(await saving, 'Results released.');
  });
  test(
    'v8 upgrade preserves account data and legacy released results',
    () async {
      await db.close();
      fixtureClosed = true;
      final directory = await Directory.systemTemp.createTemp(
        'filo-results-upgrade-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/account.sqlite');
      final old = ResultsV8Database(NativeDatabase(file));
      await seed(old);
      // Remove v9 objects to reproduce the previously deployed v8 layout.
      await old.customStatement('DROP TABLE results_snapshots');
      await old.customStatement(
        "INSERT INTO cache_results(session_id,score,total_points,percent,passed) VALUES ('legacy',7,10,70,1)",
      );
      await old.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect((await upgraded.readProfile('student'))!.displayName, 'Ada');
      final cache = ResultsCache(upgraded, 'student', () => true);
      expect((await cache.result('legacy'))!.score, 7);
      await cache.put('student:quiz', 'class', {
        'quiz': remote.quizRow,
        'session': null,
      });
      expect(await cache.read('student:quiz', instructor: false), isNotNull);
    },
  );
  test('catalog changes invalidate results without a result refresh overwriting exam state', () async {
    await db.customStatement(
      'INSERT INTO student_quiz_catalog(id,class_id,payload) VALUES(?,?,?)',
      [
        'quiz',
        'class',
        jsonEncode({'quiz': remote.quizRow, 'session': null, 'known': true}),
      ],
    );
    await student.refresh('quiz');
    expect((await student.cached('quiz'))!.result!.score, 7);
    final original = await db
        .customSelect('SELECT payload FROM student_quiz_catalog')
        .getSingle();
    expect(jsonDecode(original.read<String>('payload'))['session'], isNull);
    await db.customStatement(
      'UPDATE student_quiz_catalog SET payload=? WHERE id=?',
      [
        jsonEncode({
          'quiz': remote.quizRow,
          'session': {'session_id': 'replacement', 'status': 'in_progress'},
          'known': true,
        }),
        'quiz',
      ],
    );
    expect(await student.cached('quiz'), isNull);
    expect(await student.cache.result('session'), isNull);
  });
  test(
    'refreshes share in-flight work and settle before subsequent retries',
    () async {
      final studentFirst = student.refresh('quiz');
      expect(identical(studentFirst, student.refresh('quiz')), isTrue);
      await studentFirst;
      expect(remote.resultReads, 1);
      final instructorFirst = instructor.refreshQuiz('quiz');
      expect(
        identical(instructorFirst, instructor.refreshQuiz('quiz')),
        isTrue,
      );
      await instructorFirst;
      remote.readError = TimeoutException('read failed');
      await expectLater(
        student.refresh('quiz'),
        throwsA(isA<ResultsFailure>()),
      );
      await expectLater(
        instructor.refreshQuiz('quiz'),
        throwsA(isA<ResultsFailure>()),
      );
      remote.readError = null;
      expect((await student.refresh('quiz')).result!.score, 7);
      expect((await instructor.refreshQuiz('quiz')).current.single.score, 7);
    },
  );
  test('override accepts zero, uses exact keys, and refuses fractions without dispatch', () async {
    await instructor.overridePoints(
      'quiz',
      'session',
      'question',
      0,
      feedback: 'Reviewed',
    );
    expectCall(remote.calls.single, 'override_points', {
      'p_session': 'session',
      'p_question': 'question',
      'p_points': 0,
      'p_feedback': 'Reviewed',
    });
    await expectLater(
      instructor.overridePoints('quiz', 'session', 'question', 1.5),
      throwsA(isA<ResultsFailure>()),
    );
    expect(remote.calls.length, 1);
  });
  test(
    'closing extension changes only time and refuses released or past windows',
    () async {
      remote.quizRow['results_released_at'] = null;
      final closes = DateTime.now().toUtc().add(const Duration(hours: 2));
      expect(
        await instructor.extendClosing('quiz', closes),
        'Closing time updated.',
      );
      expect(remote.quizRow['closes_at'], closes.toIso8601String());
      await expectLater(
        instructor.extendClosing('quiz', DateTime.utc(2020)),
        throwsA(isA<ResultsFailure>()),
      );
      remote.quizRow['results_released_at'] = '2026-01-01T00:00:00Z';
      await expectLater(
        instructor.extendClosing('quiz', closes),
        throwsA(isA<ResultsFailure>()),
      );
    },
  );
}
