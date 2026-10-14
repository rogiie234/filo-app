import 'dart:async';
import 'dart:io';

import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restored session, account switch and logout drive the database',
    () async {
      final directory = await Directory.systemTemp.createTemp('filo-auth-db-');
      final ids = StreamController<String?>();
      final manager = UserDatabaseManager(
        directoryProvider: () async => directory,
      );
      final container = ProviderContainer(
        overrides: [
          authUserIdProvider.overrideWith((ref) => ids.stream),
          userDatabaseManagerProvider.overrideWithValue(manager),
        ],
      );
      final subscription = container.listen(accountDatabaseProvider, (_, _) {});
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ids.close();
        await manager.close();
        await directory.delete(recursive: true);
      });

      // The first auth emission represents the session restored at startup.
      ids.add('account-a');
      final a = (await container.read(accountDatabaseProvider.future))!;
      await a.saveProfile(
        CacheProfilesCompanion.insert(
          id: 'account-a',
          role: 'student',
          displayName: 'Account A',
        ),
      );

      ids.add('account-b');
      await Future<void>.delayed(Duration.zero);
      final b = (await container.read(accountDatabaseProvider.future))!;
      expect(b, isNot(same(a)));
      expect(await b.readProfile('account-a'), isNull);

      ids.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(accountDatabaseProvider.future), isNull);

      ids.add('account-a');
      await Future<void>.delayed(Duration.zero);
      final reopened = (await container.read(accountDatabaseProvider.future))!;
      expect(
        (await reopened.readProfile('account-a'))?.displayName,
        'Account A',
      );
    },
  );
}
