import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/supabase/auth_providers.dart';
import '../../files/application/files_providers.dart';
import '../../files/data/file_storage.dart';
import '../../files/data/files_repository.dart';

class StorageRepository {
  StorageRepository(this.files);
  final FilesRepository files;

  Future<StorageUsage> load() => files.serialize(files.storage.usage);

  Future<StorageUsage> clear(bool Function() isCurrent) =>
      files.serialize(() async {
        if (!isCurrent()) throw StateError('Account changed');
        await files.storage.clearTemporary(isCurrent: isCurrent);
        if (!isCurrent()) throw StateError('Account changed');
        return files.storage.usage();
      });
}

final storageRepositoryProvider = FutureProvider<StorageRepository>((
  ref,
) async {
  final id = ref.watch(authUserIdProvider).asData?.value;
  if (id == null) throw StateError('Account unavailable');
  final files = await ref.watch(filesRepositoryProvider.future);
  if (!ref.mounted ||
      files == null ||
      ref.read(authUserIdProvider).asData?.value != id ||
      p.basename(files.storage.root.path) != id) {
    throw StateError('Storage unavailable');
  }
  return StorageRepository(files);
});

final storageSettingsProvider =
    AsyncNotifierProvider.autoDispose<StorageSettings, StorageUsage>(
      StorageSettings.new,
    );

class StorageSettings extends AsyncNotifier<StorageUsage> {
  Object _generation = Object();
  bool _working = false;
  String? _account;
  StorageRepository? _repository;

  @override
  Future<StorageUsage> build() async {
    final generation = _generation = Object();
    _working = false;
    _repository = null;
    _account = ref.watch(authUserIdProvider).asData?.value;
    ref.onDispose(() {
      _generation = Object();
    });
    if (_account == null) throw StateError('Account unavailable');
    final repository = await ref.watch(storageRepositoryProvider.future);
    if (!_current(generation)) throw StateError('Account changed');
    _repository = repository;
    return repository.load();
  }

  bool _current(Object generation) =>
      ref.mounted &&
      identical(_generation, generation) &&
      _account != null &&
      ref.read(authUserIdProvider).asData?.value == _account;

  Future<bool> clear() async {
    final generation = _generation;
    final repository = _repository;
    if (_working || !_current(generation) || repository == null) return false;
    _working = true;
    state = const AsyncLoading();
    try {
      final usage = await repository.clear(() => _current(generation));
      if (!_current(generation)) return false;
      state = AsyncData(usage);
      return true;
    } catch (error, stack) {
      if (_current(generation))
        state = AsyncError(
          const FileProblem(
            "Couldn't finish clearing the cache. Try again.",
            kind: 'cache-clear',
          ),
          stack,
        );
      return false;
    } finally {
      if (_current(generation)) _working = false;
    }
  }
}
