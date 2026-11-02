import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/settings/application/storage_settings.dart';
import 'package:filo/features/settings/application/theme_settings.dart';
import 'package:filo/features/settings/presentation/settings_screen.dart';
import 'package:filo/features/settings/presentation/storage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FixtureStorage extends StorageRepository {
  FixtureStorage(super.files);
  var usage = const StorageUsage(1024, 100);
  int clears = 0;
  Completer<StorageUsage>? pendingLoad;
  bool failLoad = false, failClear = false;
  @override
  Future<StorageUsage> load() async {
    if (pendingLoad != null) return pendingLoad!.future;
    if (failLoad) throw StateError('fixture scan failed');
    return usage;
  }

  @override
  Future<StorageUsage> clear(bool Function() isCurrent) async {
    if (!isCurrent()) throw StateError('Account changed');
    clears++;
    if (failClear) throw const FileProblem('fixture partial deletion');
    return usage = const StorageUsage(1024, 0);
  }
}

void main() {
  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is FiloButton && w.label == label);
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  for (final role in ['student', 'instructor']) {
    testWidgets(
      '$role opens T5 in Dark at 130 percent; Cancel, failure and Retry preserve files',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repository = FixtureStorage(
          FilesRepository(db, FileStorage(Directory.systemTemp)),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await tester.runAsync(db.close);
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authUserIdProvider.overrideWith(
                (ref) => Stream.value('account-a'),
              ),
              accountDatabaseProvider.overrideWith((ref) async => db),
              themeSettingsRepositoryProvider.overrideWith((ref) async => null),
              storageRepositoryProvider.overrideWith((ref) async => repository),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: SettingsScreen(
                profile: AccountProfile.fromJson({
                  'id': 'account-a',
                  'role': role,
                  'display_name': 'Alex',
                  'email': 'fixture@example.invalid',
                }),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Storage'));
        await tester.tap(find.text('Storage'));
        await tester.pumpAndSettle();
        expect(find.byType(StorageScreen), findsOneWidget);
        expect(find.text('Downloads and personal files'), findsOneWidget);
        expect(find.text('1.0 KB'), findsOneWidget);
        await reveal(tester, button('Clear cache'));
        await tester.tap(button('Clear cache'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(repository.clears, 0);
        repository.failClear = true;
        await tester.tap(button('Clear cache'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear cache').last);
        await tester.pumpAndSettle();
        expect(
          find.text("Couldn't finish clearing the cache. Try again."),
          findsOneWidget,
        );
        expect(
          find.text(
            'Cache cleared. Your downloaded files are still on this device.',
          ),
          findsNothing,
        );
        repository.failClear = false;
        await reveal(tester, button('Retry'));
        await tester.tap(button('Retry'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear cache').last);
        await tester.pumpAndSettle();
        expect(repository.clears, 2);
        expect(
          find.text(
            'Cache cleared. Your downloaded files are still on this device.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<FiloButton>(button('Clear cache')).onPressed,
          isNull,
        );
        expect(find.text('1.0 KB'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Your files are kept inside Filo'));
        expect(
          find.textContaining('Uninstalling Filo or clearing its app data'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('loading disables actions until measured bytes arrive', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = FixtureStorage(
      FilesRepository(db, FileStorage(Directory.systemTemp)),
    )..pendingLoad = Completer<StorageUsage>();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(db.close);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserIdProvider.overrideWith((ref) => Stream.value('account-a')),
          storageRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const StorageScreen(userId: 'account-a'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FiloButton>(button('Clear cache')).onPressed, isNull);
    expect(tester.widget<FiloButton>(button('Refresh')).onPressed, isNull);
    repository.pendingLoad!.complete(const StorageUsage(1024, 0));
    await tester.pumpAndSettle();
    expect(find.text('1.0 KB'), findsOneWidget);
    expect(tester.widget<FiloButton>(button('Clear cache')).onPressed, isNull);
  });

  testWidgets(
    'scan failure offers read Retry without clearing or reporting zero',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = FixtureStorage(
        FilesRepository(db, FileStorage(Directory.systemTemp)),
      )..failLoad = true;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authUserIdProvider.overrideWith((ref) => Stream.value('account-a')),
            storageRepositoryProvider.overrideWith((ref) async => repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const StorageScreen(userId: 'account-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't read storage usage. Try again."),
        findsOneWidget,
      );
      expect(find.text('0 B'), findsNothing);
      repository.failLoad = false;
      await tester.tap(button('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('1.0 KB'), findsOneWidget);
      expect(repository.clears, 0);
    },
  );
}
