import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_cancellation.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/study/application/study_summary_session.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_summary_usage.dart';
import 'package:flutter_test/flutter_test.dart';

class SummaryRepositoryFixture extends StudySummaryRepository {
  SummaryRepositoryFixture(super.db);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> save(
    String notebookId,
    String content, {
    StudySummaryUsage? usage,
    bool Function()? canCommit,
  }) async {
    await gate?.future;
    if (fail) throw StateError('Private synthetic disk failure');
    await super.save(notebookId, content, usage: usage, canCommit: canCommit);
  }
}

void main() {
  late AppDatabase db;
  late SummaryRepositoryFixture repo;
  late StudySummarySession session;
  late StudentAiClient client;
  late AiRequestGuard guard;
  late String notebook;
  late StudyAiInvoke invoke;
  var current = true, online = true, calls = 0;
  var sourceText = 'Source overview';
  Map<String, dynamic>? submitted;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2026, 10, 31);
    db = AppDatabase(NativeDatabase.memory(), now: () => now);
    repo = SummaryRepositoryFixture(db);
    notebook = await NotebookRepository(db).create('Summary');
    sourceText = 'Source overview';
    online = current = true;
    calls = 0;
    submitted = null;
    guard = AiRequestGuard();
    invoke = (_, body, _) async => {
      'answer': '**Overview**\n- Main idea',
      'mode': 'files',
      'truncated': false,
    };
    client = StudentAiClient(
      invoke: (function, body, abort) {
        calls++;
        submitted = body;
        return invoke(function, body, abort);
      },
      loadSources: (_) async => [
        StudyAiSource(key: 'att:source', name: 'Lesson.txt', text: sourceText),
      ],
      isOnline: () => online,
      currentAccount: () => current ? 'owner' : 'other',
      guard: guard,
    );
    session = StudySummarySession(
      notebookId: notebook,
      repository: repo,
      client: client,
      isCurrent: () => current,
      isOnline: () => online,
    );
  });
  tearDown(() async {
    session.dispose();
    await guard.close();
    await db.close();
  });
  Future<StudySummary?> saved() => (db.select(
    db.summaries,
  )..where((s) => s.notebookId.equals(notebook))).getSingleOrNull();

  test('generation saves content, actual usage and updated date in one notebook row', () async {
    await session.generate();
    final first = (await saved())!;
    expect(first.content, '**Overview**\n- Main idea');
    expect(
      StudySummaryUsage.decode(first.usageJson)!.retainedCharacters,
      sourceText.runes.length,
    );
    expect(submitted!['mode'], 'summary');
    expect(submitted!['messages'], isEmpty);
    expect(session.pending, isNull);
    now = now.add(const Duration(days: 1));
    invoke = (_, _, _) async => {
      'answer': 'Replacement',
      'mode': 'files',
      'truncated': false,
    };
    await session.generate();
    final second = (await saved())!;
    expect(second.content, 'Replacement');
    expect(second.createdAt.toUtc(), first.createdAt.toUtc());
    expect(second.updatedAt.toUtc(), now);
    expect(await db.select(db.summaries).get(), hasLength(1));
  });

  test(
    'old summary survives cancellation and late replies cannot replace it',
    () async {
      await repo.save(notebook, 'Old summary');
      final response = Completer<dynamic>(), started = Completer<void>();
      invoke = (_, _, _) {
        started.complete();
        return response.future;
      };
      final request = session.generate();
      await started.future;
      session.cancel();
      await request;
      response.complete({
        'answer': 'Late replacement',
        'mode': 'files',
        'truncated': false,
      });
      await Future<void>.delayed(Duration.zero);
      expect((await saved())!.content, 'Old summary');
      expect(session.pending, isNull);
      expect(session.error, studyAiMessages['CANCELLED']);
      expect(guard.isBusy, isFalse);
    },
  );

  test('save failure retains old summary; retry saves answer and usage without another request', () async {
    await repo.save(notebook, 'Old summary');
    repo.fail = true;
    await session.generate();
    expect((await saved())!.content, 'Old summary');
    expect(session.pending, isNotNull);
    expect(session.error, studySummarySaveError);
    expect(session.error, isNot(contains('Private')));
    repo.fail = false;
    await session.retrySave();
    expect(calls, 1);
    expect(session.pending, isNull);
    expect((await saved())!.usageJson, isNotNull);
  });

  test('Unicode source cap and truncation remain attached to the saved result offline', () async {
    sourceText = List.filled(40001, '😀').join();
    await session.generate();
    final usage = StudySummaryUsage.decode((await saved())!.usageJson)!;
    expect(usage.retainedCharacters, 40000);
    expect(usage.sources.single.originalCharacters, 40001);
    expect(usage.truncated, isTrue);
    expect(
      ((submitted!['sources'] as List).single['text'] as String).runes.length,
      40000,
    );
    online = false;
    expect(
      StudySummaryUsage.decode((await saved())!.usageJson)!.retainedCharacters,
      40000,
    );
    await session.generate();
    expect(calls, 1);
    expect(session.error, studyAiMessages['OFFLINE']);
  });

  test(
    'shared busy guard refuses dispatch; summaries do not have chat cooldown',
    () async {
      final blocker = Completer<void>();
      final busy = guard.run(AiCancelToken(), (_) => blocker.future);
      await session.generate();
      expect(calls, 0);
      expect(session.error, studyAiMessages['AI_IN_PROGRESS']);
      blocker.complete();
      await busy;
      guard.markChatDispatched();
      await session.generate();
      expect(calls, 1);
    },
  );

  test('all safe error mappings retain the previous summary', () async {
    await repo.save(notebook, 'Old summary');
    for (final code in [
      'NOT_ALLOWED',
      'INVALID_REQUEST',
      'NO_TEXT',
      'TOO_LARGE',
      'AI_IN_PROGRESS',
      'AI_BUSY',
      'AI_TIMEOUT',
      'AI_BAD_OUTPUT',
      'AI_UNAVAILABLE',
      'AI_BLOCKED',
    ]) {
      invoke = (_, _, _) async => {
        'error': {'code': code, 'message': 'PRIVATE'},
      };
      await session.generate();
      expect(
        session.error,
        code == 'AI_BUSY' ? studySummaryBusyMessage : studyAiMessages[code],
      );
      expect((await saved())!.content, 'Old summary');
    }
    invoke = (_, _, _) async => throw StateError('PRIVATE');
    await session.generate();
    expect(session.error, studyAiMessages['UNKNOWN']);
    invoke = (_, _, _) async => {'answer': 3};
    await session.generate();
    expect(session.error, studyAiMessages['AI_BAD_OUTPUT']);
  });

  test('account change while transport waits discards the result', () async {
    final response = Completer<dynamic>(), started = Completer<void>();
    invoke = (_, _, _) {
      started.complete();
      return response.future;
    };
    final request = session.generate();
    await started.future;
    current = false;
    response.complete({
      'answer': 'Other account must never see this',
      'mode': 'files',
      'truncated': false,
    });
    await request;
    expect(await saved(), isNull);
  });

  test(
    'losing the account during a pending local save cannot replace the old row',
    () async {
      await repo.save(notebook, 'Old summary');
      final saving = Completer<void>();
      repo.gate = Completer<void>();
      session.addListener(() {
        if (session.saving && !saving.isCompleted) saving.complete();
      });
      final request = session.generate();
      await saving.future;
      current = false;
      repo.gate!.complete();
      await request;
      expect((await saved())!.content, 'Old summary');
    },
  );

  test('invalid or old usage metadata leaves readable summaries available', () {
    expect(StudySummaryUsage.decode(null), isNull);
    expect(StudySummaryUsage.decode('{bad json'), isNull);
    expect(
      StudySummaryUsage.decode(
        '{"version":1,"server_truncated":false,"sources":[]}',
      ),
      isNull,
    );
  });

  test(
    'unreadable sources cannot silently generate a general-knowledge summary',
    () async {
      sourceText = '   ';
      await session.generate();
      expect(calls, 0);
      expect(session.error, studyAiMessages['NO_TEXT']);
      expect(await saved(), isNull);
    },
  );

  test(
    'timeout releases shared state and preserves the saved summary',
    () async {
      await repo.save(notebook, 'Old summary');
      session.dispose();
      final response = Completer<dynamic>();
      final timed = StudentAiClient(
        invoke: (_, _, _) => response.future,
        loadSources: client.loadSources,
        isOnline: () => true,
        currentAccount: () => 'owner',
        guard: guard,
        timeout: const Duration(milliseconds: 10),
      );
      session = StudySummarySession(
        notebookId: notebook,
        repository: repo,
        client: timed,
        isCurrent: () => current,
        isOnline: () => true,
      );
      await session.generate();
      expect(session.error, studyAiMessages['AI_TIMEOUT']);
      expect(guard.isBusy, isFalse);
      response.complete({
        'answer': 'Late',
        'mode': 'files',
        'truncated': false,
      });
      await Future<void>.delayed(Duration.zero);
      expect((await saved())!.content, 'Old summary');
    },
  );

  test(
    'metadata uses all submitted sources and replacement rolls back atomically',
    () async {
      final usage = StudySummaryUsage([
        const StudySourceUsage(
          key: 'att:a',
          name: 'A.txt',
          originalCharacters: 10,
          retainedCharacters: 10,
        ),
        const StudySourceUsage(
          key: 'att:b',
          name: 'B.txt',
          originalCharacters: 50000,
          retainedCharacters: 39990,
        ),
      ]);
      await repo.save(notebook, 'Old summary', usage: usage);
      var checks = 0;
      await expectLater(
        repo.save(notebook, 'New summary', canCommit: () => ++checks == 1),
        throwsStateError,
      );
      final row = (await saved())!;
      expect(row.content, 'Old summary');
      final retained = StudySummaryUsage.decode(row.usageJson)!;
      expect(retained.retainedCharacters, 40000);
      expect(retained.sources, hasLength(2));
      expect(retained.sources.last.retainedCharacters, 39990);
    },
  );

  test('physical v11 summary migrates without losing content or other account records', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-summary-migration-',
    );
    final file = File('${directory.path}/account.sqlite');
    var disk = AppDatabase(NativeDatabase(file), now: () => now);
    try {
      final id = await NotebookRepository(disk).create('Existing notebook');
      await StudySummaryRepository(disk).save(id, 'Existing offline summary');
      await disk.saveProfile(
        CacheProfilesCompanion.insert(
          id: 'owner',
          role: 'student',
          displayName: 'Owner',
        ),
      );
      await disk.customStatement(
        'ALTER TABLE summaries DROP COLUMN usage_json',
      );
      await disk.customStatement('PRAGMA user_version=11');
      await disk.close();
      disk = AppDatabase(NativeDatabase(file), now: () => now);
      final row = (await disk.select(disk.summaries).get()).single;
      expect(row.content, 'Existing offline summary');
      expect(row.usageJson, isNull);
      expect(row.createdAt.toUtc(), now);
      expect((await disk.readProfile('owner'))!.displayName, 'Owner');
      expect(
        (await disk.select(disk.notebooks).get()).single.name,
        'Existing notebook',
      );
      expect(
        (await disk.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        12,
      );
      await NotebookRepository(disk).delete(id);
      expect(await disk.select(disk.summaries).get(), isEmpty);
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });
}
