import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../../core/supabase/session_gate.dart';

final onboardingUserProvider = Provider<User>((ref) {
  final user =
      ref.watch(loginSessionProvider).asData?.value?.user ??
      ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) throw StateError('Sign in required');
  return user;
});

enum AccountRole {
  student('Student'),
  instructor('Instructor');

  const AccountRole(this.label);
  final String label;
}

class AccountProfile {
  AccountProfile.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      role = AccountRole.values.byName(json['role'] as String),
      name = json['display_name'] as String,
      email = json['email'] as String?,
      school = json['school'] as String?,
      photoUrl = json['google_photo_url'] as String?,
      avatarPath = json['avatar_path'] as String?;

  final String id;
  final AccountRole role;
  final String name;
  final String? email, school, photoUrl, avatarPath;
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

class ProfileRepository {
  ProfileRepository(this.client);
  final SupabaseClient client;

  Future<AccountProfile?> fetch() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in required');
    final json = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return json == null ? null : AccountProfile.fromJson(json);
  }

  Future<AccountProfile> create({
    required AccountRole role,
    required String name,
    required String school,
    required bool consent,
  }) async {
    if (!consent ||
        name.trim().isEmpty ||
        name.trim().length > 80 ||
        school.trim().length > 120) {
      throw ArgumentError('Valid details and privacy consent are required');
    }
    final user = client.auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Sign in required');
    }
    // An earlier insert may have committed even when its response was lost.
    final existing = await fetch();
    if (existing != null) return existing;
    try {
      final json = await client
          .from('profiles')
          .insert({
            'id': user.id,
            'role': role.name,
            'display_name': name.trim(),
            'email': user.email,
            'school': school.trim().isEmpty ? null : school.trim(),
            'google_photo_url':
                user.userMetadata?['avatar_url'] ??
                user.userMetadata?['picture'],
            'privacy_accepted_at': DateTime.now().toUtc().toIso8601String(),
            'privacy_version': '2026-10-15',
          })
          .select()
          .single();
      return AccountProfile.fromJson(json);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final saved = await fetch();
      if (saved == null) rethrow;
      return saved;
    }
  }
}
