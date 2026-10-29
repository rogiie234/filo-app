import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';

import '../../../data/local/app_database.dart';
import '../domain/ai_sources.dart';

const lessonExtractorRevision = 2;
const lessonCacheByteCap = 2 * 1024 * 1024;

class FileTextCache {
  FileTextCache(this.db, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() now;
  Future<bool> privacyAccepted() async =>
      (await db
              .customSelect(
                "SELECT value FROM ai_settings WHERE key='privacy_v1' AND value='accepted'",
              )
              .get())
          .isNotEmpty;
  Future<void> acceptPrivacy() => db.customStatement(
    "INSERT OR REPLACE INTO ai_settings(key,value) VALUES('privacy_v1','accepted')",
  );
  static bool validKey(String key) =>
      RegExp(r'^(att:[a-zA-Z0-9-]+|sha:[0-9a-f]{64})$').hasMatch(key);

  Future<LessonText?> find(String key) async {
    if (!validKey(key)) throw const FormatException('Invalid source key');
    final rows = await db
        .customSelect(
          'SELECT * FROM file_text_cache WHERE source_key=? AND revision=? AND extracted_at>=?',
          variables: [
            Variable(key),
            Variable(lessonExtractorRevision),
            Variable(
              now()
                  .toUtc()
                  .subtract(const Duration(days: 30))
                  .millisecondsSinceEpoch,
            ),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return LessonText(
      sourceKey: key,
      text: row.read<String>('text'),
      warnings: (jsonDecode(row.read<String>('warnings')) as List)
          .cast<String>(),
      fromCache: true,
      knownCharacterCount: row.read<int>('character_count'),
    );
  }

  Future<void> save(LessonText result, String quizId) async {
    final text = result.text;
    final byteSize = await _utf8BytesInBackground(text);
    if (!validKey(result.sourceKey) ||
        result.text.trim().isEmpty ||
        byteSize > lessonCacheByteCap) {
      throw const FormatException('Invalid cached text');
    }
    await db.transaction(() async {
      await db.customStatement(
        'INSERT OR REPLACE INTO file_text_cache(source_key,text,character_count,extracted_at,byte_cap,warnings,revision) VALUES(?,?,?,?,?,?,?)',
        [
          result.sourceKey,
          result.text,
          result.characterCount,
          now().toUtc().millisecondsSinceEpoch,
          lessonCacheByteCap,
          jsonEncode(result.warnings),
          lessonExtractorRevision,
        ],
      );
      await associate(quizId, result.sourceKey);
    });
  }

  Future<void> associate(String quizId, String key) => db.customStatement(
    'INSERT OR IGNORE INTO draft_text_sources(quiz_id,source_key) VALUES(?,?)',
    [quizId, key],
  );
  Future<void> abandonPending(String quizId) => db.customStatement(
    "DELETE FROM ai_question_contexts WHERE quiz_id=? AND state<>'saved'",
    [quizId],
  );
  Future<void> delete(String key) async {
    await db.customStatement(
      'DELETE FROM draft_text_sources WHERE source_key=?',
      [key],
    );
    await db.customStatement('DELETE FROM file_text_cache WHERE source_key=?', [
      key,
    ]);
  }

  Future<void> deleteForDraft(String quizId) => db.transaction(() async {
    await db.customStatement(
      'DELETE FROM ai_question_contexts WHERE quiz_id=?',
      [quizId],
    );
    await db.customStatement('DELETE FROM draft_text_sources WHERE quiz_id=?', [
      quizId,
    ]);
    await db.customStatement(
      'DELETE FROM file_text_cache WHERE source_key NOT IN (SELECT source_key FROM draft_text_sources)',
    );
  });

  Future<void> putContext(
    String questionId,
    String quizId,
    AiSourceContext context, {
    String state = 'saved',
    String? payload,
    int? position,
  }) async {
    await db.customStatement(
      'INSERT OR REPLACE INTO ai_question_contexts(question_key,quiz_id,context,state,payload,position) VALUES(?,?,?,?,?,?)',
      [
        questionId,
        quizId,
        jsonEncode(context.toJson()),
        state,
        payload,
        position,
      ],
    );
  }

  Future<AiSourceContext?> contextFor(String questionId) async {
    final rows = await db
        .customSelect(
          'SELECT context FROM ai_question_contexts WHERE question_key=?',
          variables: [Variable(questionId)],
        )
        .get();
    return rows.isEmpty
        ? null
        : AiSourceContext.fromJson(
            jsonDecode(rows.single.read<String>('context'))
                as Map<String, dynamic>,
          );
  }

  Future<void> bind(String localId, String serverId) async {
    if ((await db
            .customSelect(
              'SELECT question_key FROM ai_question_contexts WHERE question_key=?',
              variables: [Variable(localId)],
            )
            .get())
        .isEmpty)
      return;
    await db.customStatement(
      'DELETE FROM ai_question_contexts WHERE question_key=? AND question_key<>?',
      [serverId, localId],
    );
    await db.customStatement(
      "UPDATE ai_question_contexts SET question_key=?,state='saved',payload=NULL WHERE question_key=?",
      [serverId, localId],
    );
  }

  Future<List<Map<String, dynamic>>> pending(String quizId) async =>
      (await db
              .customSelect(
                "SELECT * FROM ai_question_contexts WHERE quiz_id=? AND state<>'saved' ORDER BY position",
                variables: [Variable(quizId)],
              )
              .get())
          .map((r) => r.data)
          .toList();

  Future<List<Map<String, String>>?> restore(AiSourceContext context) async {
    if (context.revision != lessonExtractorRevision) return null;
    final texts = <Map<String, String>>[];
    for (final source in context.sources) {
      final result = await find(source.key);
      if (result == null || result.characterCount < source.characters)
        return null;
      texts.add({
        'file_name': source.name,
        'text': String.fromCharCodes(result.text.runes.take(source.characters)),
      });
    }
    return texts.isEmpty ? null : texts;
  }
}

Future<int> _utf8BytesInBackground(String text) =>
    Isolate.run(() => utf8.encode(text).length);
