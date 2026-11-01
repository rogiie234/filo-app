import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/settings/application/theme_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedThemeRepository extends ThemeSettingsRepository {
  DelayedThemeRepository(super.database, this.initial);
  final ThemeMode initial;
  final write = Completer<void>();
  bool storageRecovered = false;
  @override
  Future<ThemeMode> load() async => initial;
  @override
  Future<void> save(ThemeMode mode) =>
      storageRecovered ? super.save(mode) : write.future;
}

class DelayedLoadThemeRepository extends ThemeSettingsRepository {
  DelayedLoadThemeRepository(super.database);
  final loaded = Completer<ThemeMode>();
  @override
  Future<ThemeMode> load() => loaded.future;
}

void main() {
  test('a late load cannot replace the next account theme', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repositoryA = DelayedLoadThemeRepository(database);
    final repositoryB = ThemeSettingsRepository(database);
    await repositoryB.save(ThemeMode.light);
    final events = StreamController<String?>();
    addTearDown(events.close);
    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWith((ref) async* {
          yield 'account-a';
          yield* events.stream;
        }),
        themeSettingsRepositoryProvider.overrideWith(
          (ref) async =>
              ref.watch(authUserIdProvider).asData?.value == 'account-a'
              ? repositoryA
              : repositoryB,
        ),
      ],
    );
    addTearDown(container.dispose);
    final authSubscription = container.listen(authUserIdProvider, (_, _) {});
    addTearDown(authSubscription.close);
    await container.read(authUserIdProvider.future);
    final subscription = container.listen(themeSettingsProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.pump();
    events.add('account-b');
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(await container.read(themeSettingsProvider.future), ThemeMode.light);
    repositoryA.loaded.complete(ThemeMode.dark);
    await container.pump();
    expect(
      container.read(themeSettingsProvider).asData?.value,
      ThemeMode.light,
    );
  });
  test(
    'missing and invalid preferences use System; each valid mode round-trips',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ThemeSettingsRepository(database);
      expect(await repository.load(), ThemeMode.system);
      await database.customStatement(
        "INSERT INTO app_settings VALUES('theme','unknown')",
      );
      expect(await repository.load(), ThemeMode.system);
      for (final mode in ThemeMode.values) {
        await repository.save(mode);
        expect(await repository.load(), mode);
      }
    },
  );

  test(
    'theme survives reopening and version 13 upgrade preserves existing data',
    () async {
      final directory = await Directory.systemTemp.createTemp('filo-theme-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/account.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      await ThemeSettingsRepository(database).save(ThemeMode.dark);
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      expect(await ThemeSettingsRepository(database).load(), ThemeMode.dark);
      await database.customStatement(
        "INSERT INTO ai_settings VALUES('preserve','yes')",
      );
      await database.customStatement('DROP TABLE app_settings');
      await database.customStatement('PRAGMA user_version=13');
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      addTearDown(database.close);
      expect(await ThemeSettingsRepository(database).load(), ThemeMode.system);
      expect(
        (await database
                .customSelect(
                  "SELECT value FROM ai_settings WHERE key='preserve'",
                )
                .getSingle())
            .read<String>('value'),
        'yes',
      );
    },
  );

  test('selection applies immediately; failed persistence restores confirmed choice and permits retry', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DelayedThemeRepository(database, ThemeMode.light);
    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWith((ref) => Stream.value('account-a')),
        themeSettingsRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    final authSubscription = container.listen(authUserIdProvider, (_, _) {});
    addTearDown(authSubscription.close);
    await container.read(authUserIdProvider.future);
    await container.read(themeSettingsProvider.future);
    final controller = container.read(themeSettingsProvider.notifier);
    final pending = controller.choose(ThemeMode.dark);
    expect(container.read(themeSettingsProvider).asData?.value, ThemeMode.dark);
    expect(await controller.choose(ThemeMode.system), isFalse);
    repository.write.completeError(StateError('disk unavailable'));
    expect(await pending, isFalse);
    expect(
      container.read(themeSettingsProvider).asData?.value,
      ThemeMode.light,
    );
    repository.storageRecovered = true;
    expect(
      await container
          .read(themeSettingsProvider.notifier)
          .choose(ThemeMode.dark),
      isTrue,
    );
    expect(await ThemeSettingsRepository(database).load(), ThemeMode.dark);
  });

  test('late failed save for account A cannot overwrite account B or signed-out System', () async {
    final databaseA = AppDatabase(NativeDatabase.memory());
    final databaseB = AppDatabase(NativeDatabase.memory());
    addTearDown(databaseA.close);
    addTearDown(databaseB.close);
    final events = StreamController<String?>();
    addTearDown(events.close);
    final repositoryA = DelayedThemeRepository(databaseA, ThemeMode.light);
    final repositoryB = ThemeSettingsRepository(databaseB);
    await repositoryB.save(ThemeMode.system);
    final container = ProviderContainer(
      overrides: [
        authUserIdProvider.overrideWith((ref) async* {
          yield 'account-a';
          yield* events.stream;
        }),
        themeSettingsRepositoryProvider.overrideWith((ref) async {
          return ref.watch(authUserIdProvider).asData?.value == 'account-a'
              ? repositoryA
              : repositoryB;
        }),
      ],
    );
    addTearDown(container.dispose);
    final authSubscription = container.listen(authUserIdProvider, (_, _) {});
    addTearDown(authSubscription.close);
    final subscription = container.listen(themeSettingsProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(authUserIdProvider.future);
    await container.read(themeSettingsProvider.future);
    final pending = container
        .read(themeSettingsProvider.notifier)
        .choose(ThemeMode.dark);
    events.add('account-b');
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(
      await container.read(themeSettingsProvider.future),
      ThemeMode.system,
    );
    repositoryA.write.completeError(StateError('old account write failed'));
    expect(await pending, isFalse);
    expect(
      container.read(themeSettingsProvider).asData?.value,
      ThemeMode.system,
    );
    expect(await repositoryB.load(), ThemeMode.system);
    events.add(null);
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(
      await container.read(themeSettingsProvider.future),
      ThemeMode.system,
    );
    expect(
      await container
          .read(themeSettingsProvider.notifier)
          .choose(ThemeMode.light),
      isFalse,
    );
  });
}
