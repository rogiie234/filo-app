import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/auth_providers.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';

class ThemeSettingsRepository {
  ThemeSettingsRepository(this.database);
  final AppDatabase database;

  Future<ThemeMode> load() async {
    final row = await database
        .customSelect("SELECT value FROM app_settings WHERE key='theme'")
        .getSingleOrNull();
    return switch (row?.read<String>('value')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> save(ThemeMode mode) => database.customStatement(
    "INSERT OR REPLACE INTO app_settings(key,value) VALUES('theme',?)",
    [mode.name],
  );
}

final themeSettingsRepositoryProvider =
    FutureProvider<ThemeSettingsRepository?>((ref) async {
      final database = await ref.watch(accountDatabaseProvider.future);
      return database == null ? null : ThemeSettingsRepository(database);
    });

final themeSettingsProvider = AsyncNotifierProvider<ThemeSettings, ThemeMode>(
  ThemeSettings.new,
);

class ThemeSettings extends AsyncNotifier<ThemeMode> {
  Object _generation = Object();
  bool _saving = false;
  String? _accountId;

  @override
  Future<ThemeMode> build() async {
    _generation = Object();
    _saving = false;
    final account = ref.watch(authUserIdProvider);
    _accountId = account.asData?.value;
    if (_accountId == null) return ThemeMode.system;
    final repository = await ref.watch(themeSettingsRepositoryProvider.future);
    return repository == null ? ThemeMode.system : await repository.load();
  }

  Future<bool> choose(ThemeMode mode) async {
    final previous = state.asData?.value;
    if (_saving ||
        previous == null ||
        _accountId == null ||
        ref.read(authUserIdProvider).asData?.value != _accountId) {
      return false;
    }
    final generation = _generation;
    final repository = ref.read(themeSettingsRepositoryProvider).asData?.value;
    if (repository == null) return false;
    _saving = true;
    state = AsyncData(mode);
    try {
      await repository.save(mode);
      return ref.mounted && identical(generation, _generation);
    } catch (_) {
      if (ref.mounted && identical(generation, _generation)) {
        state = AsyncData(previous);
      }
      return false;
    } finally {
      if (ref.mounted && identical(generation, _generation)) _saving = false;
    }
  }
}

String themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};
