import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/onboarding/application/profile_photo_picker.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/onboarding/domain/profile_photo.dart';
import 'package:filo/features/settings/application/profile_settings.dart';
import 'package:filo/features/settings/application/theme_settings.dart';
import 'package:filo/features/settings/presentation/edit_profile_screen.dart';
import 'package:filo/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AccountProfile profile(
  String role, {
  String name = 'Alex',
  String? school = 'School',
  String? path,
}) => AccountProfile.fromJson({
  'id': 'user-1',
  'role': role,
  'display_name': name,
  'school': school,
  'email': 'fixture@example.invalid',
  'google_photo_url': null,
  'avatar_path': path,
  'privacy_accepted_at': '2026-10-15T00:00:00Z',
  'privacy_version': 'original',
  'deleted_at': null,
  'created_at': '2026-10-15T00:00:00Z',
  'updated_at': '2026-11-02T01:00:00Z',
});

class FakeProfileCache extends ProfileCache {
  FakeProfileCache(AppDatabase database, this.saved)
    : super(database, 'user-1');
  AccountProfile saved;
  final changes = StreamController<AccountProfile>.broadcast();
  int saves = 0;
  bool fail = false;
  @override
  Stream<AccountProfile?> watch() async* {
    yield saved;
    yield* changes.stream;
  }

  @override
  Future<void> save(AccountProfile profile) async {
    saves++;
    if (fail) throw StateError('fixture disk unavailable');
    saved = profile;
    changes.add(profile);
  }
}

class FakeEditRepository extends ProfileRepository {
  FakeEditRepository(super.client, this.original);
  final AccountProfile original;
  int edits = 0;
  bool fail = false;
  ProfilePhotoDraft? lastPhoto;
  Completer<AccountProfile>? pending;
  @override
  Future<AccountProfile> edit({
    required String userId,
    required String name,
    required String school,
    ProfilePhotoDraft? photo,
  }) async {
    edits++;
    lastPhoto = photo;
    if (fail) throw const ProfileEditException();
    if (pending != null) return pending!.future;
    return profile(
      original.role.name,
      name: name.trim(),
      school: school.trim().isEmpty ? null : school.trim(),
      path: photo == null
          ? original.avatarPath
          : '$userId/${photo.id}.${photo.extension}',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'compression bounds a large noisy image and preserves aspect ratio',
    () async {
      final random = Random(13);
      final pixels = Uint8List.fromList(
        List.generate(
          900 * 600 * 4,
          (i) => i % 4 == 3 ? 255 : random.nextInt(256),
        ),
      );
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        900,
        600,
        ui.PixelFormat.rgba8888,
        decoded.complete,
      );
      final image = await decoded.future;
      late Uint8List input;
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        input = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
      expect(input.length, greaterThan(ProfilePhotoDraft.maxBytes));
      final draft = await ProfilePhotoDraft.compress(input);
      expect(draft.bytes.length, lessThanOrEqualTo(ProfilePhotoDraft.maxBytes));
      expect(draft.contentType, 'image/png');
      final codec = await ui.instantiateImageCodec(draft.bytes);
      try {
        final output = (await codec.getNextFrame()).image;
        try {
          expect(max(output.width, output.height), lessThanOrEqualTo(512));
          expect(output.width / output.height, closeTo(1.5, 0.01));
        } finally {
          output.dispose();
        }
      } finally {
        codec.dispose();
      }
    },
  );

  test('compression rejects unsupported and corrupt input', () async {
    await expectLater(
      ProfilePhotoDraft.compress(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    await expectLater(
      ProfilePhotoDraft.compress(Uint8List.fromList([255, 216, 255, 0])),
      throwsA(anything),
    );
  });

  test('cache saves confirmed consent/timestamps, clears optional fields, and survives reopening', () async {
    final directory = await Directory.systemTemp.createTemp(
      'filo-edit-profile-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/profile.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    await ProfileCache(db, 'user-1').save(
      profile(
        'instructor',
        name: 'Changed',
        school: null,
        path: 'user-1/new.png',
      ),
    );
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final cached = (await db.readProfile('user-1'))!;
    expect(cached.displayName, 'Changed');
    expect(cached.school, isNull);
    expect(cached.avatarPath, 'user-1/new.png');
    expect(cached.role, 'instructor');
    expect(cached.email, 'fixture@example.invalid');
    expect(cached.privacyVersion, 'original');
    expect(cached.privacyAcceptedAt!.toUtc(), DateTime.utc(2026, 10, 15));
    expect(cached.createdAt.toUtc(), DateTime.utc(2026, 10, 15));
  });

  test('cache refuses incomplete/foreign profiles without wiping existing protected fields', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cache = ProfileCache(db, 'user-1');
    await cache.save(profile('student'));
    await expectLater(
      cache.save(
        AccountProfile.fromJson({
          'id': 'user-1',
          'role': 'student',
          'display_name': 'Incomplete',
        }),
      ),
      throwsStateError,
    );
    await expectLater(
      ProfileCache(db, 'other').save(profile('student')),
      throwsStateError,
    );
    expect((await db.readProfile('user-1'))!.privacyVersion, 'original');
  });

  Future<void> reveal(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(
        target,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
  Finder button(String label) => find.byWidgetPredicate(
    (widget) => widget is FiloButton && widget.label == label,
  );

  for (final palette in [AppTheme.light, AppTheme.dark]) {
    for (final role in ['student', 'instructor']) {
      testWidgets(
        '$role edits at ${palette.brightness.name} 130 percent, retains failed drafts, retries local cache offline, updates hub',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          final initial = profile(role);
          final cache = FakeProfileCache(db, initial);
          final client = (await tester.runAsync(
            () async => SupabaseClient(
              'https://example.invalid',
              'fixture',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ))!;
          final repository = FakeEditRepository(client, initial)..fail = true;
          final network = StreamController<bool>.broadcast();
          final photo = ProfilePhotoDraft.fromBytes(
            (await tester.runAsync(
              () => File('assets/brand/google-g.png').readAsBytes(),
            ))!,
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await tester.runAsync(() async {
              await network.close();
              await cache.changes.close();
              await db.close();
              await client.dispose();
            });
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authUserIdProvider.overrideWith(
                  (ref) => Stream.value('user-1'),
                ),
                profileCacheProvider.overrideWith((ref) async => cache),
                profileRepositoryProvider.overrideWithValue(repository),
                profilePhotoPickerProvider.overrideWithValue(() async => photo),
                themeSettingsRepositoryProvider.overrideWith(
                  (ref) async => null,
                ),
                connectivityProvider.overrideWith((ref) async* {
                  yield true;
                  yield* network.stream;
                }),
              ],
              child: MaterialApp(
                theme: palette,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: SettingsScreen(profile: initial),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit profile'));
          await tester.pumpAndSettle();
          expect(find.byType(TextFormField), findsNWidgets(2));
          expect(
            find.byWidgetPredicate(
              (w) => w is FiloIcon && w.icon == FiloIcons.lock,
            ),
            findsNWidgets(2),
          );
          await tester.enterText(find.byType(TextFormField).at(0), ' Changed ');
          await tester.enterText(
            find.byType(TextFormField).at(1),
            ' New school ',
          );
          network.add(false);
          await tester.pumpAndSettle();
          await reveal(tester, button('Save'));
          expect(tester.widget<FiloButton>(button('Save')).onPressed, isNull);
          expect(
            find.text("You're offline. Connect to save your changes."),
            findsOneWidget,
          );
          network.add(true);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            button('Choose photo'),
            -250,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(button('Choose photo'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(ClipOval),
            -250,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(EditProfileScreen),
              matching: find.byType(ClipOval),
            ),
            findsOneWidget,
          );
          await reveal(tester, button('Save'));
          await tester.tap(button('Save'));
          await tester.pumpAndSettle();
          expect(
            find.text("Couldn't save your changes. Try again."),
            findsOneWidget,
          );
          expect(repository.lastPhoto!.id, photo.id);
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).first)
                .controller!
                .text,
            ' Changed ',
          );
          repository.fail = false;
          cache.fail = true;
          await reveal(tester, button('Retry'));
          await tester.tap(button('Retry'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              "Your profile was saved online, but Filo couldn't update its saved copy on this device. Try again.",
            ),
            findsOneWidget,
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(EditProfileScreen)),
          );
          expect(
            container.read(accountProfileProvider('user-1'))!.name,
            'Changed',
          );
          expect(repository.edits, 2);
          network.add(false);
          await tester.pumpAndSettle();
          cache.fail = false;
          await reveal(tester, button('Retry'));
          await tester.tap(button('Retry'));
          await tester.pumpAndSettle();
          expect(repository.edits, 2);
          expect(cache.saves, 2);
          expect(find.text('Changes saved.'), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('Changed'), findsOneWidget);
          expect(find.text('New school'), findsOneWidget);
          expect(find.text('fixture@example.invalid'), findsOneWidget);
          expect(cache.saved.role.name, role);
          expect(cache.saved.row['privacy_version'], 'original');
        },
      );
    }
  }

  testWidgets(
    'cancel/invalid picker preserve the avatar and back confirms unsaved edits',
    (tester) async {
      var picks = 0;
      final initial = profile('student');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserIdProvider.overrideWith((ref) => Stream.value('user-1')),
            connectivityProvider.overrideWithValue(const AsyncData(true)),
            profilePhotoPickerProvider.overrideWithValue(() async {
              if (picks++ == 0) return null;
              throw const FormatException('Unreadable fixture photo.');
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditProfileScreen(profile: initial),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(button('Choose photo'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.tap(button('Choose photo'));
      await tester.pumpAndSettle();
      expect(find.text('Unreadable fixture photo.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Unsaved name');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Unsaved name',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'late save after A to B to A cannot publish identity or write cache',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final initial = profile('student');
      final cache = FakeProfileCache(db, initial);
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.invalid',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ))!;
      final repository = FakeEditRepository(client, initial)
        ..pending = Completer<AccountProfile>();
      final accounts = StreamController<String?>.broadcast();
      addTearDown(() async {
        if (!repository.pending!.isCompleted)
          repository.pending!.complete(profile('student', name: 'Late name'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(() async {
          await accounts.close();
          await cache.changes.close();
          await db.close();
          await client.dispose();
        });
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserIdProvider.overrideWith((ref) async* {
              yield 'user-1';
              yield* accounts.stream;
            }),
            connectivityProvider.overrideWithValue(const AsyncData(true)),
            profileRepositoryProvider.overrideWithValue(repository),
            profileCacheProvider.overrideWith((ref) async => cache),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: EditProfileScreen(profile: initial),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EditProfileScreen)),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Late name');
      await reveal(tester, button('Save'));
      await tester.tap(button('Save'));
      await tester.pump();
      accounts.add('other');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      accounts.add('user-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      repository.pending!.complete(profile('student', name: 'Late name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(cache.saves, 0);
      expect(container.read(confirmedProfileProvider), isNull);
      expect(find.text('fixture@example.invalid'), findsNothing);
      expect(find.text('Changes saved.'), findsNothing);
    },
  );
}
