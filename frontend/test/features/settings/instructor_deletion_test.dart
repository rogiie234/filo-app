import 'dart:async';
import 'dart:convert';

import 'package:filo/core/account_deletion_journal.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/features/settings/application/account_deletion.dart';
import 'package:filo/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_deletion_test.dart'
    show MemoryJournal, FakeDeletion, FakeRemoval;

class DelayedEligibility extends FakeDeletion {
  final response = Completer<InstructorDeletionEligibility>();
  @override
  Future<InstructorDeletionEligibility> eligibility(
    String id, {
    bool Function()? isCurrent,
  }) async {
    final value = await response.future;
    if (isCurrent != null && !isCurrent()) throw StateError('Obsolete fixture');
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  AccountDeletionRepository repository(
    Future<http.Response> Function(http.Request) respond,
  ) {
    final client = SupabaseClient(
      'https://fixture.invalid',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final response = await respond(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    return AccountDeletionRepository(client);
  }

  http.Response json(Object? value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  for (final count in [1, 3]) {
    test(
      'positive authoritative count $count blocks without recovery query',
      () async {
        var calls = 0;
        final repo = repository((request) async {
          calls++;
          expect(request.url.path, '/rest/v1/rpc/owned_class_count');
          return json(count);
        });
        expect((await repo.eligibility('a')).count, count);
        expect(calls, 1);
      },
    );
  }
  for (final count in [-1, 0.5, '0', null]) {
    test('invalid count $count never becomes eligible', () async {
      final repo = repository((_) async => json(count));
      await expectLater(repo.eligibility('a'), throwsFormatException);
    });
  }
  for (final recovery in [false, true]) {
    test(
      'zero count checks owner soft-deleted presence recovery=$recovery',
      () async {
        var calls = 0;
        final repo = repository((request) async {
          if (++calls == 1) return json(0);
          expect(request.url.queryParameters['owner_id'], 'eq.a');
          expect(request.url.queryParameters['deleted_at'], 'not.is.null');
          expect(request.url.queryParameters['limit'], '1');
          return json(
            recovery
                ? [
                    {'id': 'deleted'},
                  ]
                : [],
          );
        });
        final result = await repo.eligibility('a');
        expect(result.count, 0);
        expect(result.hasRecoveryClasses, recovery);
      },
    );
  }
  test(
    'recovery lookup failure is a failure, not zero safe-to-delete',
    () async {
      var calls = 0;
      final repo = repository(
        (_) async => ++calls == 1 ? json(0) : json({'message': 'fixture'}, 503),
      );
      await expectLater(
        repo.eligibility('a'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test('session loss between reads prevents recovery query', () async {
    var calls = 0;
    final repo = repository((_) async {
      calls++;
      return json(0);
    });
    await expectLater(
      repo.eligibility('a', isCurrent: () => false),
      throwsStateError,
    );
    expect(calls, 1);
  });
  for (final count in [2, -1, '2', null]) {
    test('server 409 preserves valid positive count only: $count', () async {
      final repo = repository(
        (_) async => json({
          'error': {'code': 'OWNED_CLASSES_EXIST', 'count': count},
        }, 409),
      );
      await expectLater(
        repo.request(),
        throwsA(
          isA<OwnedClassesExist>().having(
            (error) => error.count,
            'count',
            count == 2 ? 2 : null,
          ),
        ),
      );
    });
  }
  test('journal role survives stages/restart; older student journals stay compatible', () async {
    final store = DeletionJournalStore();
    const record = DeletionRecord(
      'a',
      's',
      DeletionStage.uncertain,
      instructor: true,
    );
    await store.write({'a': record.at(DeletionStage.pending)});
    expect((await store.read())['a']!.instructor, isTrue);
    await const FlutterSecureStorage().write(
      key: DeletionJournalStore.key,
      value: '{"a":{"session":"s","stage":"pending"}}',
    );
    expect((await store.read())['a']!.instructor, isFalse);
  });
  test('initial 409 clears journal/input and holds authoritative block until refresh', () async {
    final journal = MemoryJournal();
    final remote = FakeDeletion();
    addTearDown(remote.client.dispose);
    remote.outcome = () async => throw const OwnedClassesExist(3);
    final container = ProviderContainer(
      overrides: [
        deletionJournalStoreProvider.overrideWithValue(journal),
        deletionSessionProvider.overrideWithValue((
          userId: 'a',
          sessionId: 's',
        )),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        instructorDeletionEligibilityProvider(
          'a',
        ).overrideWith((ref) async => const InstructorDeletionEligibility(0)),
        accountDeletionRepositoryProvider.overrideWithValue(remote),
        accountDeletionCleanupProvider.overrideWithValue(FakeRemoval()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(deletionJournalProvider, (_, _) {});
    container.listen(connectivityProvider, (_, _) {});
    container.listen(instructorDeletionEligibilityProvider('a'), (_, _) {});
    await container.read(deletionJournalProvider.future);
    await container.read(connectivityProvider.future);
    await container.read(instructorDeletionEligibilityProvider('a').future);
    final flow = container.read(accountDeletionProvider.notifier);
    await flow.request('a', 'DELETE', instructor: true);
    expect(journal.saved, isEmpty);
    expect(flow.draft('a'), isEmpty);
    expect(container.read(accountDeletionProvider).ownedClassCount, 3);
    await container.read(instructorDeletionEligibilityProvider('a').future);
    await flow.request('a', 'DELETE', instructor: true);
    expect(remote.calls, 1);
    flow.refreshEligibility('a');
    await container.read(instructorDeletionEligibilityProvider('a').future);
    remote.outcome = () async => DeletionStage.pending;
    await flow.request('a', 'DELETE', instructor: true);
    expect(journal.saved['a']!.instructor, isTrue);
  });
  test(
    'loading or offline instructor eligibility cannot dispatch deletion',
    () async {
      for (final online in [true, false]) {
        final remote = FakeDeletion();
        addTearDown(remote.client.dispose);
        final journal = MemoryJournal();
        final pending = Completer<InstructorDeletionEligibility>();
        final container = ProviderContainer(
          overrides: [
            deletionJournalStoreProvider.overrideWithValue(journal),
            deletionSessionProvider.overrideWithValue((
              userId: 'a',
              sessionId: 's',
            )),
            connectivityProvider.overrideWith((ref) => Stream.value(online)),
            instructorDeletionEligibilityProvider('a')
                .overrideWith((ref) => pending.future),
            accountDeletionRepositoryProvider.overrideWithValue(remote),
          ],
        );
        addTearDown(container.dispose);
        container.listen(deletionJournalProvider, (_, _) {});
        container.listen(connectivityProvider, (_, _) {});
        container.listen(instructorDeletionEligibilityProvider('a'), (_, _) {});
        await container.read(deletionJournalProvider.future);
        await container.read(connectivityProvider.future);
        await container
            .read(accountDeletionProvider.notifier)
            .request('a', 'DELETE', instructor: true);
        expect(remote.calls, 0);
        expect(journal.saved, isEmpty);
        pending.complete(const InstructorDeletionEligibility(0));
        await container.read(instructorDeletionEligibilityProvider('a').future);
      }
    },
  );
  test(
    'account replacement discards a late zero-count eligibility result',
    () async {
      final remote = DelayedEligibility();
      addTearDown(remote.client.dispose);
      var session = (userId: 'a', sessionId: 's');
      final container = ProviderContainer(
        overrides: [
          deletionSessionProvider.overrideWith((ref) => session),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          accountDeletionRepositoryProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);
      container.listen(connectivityProvider, (_, _) {});
      await container.read(connectivityProvider.future);
      container.listen(instructorDeletionEligibilityProvider('a'), (_, _) {});
      final old = container.read(
        instructorDeletionEligibilityProvider('a').future,
      );
      final oldResult = expectLater(old, throwsA(anything));
      session = (userId: 'b', sessionId: 'replacement');
      container.invalidate(deletionSessionProvider);
      await expectLater(
        container.read(instructorDeletionEligibilityProvider('a').future),
        throwsStateError,
      );
      remote.response.complete(const InstructorDeletionEligibility(0));
      await oldResult;
      expect(
        container.read(instructorDeletionEligibilityProvider('a')).hasError,
        isTrue,
      );
    },
  );
}
