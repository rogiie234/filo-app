import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/notifications/push_providers.dart';
import 'package:filo/core/notifications/push_registration.dart';
import 'package:filo/core/privacy/privacy_notice.dart';
import 'package:filo/core/router/app_router.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/data/local/user_database_manager.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/settings/application/theme_settings.dart';
import 'package:filo/features/settings/presentation/privacy_notice_screen.dart';
import 'package:filo/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is FiloButton && w.label == label);
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  for (final role in ['student', 'instructor']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$role bundled privacy is readable offline at 130 percent dark=$dark without consent writes',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          await tester.runAsync(
            () => db.customStatement(
              "INSERT INTO cache_profiles(id,role,display_name,privacy_version) VALUES('a',?,'Alex','original')",
              [role],
            ),
          );
          addTearDown(() => tester.runAsync(db.close));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authUserIdProvider.overrideWith((ref) => Stream.value('a')),
                accountDatabaseProvider.overrideWith((ref) async => db),
                themeSettingsRepositoryProvider.overrideWith(
                  (ref) async => null,
                ),
                connectivityProvider.overrideWithValue(const AsyncData(false)),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: SettingsScreen(
                  profile: AccountProfile.fromJson({
                    'id': 'a',
                    'role': role,
                    'display_name': 'Alex',
                  }),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await reveal(tester, find.text('Privacy notice'));
          await tester.tap(find.text('Privacy notice'));
          await tester.pumpAndSettle();
          expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
          expect(find.text(privacySummary), findsOneWidget);
          await reveal(tester, find.text('AI processing'));
          expect(find.text(privacyNoticeSections.last.body), findsOneWidget);
          expect(
            privacyNoticeSections.last.body,
            contains('to Google for processing with Gemini'),
          );
          expect(find.byType(Checkbox), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(
            (await tester.runAsync(() => db.readProfile('a')))!.privacyVersion,
            'original',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'Cancel is primary; confirmed sign-out is busy, retries retained-session failure and reaches signed-out fixture',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final ids = StreamController<String?>.broadcast();
      FlutterSecureStorage.setMockInitialValues({});
      String? account = 'a:session';
      var fail = true, calls = 0;
      var gate = Completer<void>();
      final service = PushRegistration(
        account: () => account,
        canRegister: () async => false,
        getToken: () async => null,
        deviceHash: () async => 'fixture',
        register: (_, _) async {},
        unregister: (_) async {},
        deleteToken: () async {},
        signOut: () async {
          calls++;
          await gate.future;
          if (fail) throw StateError('fixture retained session');
          account = null;
          ids.add(null);
        },
      );
      addTearDown(() async {
        await tester.runAsync(() async {
          await ids.close();
          await db.close();
        });
        service.dispose();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserIdProvider.overrideWith((ref) async* {
              yield 'a';
              yield* ids.stream;
            }),
            accountDatabaseProvider.overrideWith((ref) async => db),
            themeSettingsRepositoryProvider.overrideWith((ref) async => null),
            pushRegistrationProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Consumer(
              builder: (context, ref, _) =>
                  ref.watch(authUserIdProvider).asData?.value == null
                  ? const Scaffold(body: Text('Sign-in fixture'))
                  : SettingsScreen(
                      profile: AccountProfile.fromJson({
                        'id': 'a',
                        'role': 'student',
                        'display_name': 'Alex',
                      }),
                    ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(tester.widget<FiloButton>(button('Cancel')).secondary, isFalse);
      expect(tester.widget<FiloButton>(button('Sign out')).secondary, isTrue);
      await tester.tap(button('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(button('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Signing out\u2026'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Retry'));
      expect(find.text("Couldn't sign out. Try again."), findsOneWidget);
      fail = false;
      gate = Completer<void>()..complete();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(button('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in fixture'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'safer confirmation dismisses without confirming and defaults remain unchanged',
    (tester) async {
      bool? result;
      var safer = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showFiloConfirmation(
                  context,
                  title: 'Sign out?',
                  message: 'Fixture',
                  confirmLabel: 'Sign out',
                  cancelLabel: 'Cancel',
                  cancelIsPrimary: safer,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isFalse);
      safer = false;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.widget<FiloButton>(button('Sign out')).secondary, isFalse);
      await tester.tap(button('Sign out'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );

  test('actual router replaces an authenticated route with sign-in on local session removal', () async {
    final session = Session.fromJson({
      'access_token': 'fixture',
      'token_type': 'bearer',
      'user': {
        'id': 'a',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'created_at': '2026-11-02T00:00:00Z',
      },
    })!;
    final sessions = StreamController<Session?>.broadcast();
    final container = ProviderContainer(
      overrides: [
        loginSessionProvider.overrideWith((ref) async* {
          yield session;
          yield* sessions.stream;
        }),
      ],
    );
    final subscription = container.listen(appRouterProvider, (_, _) {});
    final auth = container.listen(loginSessionProvider, (_, _) {});
    addTearDown(() async {
      subscription.close();
      auth.close();
      container.dispose();
      await sessions.close();
    });
    final router = container.read(appRouterProvider);
    await container.read(loginSessionProvider.future);
    await Future<void>.delayed(Duration.zero);
    router.go('/home');
    expect(router.routeInformationProvider.value.uri.path, '/home');
    sessions.add(null);
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    expect(router.routeInformationProvider.value.uri.path, '/sign-in');
  });

  test('sign-out retains file bytes and index; another account is isolated and original account reopens', () async {
    final root = await Directory.systemTemp.createTemp('filo-sign-out-');
    final manager = UserDatabaseManager(directoryProvider: () async => root);
    addTearDown(() async {
      await manager.close();
      await root.delete(recursive: true);
    });
    final file = File('${root.path}/files/a/blobs/lesson.txt');
    await file.parent.create(recursive: true);
    await file.writeAsString('Retained offline text');
    final a = await manager.openForUser('a');
    await a.customStatement(
      "INSERT INTO local_files(id,name,relative_path,size,source,created_at,updated_at) VALUES('file','lesson.txt','blobs/lesson.txt',21,'download',1,1)",
    );
    await a.customStatement(
      "INSERT INTO app_settings(key,value) VALUES('theme','dark')",
    );
    String? account = 'a:session';
    final service = PushRegistration(
      account: () => account,
      canRegister: () async => false,
      getToken: () async => null,
      deviceHash: () async => 'fixture',
      register: (_, _) async {},
      unregister: (_) async {},
      deleteToken: () async {},
      signOut: () async {
        await manager.close();
        account = null;
      },
    );
    await service.leave();
    expect(account, isNull);
    final b = await manager.openForUser('b');
    expect(await b.select(b.localFiles).get(), isEmpty);
    final restored = await manager.openForUser('a');
    expect(
      (await restored.select(restored.localFiles).getSingle()).relativePath,
      'blobs/lesson.txt',
    );
    expect(await file.readAsString(), 'Retained offline text');
    expect(
      (await restored
              .customSelect("SELECT value FROM app_settings WHERE key='theme'")
              .getSingle())
          .read<String>('value'),
      'dark',
    );
    service.dispose();
  });
}
