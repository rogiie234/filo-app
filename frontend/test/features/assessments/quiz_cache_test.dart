import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/assessments/data/instructor_quiz_repository.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';

void main() {
  final client = SupabaseClient('https://example.supabase.co', 'test-key');
  Future<void> seed(AppDatabase db) async {
    await db.customStatement(
      "INSERT INTO cache_profiles(id,role,display_name) VALUES ('owner','instructor','Owner')",
    );
    await db.customStatement(
      "INSERT INTO cache_classes(id,owner_id,course,section,school_year,join_code) VALUES ('class','owner','Course','A','2026','ABC123')",
    );
  }

  InstructorQuizRepository repo(AppDatabase db, [String user = 'owner']) =>
      InstructorQuizRepository(db, client, user, () => false);
  test('complete snapshot and empty list survive file reopen; other accounts denied', () async {
    final dir = await Directory.systemTemp.createTemp('filo-quiz-cache');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await seed(db);
    final quiz = InstructorQuiz(
      {'id': 'quiz', 'class_id': 'class', 'title': 'Saved'},
      [
        QuizQuestion(
          localId: 'q',
          id: 'q',
          options: [const QuizOption('o', 'Answer')],
          payload: {
            'type': 'multiple_choice',
            'prompt': 'Question',
            'points': 1,
            'options': ['Answer', 'Other'],
            'correct_option_index': 0,
          },
        ),
      ],
    );
    await db.customStatement(
      'INSERT INTO instructor_quiz_details VALUES (?,?,?)',
      ['quiz', 'class', jsonEncode(quiz.toJson())],
    );
    await db.customStatement('INSERT INTO instructor_quiz_lists VALUES (?,?)', [
      'class',
      '[]',
    ]);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final loaded = await repo(db).watchQuiz('class', 'quiz').first;
    expect(loaded!.questions.first.payload['correct_option_index'], 0);
    expect(loaded.questions.first.options.first.id, 'o');
    expect(await repo(db).watchList('class').first, isEmpty);
    expect(await repo(db).watchQuiz('class', 'missing').first, isNull);
    await expectLater(
      repo(db, 'other').watchQuiz('class', 'quiz').first,
      throwsStateError,
    );
    await expectLater(repo(db).save(QuizDraft(loaded)), throwsStateError);
  });
  test('version four upgrade preserves data and adds snapshots; class deletion cascades', () async {
    final dir = await Directory.systemTemp.createTemp('filo-quiz-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await seed(db);
    await db.customStatement('DROP TABLE instructor_quiz_details');
    await db.customStatement('DROP TABLE instructor_quiz_lists');
    await db.customStatement('PRAGMA user_version=4');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.readProfile('owner'))!.displayName, 'Owner');
    await db.customStatement('INSERT INTO instructor_quiz_lists VALUES (?,?)', [
      'class',
      '[]',
    ]);
    await db.customStatement("DELETE FROM cache_classes WHERE id='class'");
    expect(
      await db.customSelect('SELECT * FROM instructor_quiz_lists').get(),
      isEmpty,
    );
  });
}
