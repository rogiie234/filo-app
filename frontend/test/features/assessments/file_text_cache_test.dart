import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/lesson_text_extractor.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'abandoning proposals never deletes confirmed question context',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final cache = FileTextCache(db);
      const ctx = AiSourceContext(sources: [], difficulty: 'easy');
      await cache.putContext('saved', 'draft', ctx);
      await cache.putContext(
        'failed',
        'draft',
        ctx,
        state: 'failed',
        payload: '{}',
        position: 0,
      );
      await cache.putContext(
        'uncertain',
        'draft',
        ctx,
        state: 'uncertain',
        payload: '{}',
        position: 1,
      );
      await cache.abandonPending('draft');
      expect(await cache.pending('draft'), isEmpty);
      expect(await cache.contextFor('saved'), isNotNull);
    },
  );
  test('source keys accept attachment IDs and complete SHA256 digests', () {
    expect(FileTextCache.validKey('att:attachment-1'), true);
    expect(FileTextCache.validKey('sha:${'a' * 64}'), true);
    for (final key in [
      'file:1',
      'sha:abc',
      'att:../secret',
      'sha:${'G' * 64}',
    ]) {
      expect(FileTextCache.validKey(key), false);
    }
  });
  test('shared sources survive one draft cleanup; final owner removes text/context', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = FileTextCache(db);
    const result = LessonText(
      text: 'A lesson',
      sourceKey: 'att:one',
      warnings: ['Simplified table'],
    );
    await cache.save(result, 'draft-a');
    await cache.associate('draft-b', result.sourceKey);
    const context = AiSourceContext(
      sources: [SourcePrefix('att:one', 'lesson.txt', 8)],
      difficulty: 'hard',
    );
    await cache.putContext('question-a', 'draft-a', context);
    await cache.deleteForDraft('draft-a');
    expect(await cache.find('att:one'), isNotNull);
    expect(await cache.contextFor('question-a'), isNull);
    await cache.deleteForDraft('draft-b');
    expect(await cache.find('att:one'), isNull);
  });
  test(
    'restoration uses saved prefixes and refuses expired/version-changed text',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime.now();
      final cache = FileTextCache(db, now: () => now);
      await cache.save(
        const LessonText(text: '😀abc remainder', sourceKey: 'att:one'),
        'draft',
      );
      const context = AiSourceContext(
        sources: [SourcePrefix('att:one', 'lesson', 4)],
        difficulty: 'medium',
        topicFocus: 'Focus',
      );
      expect((await cache.restore(context))!.single['text'], '😀abc');
      expect(
        await cache.restore(
          const AiSourceContext(
            sources: [SourcePrefix('att:one', 'x', 1)],
            difficulty: 'easy',
            revision: 1,
          ),
        ),
        isNull,
      );
      now = now.add(const Duration(days: 31));
      expect(await cache.restore(context), isNull);
    },
  );
  test(
    'same original bytes hit cache and changing bytes changes source key',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dir = await Directory.systemTemp.createTemp('filo-text-cache');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/a.txt').writeAsString('Rule one');
      final reader = LessonTextExtractor(cache: FileTextCache(db));
      final first = await reader.extract(
        file.path,
        'txt',
        draftQuizId: 'draft',
      );
      final second = await reader.extract(
        file.path,
        'txt',
        draftQuizId: 'draft',
      );
      expect(second.sourceKey, first.sourceKey);
      expect(second.fromCache, true);
      await file.writeAsString('Rule two');
      final third = await reader.extract(
        file.path,
        'txt',
        draftQuizId: 'draft',
      );
      expect(third.sourceKey, isNot(first.sourceKey));
      expect(third.fromCache, false);
    },
  );
  test('privacy acknowledgement is account-local; binding never erases existing server context', () async {
    final db = AppDatabase(NativeDatabase.memory()),
        other = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    addTearDown(other.close);
    final cache = FileTextCache(db);
    expect(await cache.privacyAccepted(), false);
    await cache.acceptPrivacy();
    expect(await cache.privacyAccepted(), true);
    expect(await FileTextCache(other).privacyAccepted(), false);
    const ctx = AiSourceContext(sources: [], difficulty: 'easy');
    await cache.putContext('server', 'draft', ctx);
    await cache.bind('unrelated-local-id', 'server');
    expect(await cache.contextFor('server'), isNotNull);
  });
  test('v9 to v10 upgrade preserves existing profile data', () async {
    final dir = await Directory.systemTemp.createTemp('filo-ai-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      "INSERT INTO cache_profiles(id,role,display_name) VALUES('owner','instructor','Owner')",
    );
    for (final name in [
      'file_text_cache',
      'draft_text_sources',
      'ai_question_contexts',
      'ai_settings',
    ]) {
      await db.customStatement('DROP TABLE $name');
    }
    await db.customStatement('PRAGMA user_version=9');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.readProfile('owner'))!.displayName, 'Owner');
    await FileTextCache(db)
        .save(const LessonText(text: 'Rule', sourceKey: 'att:one'), 'draft');
    expect(await FileTextCache(db).find('att:one'), isNotNull);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      10,
    );
  });
  test('startup removes old/incompatible cache entries without deleting other app data', () async {
    final dir = await Directory.systemTemp.createTemp('filo-ai-expiry');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await FileTextCache(
      db,
      now: () => DateTime.now().subtract(const Duration(days: 31)),
    ).save(const LessonText(text: 'Expired', sourceKey: 'att:old'), 'draft');
    await FileTextCache(db)
        .save(const LessonText(text: 'Current', sourceKey: 'att:new'), 'draft');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await FileTextCache(db).find('att:old'), isNull);
    expect(await FileTextCache(db).find('att:new'), isNotNull);
  });
  test('per-file byte cap rejects oversize cache writes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await expectLater(
      FileTextCache(db).save(
        LessonText(text: 'a' * (lessonCacheByteCap + 1), sourceKey: 'att:one'),
        'draft',
      ),
      throwsFormatException,
    );
  });
}
