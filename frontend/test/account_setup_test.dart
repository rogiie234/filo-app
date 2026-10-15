import 'package:filo/features/onboarding/application/notification_permission.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/onboarding/presentation/account_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AccountProfile profile(AccountRole role) => AccountProfile.fromJson({
  'id': 'user-1',
  'role': role.name,
  'display_name': 'Alex',
  'email': 'alex@example.com',
  'school': 'School',
});

class FakeProfiles extends ProfileRepository {
  FakeProfiles(super.client);
  AccountProfile? saved;
  bool failLookup = false, loseResponse = false;
  int inserts = 0;

  @override
  Future<AccountProfile?> fetch() async {
    if (failLookup) throw StateError('offline');
    return saved;
  }

  @override
  Future<AccountProfile> create({
    required AccountRole role,
    required String name,
    required String school,
    required bool consent,
  }) async {
    if (saved != null) return saved!;
    inserts++;
    saved = profile(role);
    if (loseResponse) throw StateError('response lost');
    return saved!;
  }
}

class FakeNotifications extends NotificationPermission {
  bool done = false, deny = false;
  int requests = 0;
  @override
  Future<bool> handled(String userId) async => done;
  @override
  Future<void> markHandled(String userId) async {
    done = true;
  }

  @override
  Future<void> request() async {
    requests++;
    if (deny) throw StateError('permission unavailable');
  }
}

void main() {
  Future<FakeProfiles> makeRepository(WidgetTester tester) async =>
      FakeProfiles(
        (await tester.runAsync(
          () async => SupabaseClient(
            'https://example.supabase.co',
            'test',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ))!,
      );
  Future<void> launch(
    WidgetTester tester,
    FakeProfiles repository,
    FakeNotifications notifications,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(repository.client.dispose));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          notificationPermissionProvider.overrideWithValue(notifications),
          onboardingUserProvider.overrideWithValue(
            User(
              id: 'user-1',
              appMetadata: {},
              userMetadata: {'full_name': 'Alex'},
              aud: 'authenticated',
              createdAt: '',
              email: 'alex@example.com',
            ),
          ),
        ],
        child: const MaterialApp(home: AccountSetupScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  for (final role in AccountRole.values) {
    testWidgets(
      '${role.label} confirms consent, retries lost response, and reaches Home',
      (tester) async {
        final repository = (await makeRepository(tester))..loseResponse = true;
        final notifications = FakeNotifications()..deny = true;
        await launch(tester, repository, notifications);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue'),
              )
              .onPressed,
          isNull,
        );
        await tap(tester, role.label);
        await tap(tester, 'Continue');
        await tap(tester, 'Go back');
        expect(find.text('Choose your role'), findsOneWidget);
        await tap(tester, 'Continue');
        await tap(tester, 'Confirm role');
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          false,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Create account'),
              )
              .onPressed,
          isNull,
        );
        await tap(tester, 'Read Privacy Notice');
        expect(find.text('Privacy Notice'), findsOneWidget);
        await tap(tester, 'Close');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tap(tester, 'Create account');
        expect(
          find.text(
            'We couldn’t finish setting up your account. Please try again.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Alex',
        );
        await tap(tester, 'Retry');
        expect(repository.inserts, 1);
        await tap(tester, 'Enable notifications');
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('${role.label} account'), findsOneWidget);
        expect(notifications.done, true);
        expect(notifications.requests, 1);
        expect(find.text('Choose your role'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'lookup failure retries without treating failure as a new account',
    (tester) async {
      final repository = (await makeRepository(tester))..failLookup = true;
      final notifications = FakeNotifications()..done = true;
      await launch(tester, repository, notifications);
      expect(find.text('Choose your role'), findsNothing);
      repository.failLookup = false;
      repository.saved = profile(AccountRole.instructor);
      await tap(tester, 'Retry');
      expect(find.text('Instructor account'), findsOneWidget);
      expect(find.text('Enable notifications'), findsNothing);
    },
  );

  testWidgets(
    'saved profile resumes notification prompt and skip reaches Home',
    (tester) async {
      final repository = (await makeRepository(tester))
        ..saved = profile(AccountRole.student);
      final notifications = FakeNotifications();
      await launch(tester, repository, notifications);
      expect(find.text('Choose your role'), findsNothing);
      await tap(tester, 'Not now');
      expect(find.text('Home'), findsOneWidget);
      expect(notifications.done, true);
      expect(notifications.requests, 0);
    },
  );
}
