import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/files/presentation/file_viewer_screen.dart';
import 'package:filo/features/files/presentation/my_files_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/study/study_source_reader_test.dart' show sourceFixture;

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final state in ['loaded', 'empty', 'loading', 'error']) {
      testWidgets(
        'personal Files $state ${theme.brightness.name} at 320dp / 130%',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = AppDatabase(NativeDatabase.memory());
          final directory = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('filo-a11y-files-'),
          ))!;
          final repository = FilesRepository(db, FileStorage(directory));
          final file = await tester.runAsync(
            () => sourceFixture(
              db,
              directory,
              'notes',
              name: 'Long descriptive class notes for the upcoming lesson.txt',
            ),
          );
          final pending = Completer<FilesRepository?>();
          final snapshots = StreamController<List<LocalFileRecord>>.broadcast();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            await tester.runAsync(() async {
              await snapshots.close();
              await db.close();
              await directory.delete(recursive: true);
            });
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                filesRepositoryProvider.overrideWith((ref) async {
                  if (state == 'error') throw StateError('Local read failed');
                  if (state == 'loading') return await pending.future;
                  return repository;
                }),
                localFilesProvider.overrideWith((ref) async* {
                  yield state == 'loaded' ? [file!] : <LocalFileRecord>[];
                  yield* snapshots.stream;
                }),
                localFoldersProvider.overrideWith((ref) => Stream.value([])),
              ],
              child: MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: const MyFilesScreen(),
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          if (state == 'loaded') {
            await tester.tap(find.text(file!.name));
            for (var i = 0; i < 10; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(find.byType(FileViewerScreen), findsOneWidget);
            expect(find.byTooltip('Previous text section'), findsOneWidget);
            expect(find.byTooltip('Next text section'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
