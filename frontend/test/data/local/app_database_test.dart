import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('sync state and queued JSON persist with their defaults', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.syncState)
        .insert(
          const SyncStateCompanion(syncedTableName: Value('cache_profiles')),
        );
    expect(
      (await database.select(database.syncState).getSingle()).lastSyncedAt,
      isNull,
    );
    await database
        .into(database.outbox)
        .insert(
          OutboxCompanion.insert(
            id: 'event-a',
            actionType: 'leave_event',
            payload: '{"session_id":"s1"}',
            status: 'pending',
          ),
        );
    final action = await database.select(database.outbox).getSingle();
    expect(action.payload, '{"session_id":"s1"}');
    expect(action.attempts, 0);
    expect(action.lastError, isNull);
  });

  test(
    'creates every cache, sync and queue table and saves a profile',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((row) => row.read<String>('name')).toSet(),
        containsAll({
          'cache_profiles',
          'cache_classes',
          'cache_class_members',
          'cache_posts',
          'cache_post_attachments',
          'cache_submissions',
          'cache_submission_items',
          'cache_grades',
          'cache_quizzes',
          'cache_results',
          'cache_notifications',
          'sync_state',
          'outbox',
        }),
      );
      await database.saveProfile(
        CacheProfilesCompanion.insert(
          id: 'student-a',
          role: 'student',
          displayName: 'Student A',
        ),
      );
      expect(
        (await database.readProfile('student-a'))?.displayName,
        'Student A',
      );
      await database.saveProfile(
        const CacheProfilesCompanion(
          id: Value('student-a'),
          role: Value('student'),
          displayName: Value('Updated name'),
        ),
      );
      expect(
        (await database.readProfile('student-a'))?.displayName,
        'Updated name',
      );
    },
  );

  test(
    'different accounts use different files and survive reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp('filo-database-');
      final manager = UserDatabaseManager(
        directoryProvider: () async => directory,
      );
      addTearDown(() async {
        await manager.close();
        await directory.delete(recursive: true);
      });
      final a = await manager.openForUser('user-a');
      expect(await manager.openForUser('user-a'), same(a));
      await a.saveProfile(
        CacheProfilesCompanion.insert(
          id: 'user-a',
          role: 'student',
          displayName: 'Account A',
        ),
      );
      final b = await manager.openForUser('user-b');
      expect(await b.readProfile('user-a'), isNull);
      for (final id in ['user-a', 'user-b']) {
        expect(
          File(
            p.join(
              directory.path,
              'databases',
              UserDatabaseManager.filenameForUser(id),
            ),
          ).existsSync(),
          isTrue,
        );
      }
      final reopened = await manager.openForUser('user-a');
      expect((await reopened.readProfile('user-a'))?.displayName, 'Account A');
    },
  );

  test('filenames encode unsafe IDs without sharing another account file', () {
    expect(UserDatabaseManager.filenameForUser('user-a'), 'user-a.sqlite');
    expect(
      UserDatabaseManager.filenameForUser('../user-a'),
      isNot('user-a.sqlite'),
    );
    expect(
      UserDatabaseManager.filenameForUser('../user-a'),
      isNot(contains('/')),
    );
    expect(() => UserDatabaseManager.filenameForUser(''), throwsArgumentError);
  });
}
