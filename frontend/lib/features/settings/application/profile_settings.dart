import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/auth_providers.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/cache_row_json.dart';
import '../../../data/local/database_providers.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../onboarding/domain/profile_photo.dart';

class ProfileCache {
  ProfileCache(this.database, this.userId);
  final AppDatabase database;
  final String userId;

  Stream<AccountProfile?> watch() =>
      (database.select(
        database.cacheProfiles,
      )..where((row) => row.id.equals(userId))).watchSingleOrNull().map(
        (row) => row == null
            ? null
            : AccountProfile.fromJson({
                'id': row.id,
                'role': row.role,
                'display_name': row.displayName,
                'email': row.email,
                'school': row.school,
                'google_photo_url': row.googlePhotoUrl,
                'avatar_path': row.avatarPath,
              }),
      );

  Future<void> save(AccountProfile profile) async {
    if (profile.id != userId) throw StateError('Account changed');
    final row = profile.row;
    const columns = [
      'id',
      'role',
      'display_name',
      'email',
      'school',
      'google_photo_url',
      'avatar_path',
      'privacy_accepted_at',
      'privacy_version',
      'deleted_at',
      'created_at',
      'updated_at',
    ];
    if (columns.any((key) => !row.containsKey(key))) {
      throw StateError('Incomplete confirmed profile');
    }
    final json = cacheRowJson(row);
    final confirmed = CacheProfile.fromJson(json);
    await database.transaction(() async {
      final cached = await database.readProfile(userId);
      if (cached != null && cached.updatedAt.isAfter(confirmed.updatedAt)) {
        return;
      }
      await database.saveProfile(confirmed.toCompanion(false));
    });
  }
}

final profileCacheProvider = FutureProvider<ProfileCache?>((ref) async {
  final id = ref.watch(authUserIdProvider).asData?.value;
  if (id == null) return null;
  final database = await ref.watch(accountDatabaseProvider.future);
  if (!ref.mounted ||
      database == null ||
      ref.read(authUserIdProvider).asData?.value != id) {
    return null;
  }
  return ProfileCache(database, id);
});

final cachedAccountProfileProvider = StreamProvider.autoDispose
    .family<AccountProfile?, String>((ref, id) {
      if (ref.watch(authUserIdProvider).asData?.value != id) {
        return Stream.value(null);
      }
      // Capture dependencies before a lazy stream can start after disposal.
      final ready = ref.watch(profileCacheProvider.future);
      return ready.asStream().asyncExpand((cache) {
        if (!ref.mounted || cache == null || cache.userId != id) {
          return Stream<AccountProfile?>.value(null);
        }
        return cache.watch();
      });
    });

class ConfirmedProfile {
  const ConfirmedProfile(this.profile, this.photo, {this.cachePending = true});
  final AccountProfile profile;
  final ProfilePhotoDraft? photo;
  final bool cachePending;
}

final confirmedProfileProvider =
    NotifierProvider<ConfirmedProfileController, ConfirmedProfile?>(
      ConfirmedProfileController.new,
    );

class ConfirmedProfileController extends Notifier<ConfirmedProfile?> {
  @override
  ConfirmedProfile? build() {
    ref.watch(authUserIdProvider);
    return null;
  }

  Future<void> clearAccount(String id) async {
    final current = state;
    if (current == null || current.profile.id != id) return;
    state = null;
    if (current.photo != null) await MemoryImage(current.photo!.bytes).evict();
    if (current.profile.photoUrl != null) {
      await NetworkImage(current.profile.photoUrl!).evict();
    }
  }

  void publish(AccountProfile profile, ProfilePhotoDraft? photo) {
    if (ref.read(authUserIdProvider).asData?.value != profile.id) return;
    final previous = state;
    final retained =
        photo ??
        (previous?.profile.id == profile.id &&
                previous?.profile.avatarPath == profile.avatarPath
            ? previous?.photo
            : null);
    state = ConfirmedProfile(profile, retained);
  }

  void cached(AccountProfile profile) {
    final current = state;
    if (current == null || !identical(current.profile, profile)) return;
    ref.invalidate(cachedAccountProfileProvider(profile.id));
    state = ConfirmedProfile(profile, current.photo, cachePending: false);
  }
}

final accountProfileProvider = Provider.autoDispose
    .family<AccountProfile?, String>((ref, id) {
      if (ref.watch(authUserIdProvider).asData?.value != id) return null;
      final cacheState = ref.watch(cachedAccountProfileProvider(id));
      final cached = cacheState.isLoading ? null : cacheState.asData?.value;
      final confirmed = ref.watch(confirmedProfileProvider);
      if (confirmed?.profile.id == id) {
        return confirmed!.cachePending
            ? confirmed.profile
            : cached ?? confirmed.profile;
      }
      return cached;
    });
