import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:drift/native.dart';
import 'package:filo/core/notifications/push_registration.dart';
import 'package:filo/core/notifications/push_providers.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/settings/application/theme_settings.dart';
import 'package:filo/features/settings/presentation/settings_screen.dart';
import 'package:filo/features/settings/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecoverableThemeRepository extends ThemeSettingsRepository {
  RecoverableThemeRepository(super.database);
  ThemeMode saved = ThemeMode.system;
  bool fail = false;
  @override
  Future<ThemeMode> load() async => saved;
  @override
  Future<void> save(ThemeMode mode) async {
    if (fail) throw StateError('fixture disk failure');
    saved = mode;
  }
}

void main() {
  late AppDatabase database;
  late RecoverableThemeRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = RecoverableThemeRepository(database);
  });
  tearDown(() => database.close());

  Widget app(Widget page) => ProviderScope(
    overrides: [
      connectivityProvider.overrideWithValue(const AsyncData(true)),
      authUserIdProvider.overrideWith((ref) => Stream.value('account-a')),
      accountDatabaseProvider.overrideWith((ref) async => database),
      pushRegistrationProvider.overrideWith(
        (ref) => PushRegistration(
          account: () => 'account-a:session-a',
          canRegister: () async => false,
          getToken: () async => null,
          deviceHash: () async => 'fixture',
          register: (_, _) async {},
          unregister: (_) async {},
          deleteToken: () async {},
          signOut: () async {},
        ),
      ),
      themeSettingsRepositoryProvider.overrideWith((ref) async => repository),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode:
            ref.watch(themeSettingsProvider).asData?.value ?? ThemeMode.system,
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );

  for (final role in ['instructor', 'student']) {
    testWidgets('long $role profile stays usable at 320dp and 130 percent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const name = 'Alexandra Marie Santos with a long account name';
      final profile = AccountProfile.fromJson({
        'id': 'account-a',
        'role': role,
        'display_name': name,
        'school': 'School of Computing and Information Technology',
        'email': 'alexandra.marie.santos@example.invalid',
      });
      await tester.pumpWidget(app(SettingsScreen(profile: profile)));
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
      expect(find.text(profile.role.label), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text(name), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'picker changes brightness immediately, follows System, and retries failed save at 130 percent',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        app(const ThemeSettingsScreen(userId: 'account-a')),
      );
      await tester.pumpAndSettle();
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(ThemeSettingsScreen))).brightness;
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      expect(repository.saved, ThemeMode.dark);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      repository.fail = true;
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      expect(
        find.text("Couldn't save your changes. Try again."),
        findsOneWidget,
      );
      repository.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      expect(repository.saved, ThemeMode.dark);
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'hub sign-out confirmation explains retention and Cancel keeps the hub',
    (tester) async {
      repository.saved = ThemeMode.dark;
      final profile = AccountProfile.fromJson({
        'id': 'account-a',
        'role': 'student',
        'display_name': 'Settings fixture',
        'email': 'fixture@example.invalid',
      });
      await tester.pumpWidget(app(SettingsScreen(profile: profile)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      expect(
        find.text(
          'Your local files will stay on this device. They will be available only to this account when you sign in again.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
