import 'dart:convert';
import 'dart:io';

import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String token(Map<String, dynamic> claims) =>
      'header.${base64UrlEncode(utf8.encode(jsonEncode(claims)))}.signature';

  test('requires a UUID session_id, even when a user ID is present', () {
    expect(
      () => sessionIdFromToken(token({'sub': 'user'})),
      throwsFormatException,
    );
    expect(
      () => sessionIdFromToken(token({'session_id': 'bad'})),
      throwsFormatException,
    );
    const id = '12345678-1234-1234-1234-123456789abc';
    expect(sessionIdFromToken(token({'session_id': id})), id);
  });

  test(
    'verification loss closes cached account data; verification reopens it',
    () async {
      final directory = await Directory.systemTemp.createTemp('filo-otp-gate-');
      final manager = UserDatabaseManager(
        directoryProvider: () async => directory,
      );
      String? verifiedUser;
      final container = ProviderContainer(
        overrides: [
          verifiedUserIdProvider.overrideWith((ref) async => verifiedUser),
          userDatabaseManagerProvider.overrideWithValue(manager),
        ],
      );
      final subscription = container.listen(accountDatabaseProvider, (_, _) {});
      try {
        expect(await container.read(accountDatabaseProvider.future), isNull);
        expect(await directory.list().isEmpty, isTrue);
        verifiedUser = 'verified-account';
        container.invalidate(verifiedUserIdProvider);
        await Future<void>.delayed(Duration.zero);
        final database = await container.read(accountDatabaseProvider.future);
        expect(database, isNotNull);
        verifiedUser = null;
        container.invalidate(verifiedUserIdProvider);
        await Future<void>.delayed(Duration.zero);
        expect(await container.read(accountDatabaseProvider.future), isNull);
      } finally {
        subscription.close();
        container.dispose();
        await manager.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
