import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/exams/application/exam_providers.dart';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/exams/application/student_exam_repository.dart';
import 'package:filo/features/exams/data/exam_store.dart';
import 'package:filo/features/exams/domain/exam.dart';

import 'exam_test_support.dart';
import 'student_quiz_status_test.dart' show quizFixture;

Future<void> seedQuizClass(AppDatabase db) async {
  await db.customStatement(
    "INSERT INTO cache_profiles(id,role,display_name) VALUES ('teacher','instructor','Teacher')",
  );
  await db.customStatement(
    "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','teacher','Course','Section','2026','CODE')",
  );
}

void main() {
  test('confirmed submission updates cached catalog and survives stale refresh offline', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedQuizClass(db);
    var online = true;
    final remote = FakeExamRemote()..rows = [quizFixture().json];
    final store = ExamStore(db);
    final repository = StudentExamRepository(
      store: store,
      remote: remote,
      clock: FakeExamTime().clock,
      isCurrent: () => true,
      online: () => online,
    );
    addTearDown(() async {
      repository.dispose();
      await db.close();
    });
    await repository.refreshCatalog();
    await repository.recover();
    await repository.submit();
    expect(
      (await repository.cachedCatalog()).quizzes.single.session!.submitted,
      isTrue,
    );
    await store.confirmSession('quiz', ExamSession(sessionPayload()));
    await store.saveCatalog([
      quizFixture(session: ExamSession(sessionPayload())),
    ]);
    online = false;
    expect(
      (await repository.refreshCatalog()).quizzes.single.session!.submitted,
      isTrue,
    );
    expect(await store.attempts(), isEmpty);
    expect(await store.answers('session'), isEmpty);
  });

  test(
    'cosmetic class changes do not refetch catalog; access changes do',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      await seedQuizClass(db);
      final cards = StreamController<List<ClassRoom>>.broadcast();
      final remote = FakeExamRemote()
        ..rows = [quizFixture().json]
        ..currentSession = null;
      var current = true;
      final repository = StudentExamRepository(
        store: ExamStore(db),
        remote: remote,
        isCurrent: () => current,
        online: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          studentExamRepositoryProvider.overrideWith((ref) async => repository),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          classCardsProvider.overrideWith((ref) async* {
            yield [
              const ClassRoom(
                id: 'class',
                section: 'Section',
                course: 'Course',
                instructor: 'Teacher',
                color: 0xFF236B57,
              ),
            ];
            yield* cards.stream;
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await cards.close();
        repository.dispose();
        await db.close();
      });
      final ready = Completer<void>();
      final subscription = container.listen(studentQuizCatalogProvider, (
        _,
        next,
      ) {
        if (next.value?.loaded == true &&
            next.value?.refreshing == false &&
            !ready.isCompleted)
          ready.complete();
      });
      addTearDown(subscription.close);
      await ready.future;
      final calls = remote.calls.length;
      cards.add([
        const ClassRoom(
          id: 'class',
          section: 'Renamed',
          course: 'Updated course',
          instructor: 'New name',
          color: 0xFF999999,
        ),
      ]);
      await container.pump();
      expect(remote.calls.length, calls);
      expect(
        container.read(studentQuizCatalogProvider).value!.quizzes,
        hasLength(1),
      );
      final removed = Completer<void>();
      final removal = container.listen(studentQuizCatalogProvider, (_, next) {
        if (next.value?.loaded == true &&
            next.value!.quizzes.isEmpty &&
            !removed.isCompleted)
          removed.complete();
      });
      addTearDown(removal.close);
      remote.rows = [];
      cards.add([]);
      await removed.future;
      expect(remote.calls.length, greaterThan(calls));
      // A locked/changed account still cannot read the retained account cache.
      current = false;
      await expectLater(repository.cachedCatalog(), throwsA(isA<Exception>()));
    },
  );

  test('catalog keeps confirmed terminal state on status failures and retries safely', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedQuizClass(db);
    final remote = FakeExamRemote()
      ..rows = [quizFixture().json]
      ..currentSession = sessionPayload('submitted');
    var online = true, current = true;
    final repository = StudentExamRepository(
      store: ExamStore(db),
      remote: remote,
      isCurrent: () => current,
      online: () => online,
    );
    addTearDown(() async {
      repository.dispose();
      await db.close();
    });
    expect((await repository.cachedCatalog()).loaded, isFalse);
    expect(
      (await repository.refreshCatalog()).quizzes.single.session!.submitted,
      isTrue,
    );
    remote.sessionError = const SocketException('offline');
    final partial = await repository.refreshCatalog();
    expect(partial.failed, isTrue);
    expect(partial.quizzes.single.sessionKnown, isFalse);
    expect(partial.quizzes.single.session!.submitted, isTrue);
    remote.sessionError = null;
    remote.currentSession = null;
    expect(
      (await repository.refreshCatalog()).quizzes.single.sessionKnown,
      isTrue,
    );
    final count = remote.calls.length;
    online = false;
    expect((await repository.refreshCatalog()).quizzes.single.session, isNull);
    expect(remote.calls.length, count);
    online = true;
    remote.quizError = const SocketException('offline');
    final failed = await repository.refreshCatalog();
    expect(failed.loaded, isTrue);
    expect(failed.failed, isTrue);
    expect(failed.quizzes, hasLength(1));
    current = false;
    await expectLater(repository.cachedCatalog(), throwsA(isA<Exception>()));
    expect(remote.calls.any((c) => c.startsWith('start:')), isFalse);
  });

  test('version six upgrade retains answers, catalog survives reopen and class deletion', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-student-quizzes',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await seedQuizClass(db);
    await ExamStore(db).cache(ExamAttempt(examPayload()), examEpoch, examEpoch);
    await ExamStore(db).write(
      'session',
      const ExamAnswer(questionId: 'q', text: 'Keep'),
      examEpoch,
    );
    await db.customStatement('DROP TABLE student_quiz_catalog');
    await db.customStatement('DROP TABLE student_quiz_catalog_state');
    await db.customStatement('PRAGMA user_version=6');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    expect((await ExamStore(db).answers('session')).single.answer.text, 'Keep');
    await ExamStore(db).saveCatalog([
      quizFixture(session: ExamSession(sessionPayload('auto_submitted'))),
    ]);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    final cached = await ExamStore(db).catalog();
    expect(cached.loaded, isTrue);
    expect(cached.quizzes.single.session!.submitted, isTrue);
    await db.customStatement("DELETE FROM cache_classes WHERE id='class'");
    expect((await ExamStore(db).catalog()).quizzes, isEmpty);
  });
}
