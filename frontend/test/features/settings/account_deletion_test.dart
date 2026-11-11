import 'dart:async';
import 'dart:convert';

import 'package:filo/core/account_deletion_journal.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:filo/features/settings/application/account_deletion.dart';
import 'package:filo/features/settings/data/account_deletion_cleanup.dart';
import 'package:filo/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryJournal extends DeletionJournalStore {
  Map<String, DeletionRecord> saved = {};
  bool fail = false;
  @override
  Future<Map<String, DeletionRecord>> read() async => {...saved};
  @override
  Future<void> write(Map<String, DeletionRecord> records) async {
    if (fail) throw StateError('fixture journal write');
    saved = {...records};
  }
}

class FakeDeletion extends AccountDeletionRepository {
  FakeDeletion()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int calls = 0;
  Future<DeletionStage> Function() outcome = () async => DeletionStage.pending;
  @override
  Future<DeletionStage> request() {
    calls++;
    return outcome();
  }
}

class FakeRemoval extends AccountDeletionCleanup {
  FakeRemoval() : super(UserDatabaseManager());
  int removed = 0;
  bool fail = false;
  bool failBlock = false;
  @override
  Future<void> block(String id, bool blocked) async {
    if (blocked && failBlock) throw StateError('fixture preparation');
  }

  @override
  Future<void> remove(String id) async {
    if (fail) throw StateError('fixture removal');
    removed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'secure journal survives restart and rejects malformed records',
    () async {
      final store = DeletionJournalStore();
      await store.write({
        'a': const DeletionRecord('a', 's', DeletionStage.cleanup),
      });
      expect(
        (await DeletionJournalStore().read())['a']!.stage,
        DeletionStage.cleanup,
      );
      await const FlutterSecureStorage().write(
        key: DeletionJournalStore.key,
        value: '{bad',
      );
      await expectLater(store.read(), throwsFormatException);
    },
  );

  for (final response in [
    (200, {'status': 'deleted'}, DeletionStage.cleanup),
    (202, {'status': 'pending'}, DeletionStage.pending),
  ]) {
    test('POST empty object recognizes ${response.$1}', () async {
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/functions/v1/delete-account');
          expect(jsonDecode(request.body), <String, dynamic>{});
          return http.Response(
            jsonEncode(response.$2),
            response.$1,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      expect(await AccountDeletionRepository(client).request(), response.$3);
    });
  }
  for (final response in [
    (
      403,
      {
        'error': {'code': 'NOT_ALLOWED'},
      },
      true,
    ),
    (
      503,
      {
        'error': {'code': 'UNAVAILABLE'},
      },
      false,
    ),
    (200, {'status': 'unexpected'}, false),
  ]) {
    test(
      'response ${response.$1} classified without assuming account intact',
      () async {
        final client = SupabaseClient(
          'https://fixture.invalid',
          'fixture',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode(response.$2),
              response.$1,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(client.dispose);
        await expectLater(
          AccountDeletionRepository(client).request(),
          response.$3 ? throwsA(isA<DeletionRejected>()) : throwsStateError,
        );
      },
    );
  }

  for (final status in [401, 404]) {
    test(
      'gateway $status is an actionable rejection, not unknown deletion',
      () async {
        final client = SupabaseClient(
          'https://fixture.invalid',
          'fixture',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'code': status == 404 ? 'NOT_FOUND' : 401,
                'message': 'Gateway refusal',
              }),
              status,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(client.dispose);
        await expectLater(
          AccountDeletionRepository(client).request(),
          throwsA(
            isA<DeletionRejected>().having(
              (e) => e.message,
              'actionable message',
              contains(status == 404 ? 'unavailable' : 'sign in again'),
            ),
          ),
        );
      },
    );
  }

  late MemoryJournal journal;
  late FakeDeletion remote;
  late FakeRemoval cleanup;
  late ProviderContainer container;
  var session = (userId: 'a', sessionId: 's');
  Future<void> setup({
    bool online = true,
    DeletionStage? stage,
    Future<void> Function(String)? sessionCleanup,
  }) async {
    journal = MemoryJournal();
    if (stage != null) journal.saved['a'] = DeletionRecord('a', 's', stage);
    remote = FakeDeletion();
    cleanup = FakeRemoval();
    session = (userId: 'a', sessionId: 's');
    container = ProviderContainer(
      overrides: [
        deletionJournalStoreProvider.overrideWithValue(journal),
        deletionSessionProvider.overrideWith((ref) => session),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        accountDeletionRepositoryProvider.overrideWithValue(remote),
        accountDeletionCleanupProvider.overrideWithValue(cleanup),
        deletionSessionCleanupProvider.overrideWithValue(
          sessionCleanup ?? (_) async {},
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(remote.client.dispose);
    container.listen(deletionJournalProvider, (_, _) {});
    container.listen(connectivityProvider, (_, _) {});
    await container.read(deletionJournalProvider.future);
    await container.read(connectivityProvider.future);
  }

  test('exact confirmation only; offline never dispatches', () async {
    await setup();
    final flow = container.read(accountDeletionProvider.notifier);
    for (final word in ['', 'delete', ' DELETE', 'DELETE ', 'OTHER']) {
      await flow.request('a', word);
    }
    expect(remote.calls, 0);
    await flow.request('a', 'DELETE');
    expect(remote.calls, 1);
    expect(journal.saved['a']!.stage, DeletionStage.pending);
    await setup(online: false);
    await container
        .read(accountDeletionProvider.notifier)
        .request('a', 'DELETE');
    expect(remote.calls, 0);
  });
  test(
    'local preparation failure rolls back without claiming unknown deletion',
    () async {
      await setup();
      cleanup.failBlock = true;
      await container
          .read(accountDeletionProvider.notifier)
          .request('a', 'DELETE');
      expect(remote.calls, 0);
      expect(journal.saved, isEmpty);
      expect(
        container.read(accountDeletionProvider).message,
        "Couldn't delete your account. Try again.",
      );
    },
  );
  test('failed journal prevents remote request', () async {
    await setup();
    journal.fail = true;
    await container
        .read(accountDeletionProvider.notifier)
        .request('a', 'DELETE');
    expect(remote.calls, 0);
    expect(journal.saved, isEmpty);
  });
  test(
    'known rejection clears marker, keeps draft and permits explicit retry',
    () async {
      await setup();
      remote.outcome = () async => throw const DeletionRejected();
      final flow = container.read(accountDeletionProvider.notifier);
      await flow.request('a', 'DELETE');
      expect(journal.saved, isEmpty);
      expect(flow.draft('a'), 'DELETE');
      expect(
        container.read(accountDeletionProvider).message,
        contains("Couldn't delete"),
      );
      remote.outcome = () async => DeletionStage.pending;
      await flow.request('a', 'DELETE');
      expect(remote.calls, 2);
    },
  );
  test(
    'uncertain outcome remains durable and requires exact confirmation again',
    () async {
      await setup();
      remote.outcome = () async => throw TimeoutException('fixture');
      final flow = container.read(accountDeletionProvider.notifier);
      await flow.request('a', 'DELETE');
      expect(journal.saved['a']!.stage, DeletionStage.uncertain);
      await flow.request('a', '');
      expect(remote.calls, 1);
    },
  );
  test(
    'duplicate and obsolete A-B-A completions cannot clean or publish success',
    () async {
      await setup();
      final response = Completer<DeletionStage>();
      remote.outcome = () => response.future;
      final flow = container.read(accountDeletionProvider.notifier);
      final first = flow.request('a', 'DELETE');
      await Future<void>.delayed(Duration.zero);
      await flow.request('a', 'DELETE');
      expect(remote.calls, 1);
      session = (userId: 'b', sessionId: 'b-session');
      container.invalidate(deletionSessionProvider);
      container.read(deletionSessionProvider);
      session = (userId: 'a', sessionId: 's');
      container.invalidate(deletionSessionProvider);
      container.read(deletionSessionProvider);
      response.complete(DeletionStage.cleanup);
      await first;
      expect(cleanup.removed, 0);
      expect(journal.saved['a']!.stage, DeletionStage.uncertain);
    },
  );
  test(
    'pending resume is deliberate; cleanup retry offline is local only',
    () async {
      await setup(stage: DeletionStage.pending);
      expect(remote.calls, 0);
      remote.outcome = () async => DeletionStage.cleanup;
      cleanup.fail = true;
      await container.read(accountDeletionProvider.notifier).request('a', '');
      expect(journal.saved['a']!.stage, DeletionStage.cleanup);
      expect(remote.calls, 1);
      cleanup.fail = false;
      await container.read(accountDeletionProvider.notifier).removeLocal('a');
      expect(cleanup.removed, 1);
      expect(remote.calls, 1);
      expect(journal.saved, isEmpty);
      await setup(online: false, stage: DeletionStage.cleanup);
      await container.read(accountDeletionProvider.notifier).removeLocal('a');
      expect(cleanup.removed, 1);
      expect(remote.calls, 0);
    },
  );
  test('replacement session cannot resume old accepted request', () async {
    await setup(stage: DeletionStage.pending);
    session = (userId: 'a', sessionId: 'new-session');
    container.invalidate(deletionSessionProvider);
    await container
        .read(accountDeletionProvider.notifier)
        .request('a', 'DELETE');
    expect(remote.calls, 0);
    expect(journal.saved['a']!.stage, DeletionStage.pending);
  });
  test('native cleanup failure retains journal; offline retry never repeats server deletion', () async {
    var fail = true;
    await setup(
      online: false,
      stage: DeletionStage.cleanup,
      sessionCleanup: (_) async {
        if (fail) throw const DeletionCleanupFailure('Clearing reminders');
      },
    );
    final flow = container.read(accountDeletionProvider.notifier);
    await flow.removeLocal('a');
    expect(journal.saved['a']!.stage, DeletionStage.cleanup);
    expect(cleanup.removed, 0);
    expect(remote.calls, 0);
    expect(
      container.read(accountDeletionProvider).message,
      contains("Clearing reminders didn't finish"),
    );
    expect(container.read(accountDeletionProvider).busyUser, isNull);
    fail = false;
    await flow.removeLocal('a');
    expect(journal.saved, isEmpty);
    expect(cleanup.removed, 1);
    expect(remote.calls, 0);
  });
}
