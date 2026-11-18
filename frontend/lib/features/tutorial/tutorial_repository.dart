import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Variable;

import '../../data/local/app_database.dart';
import '../../data/local/database_providers.dart';

class TutorialRepository {
  TutorialRepository(this.database);
  final AppDatabase database;

  Future<bool> dismissed(String id) async {
    final row = await database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: [Variable<String>('tutorial_$id')],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<void> dismiss(String id, {required bool completed}) =>
      database.customStatement(
        'INSERT OR REPLACE INTO app_settings(key,value) VALUES(?,?)',
        ['tutorial_$id', completed ? 'completed' : 'skipped'],
      );
}

final tutorialRepositoryProvider = FutureProvider<TutorialRepository?>((
  ref,
) async {
  final database = await ref.watch(accountDatabaseProvider.future);
  return database == null ? null : TutorialRepository(database);
});
