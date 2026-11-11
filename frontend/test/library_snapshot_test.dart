import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_motion_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/files/presentation/my_files_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = DateTime.utc(2026, 11, 5);
LocalFileRecord _file() => LocalFileRecord(
  id: 'file',
  name: 'Notes.pdf',
  relativePath: 'notes.pdf',
  size: 32,
  source: 'import',
  createdAt: _date,
  updatedAt: _date,
);
LocalFolderRecord _folder() => LocalFolderRecord(
  id: 'folder',
  name: 'Resources',
  createdAt: _date,
  updatedAt: _date,
);

void main() {
  test('library snapshots outlive disposed queries, reconcile deletion and reset on account change', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = FilesRepository(db, FileStorage(Directory.systemTemp));
    await db.into(db.localFiles).insert(_file());
    await db.into(db.localFolders).insert(_folder());
    String? account = 'first';
    final container = ProviderContainer(
      overrides: [
        verifiedUserIdProvider.overrideWith((ref) async => account),
        accountDatabaseProvider.overrideWith((ref) async => db),
        filesRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    await container.read(verifiedUserIdProvider.future);
    await container.read(accountDatabaseProvider.future);
    var files = container.listen(localFilesProvider, (_, _) {});
    var folders = container.listen(localFoldersProvider, (_, _) {});
    await container.read(localFilesProvider.future);
    await container.read(localFoldersProvider.future);
    files.close();
    folders.close();
    await container.pump();
    final snapshot = container.read(librarySnapshotProvider);
    expect(snapshot.files!.single.name, 'Notes.pdf');
    expect(snapshot.folders!.single.name, 'Resources');
    expect(() => snapshot.files!.clear(), throwsUnsupportedError);
    await db.delete(db.localFiles).go();
    await db.delete(db.localFolders).go();
    files = container.listen(localFilesProvider, (_, _) {});
    folders = container.listen(localFoldersProvider, (_, _) {});
    await container.read(localFilesProvider.future);
    await container.read(localFoldersProvider.future);
    expect(snapshot.files, isEmpty);
    expect(snapshot.folders, isEmpty);
    files.close();
    folders.close();
    account = null;
    container.invalidate(verifiedUserIdProvider);
    await container.read(verifiedUserIdProvider.future);
    expect(container.read(librarySnapshotProvider).files, isNull);
    expect(container.read(librarySnapshotProvider).folders, isNull);
    container.dispose();
    await db.close();
  });

  testWidgets(
    'returning library displays cached rows before local streams emit',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = FilesRepository(db, FileStorage(Directory.systemTemp));
      final snapshot = LibrarySnapshot()
        ..files = [_file()]
        ..folders = [_folder()];
      final files = StreamController<List<LocalFileRecord>>.broadcast();
      final folders = StreamController<List<LocalFolderRecord>>.broadcast();
      final container = ProviderContainer(
        overrides: [
          filesRepositoryProvider.overrideWith((ref) async => repo),
          librarySnapshotProvider.overrideWith((ref) => snapshot),
          localFilesProvider.overrideWith((ref) => files.stream),
          localFoldersProvider.overrideWith((ref) => folders.stream),
        ],
      );
      await container.read(filesRepositoryProvider.future);
      Widget page() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const MyFilesScreen()),
      );
      await tester.pumpWidget(page());
      expect(find.text('Notes.pdf'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      expect(find.byType(FiloDelayedLoading), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(page());
      expect(find.text('Notes.pdf'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      files.addError(StateError('Read failed'));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't load files. Try again."), findsOneWidget);
      files.add([]);
      folders.add([]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Notes.pdf'), findsNothing);
      expect(find.text('Resources'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await files.close();
      await folders.close();
      await db.close();
    },
  );
}
