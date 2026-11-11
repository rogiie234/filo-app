import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filo/core/widgets/filo_button.dart';
import 'package:filo/core/widgets/filo_widgets.dart'
    show FiloIllustratedEmptyState;
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

final class _PickedFileFixture extends PlatformFile {
  _PickedFileFixture(this.name, {this.path});
  @override
  final String name;
  @override
  final String? path;
  @override
  Uri get uri => path == null
      ? Uri.parse('content://fixture/unreadable')
      : Uri.file(path!);
  @override
  int? lengthSync() => 32;
  @override
  Future<int?> length() async => 32;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected file read');
}

class _PendingFilePicker extends FilePickerPlatform {
  final pending = Completer<List<PlatformFile>>();
  int calls = 0;
  bool fail = false;
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    if (fail) throw StateError('Picker failed');
    return pending.future;
  }
}

class _ConfirmedImportRepository extends FilesRepository {
  _ConfirmedImportRepository(AppDatabase db)
    : super(db, FileStorage(Directory.systemTemp));
  final result = Completer<LocalFileRecord>();

  @override
  Future<LocalFileRecord> importFile(File file, String name, String? folder) =>
      result.future;
}

void main() {
  for (final scenario in [
    'cancel',
    'single',
    'multiple',
    'failure',
    'partial',
  ]) {
    testWidgets('Add files confirmation requires complete success: $scenario', (
      tester,
    ) async {
      final original = FilePickerPlatform.instance;
      final picker = _PendingFilePicker();
      FilePickerPlatform.instance = picker;
      final db = AppDatabase(NativeDatabase.memory());
      final repository = _ConfirmedImportRepository(db);
      final key = GlobalKey<MyFilesScreenState>();
      addTearDown(() async {
        FilePickerPlatform.instance = original;
        await tester.pumpWidget(const SizedBox());
        await db.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filesRepositoryProvider.overrideWith((ref) async => repository),
            librarySnapshotProvider.overrideWith((ref) => LibrarySnapshot()),
            localFilesProvider.overrideWith((ref) => Stream.value([])),
            localFoldersProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MyFilesScreen(key: key),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = key.currentState!.addFiles();
      picker.pending.complete([
        if (scenario != 'cancel')
          _PickedFileFixture('Notes.pdf', path: 'notes.pdf'),
        if (scenario == 'multiple')
          _PickedFileFixture('Other.pdf', path: 'other.pdf'),
        if (scenario == 'partial') _PickedFileFixture('Unreadable.pdf'),
      ]);
      await tester.pump();
      expect(find.text('File added.'), findsNothing);
      expect(find.text('2 files added.'), findsNothing);
      expect(find.text('Please wait?'), findsNothing);
      if (scenario != 'cancel') {
        if (scenario == 'failure') {
          repository.result.completeError(FileProblem('Import failed.'));
        } else {
          final now = DateTime.utc(2026, 11, 5);
          repository.result.complete(
            LocalFileRecord(
              id: 'file',
              name: 'Notes.pdf',
              relativePath: 'notes.pdf',
              size: 32,
              source: 'personal_upload',
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
      await action;
      await tester.pump();
      expect(
        find.text('File added.'),
        scenario == 'single' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('2 files added.'),
        scenario == 'multiple' ? findsOneWidget : findsNothing,
      );
      expect(find.text('Please wait?'), findsNothing);
      final button = tester.widget<FiloButton>(
        find.ancestor(
          of: find.byTooltip('Add files'),
          matching: find.byType(FiloButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      expect(button.iconOnly, isTrue);
      expect(button.minHeight, 72);
      if (scenario == 'failure') {
        expect(find.text('Notes.pdf: Import failed.'), findsOneWidget);
      }
      if (scenario == 'partial') {
        expect(find.text('Could not read Unreadable.pdf.'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'embedded library delegates its guarded file action to the shell',
    (tester) async {
      final original = FilePickerPlatform.instance;
      final picker = _PendingFilePicker();
      FilePickerPlatform.instance = picker;
      final db = AppDatabase(NativeDatabase.memory());
      final repository = FilesRepository(db, FileStorage(Directory.systemTemp));
      final key = GlobalKey<MyFilesScreenState>();
      final busy = <bool>[];
      addTearDown(() async {
        FilePickerPlatform.instance = original;
        await tester.pumpWidget(const SizedBox());
        await db.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filesRepositoryProvider.overrideWith((ref) async => repository),
            librarySnapshotProvider.overrideWith((ref) => LibrarySnapshot()),
            localFilesProvider.overrideWith((ref) => Stream.value([])),
            localFoldersProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MyFilesScreen(
              key: key,
              embedded: true,
              onBusyChanged: busy.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      final action = key.currentState!.addFiles();
      await key.currentState!.addFiles();
      expect(picker.calls, 1);
      expect(busy, [true]);
      picker.pending.complete([]);
      await action;
      await tester.pump();
      expect(busy, [true, false]);
      picker.fail = true;
      await key.currentState!.addFiles();
      await tester.pump();
      expect(busy, [true, false, true, false]);
      expect(
        find.text('Could not complete this file action. Try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'library sorting is explicit and Add files opens one guarded picker directly',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalPicker = FilePickerPlatform.instance;
      final picker = _PendingFilePicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);
      final db = AppDatabase(NativeDatabase.memory());
      final repository = FilesRepository(db, FileStorage(Directory.systemTemp));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      });
      final files = [
        for (final item in [
          ('a', 'Alpha.pdf', 300, 3),
          ('z', 'Zulu.docx', 100, 2),
          ('b', 'Beta.png', 200, 1),
          ('d', 'Delta.pdf', 300, 3),
        ])
          LocalFileRecord(
            id: item.$1,
            name: item.$2,
            relativePath: item.$2,
            size: item.$3,
            source: 'import',
            createdAt: DateTime.utc(2026, 11, item.$4),
            updatedAt: DateTime.utc(2026, 11, item.$4),
          ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filesRepositoryProvider.overrideWith((ref) async => repository),
            librarySnapshotProvider.overrideWith((ref) => LibrarySnapshot()),
            localFilesProvider.overrideWith((ref) => Stream.value(files)),
            localFoldersProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MyFilesScreen(),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.getRect(find.byTooltip('Switch to grid view')).right,
        closeTo(876, .1),
      );
      List<String> names() => tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title! as Text).data!)
          .toList();
      Future<void> sort(String criterion) async {
        await tester.tap(find.byTooltip('Sort files'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, criterion),
        );
        await tester.pumpAndSettle();
      }

      expect(names(), ['Alpha.pdf', 'Beta.png', 'Delta.pdf', 'Zulu.docx']);
      await sort('Type');
      expect(names(), ['Zulu.docx', 'Beta.png', 'Alpha.pdf', 'Delta.pdf']);
      await tester.tap(find.byTooltip('Sort descending'));
      await tester.pumpAndSettle();
      expect(names(), ['Delta.pdf', 'Alpha.pdf', 'Beta.png', 'Zulu.docx']);
      await sort('Date');
      expect(names(), ['Delta.pdf', 'Alpha.pdf', 'Zulu.docx', 'Beta.png']);
      await sort('Size');
      expect(names(), ['Delta.pdf', 'Alpha.pdf', 'Beta.png', 'Zulu.docx']);
      await tester.tap(find.byTooltip('Sort ascending'));
      await tester.pumpAndSettle();
      expect(names(), ['Zulu.docx', 'Beta.png', 'Alpha.pdf', 'Delta.pdf']);
      await tester.tap(find.byTooltip('Filter files'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'PDFs'),
      );
      await tester.pumpAndSettle();
      expect(names(), ['Alpha.pdf', 'Delta.pdf']);
      await tester.tap(find.byTooltip('Switch to grid view'));
      await tester.pumpAndSettle();
      expect(find.text('Beta.png'), findsNothing);
      expect(find.text('Zulu.docx'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Alpha.pdf')).dy,
        tester.getTopLeft(find.text('Delta.pdf')).dy,
      );
      expect(
        tester.getTopLeft(find.text('Alpha.pdf')).dx,
        lessThan(tester.getTopLeft(find.text('Delta.pdf')).dx),
      );
      await tester.tap(find.byTooltip('File actions').first);
      await tester.pumpAndSettle();
      expect(find.text('File actions'), findsOneWidget);
      Navigator.of(tester.element(find.byType(MyFilesScreen))).pop();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pumpAndSettle();
      expect(find.text('Delta.pdf'), findsNothing);
      expect(find.text('Alpha.pdf'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to list view'));
      await tester.pumpAndSettle();
      expect(names(), ['Alpha.pdf', 'Delta.pdf']);
      await tester.tap(find.byTooltip('Filter files'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Spreadsheets'),
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching files.'), findsOneWidget);
      expect(
        tester
            .widget<FiloIllustratedEmptyState>(
              find.byType(FiloIllustratedEmptyState),
            )
            .asset,
        'assets/illustrations/library-empty-folder.png',
      );
      expect(find.text('No files yet.'), findsNothing);
      await tester.tap(find.text('Show all file types'));
      await tester.pumpAndSettle();
      expect(names(), ['Zulu.docx', 'Beta.png', 'Alpha.pdf', 'Delta.pdf']);
      expect(find.byTooltip('Drive backup'), findsOneWidget);
      expect(find.text('Drive backup'), findsNothing);
      await tester.tap(find.byTooltip('Add files'));
      await tester.pump();
      expect(picker.calls, 1);
      expect(find.text('Add to Files'), findsNothing);
      expect(find.text('Upload files'), findsNothing);
      await tester.tap(find.byTooltip('Add files'));
      await tester.pump();
      expect(picker.calls, 1);
      picker.pending.complete([]);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add files'), findsOneWidget);
      picker.fail = true;
      await tester.tap(find.byTooltip('Add files'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not complete this file action. Try again.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Add files'), findsOneWidget);
      picker.fail = false;
      await tester.tap(find.byTooltip('Add files'));
      await tester.pumpAndSettle();
      expect(picker.calls, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'library summaries count nested files and folder header preserves navigation',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final repository = FilesRepository(db, FileStorage(Directory.systemTemp));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await db.close();
      });
      final now = DateTime.utc(2026, 11, 5);
      final folders = [
        LocalFolderRecord(
          id: 'class',
          name: 'BSIT-3A',
          classId: 'class-id',
          createdAt: now,
          updatedAt: now,
        ),
        LocalFolderRecord(
          id: 'nested',
          parentId: 'class',
          name: 'References',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final files = [
        LocalFileRecord(
          id: 'one',
          folderId: 'class',
          name: 'Notes.pdf',
          relativePath: 'one.pdf',
          size: 1024,
          source: 'import',
          createdAt: now,
          updatedAt: now,
        ),
        LocalFileRecord(
          id: 'two',
          folderId: 'nested',
          name: 'Reading.docx',
          relativePath: 'two.docx',
          size: 2048,
          source: 'import',
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filesRepositoryProvider.overrideWith((ref) async => repository),
            librarySnapshotProvider.overrideWith((ref) => LibrarySnapshot()),
            localFilesProvider.overrideWith((ref) => Stream.value(files)),
            localFoldersProvider.overrideWith((ref) => Stream.value(folders)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MyFilesScreen(),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('2 files'), findsOneWidget);
      expect(find.textContaining('Class folder'), findsOneWidget);
      expect(find.textContaining('3.0 KB'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Filter files'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'PDFs'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to grid view'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BSIT-3A'));
      await tester.pumpAndSettle();
      expect(find.text('Class folder'), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);
      expect(find.text('Notes.pdf'), findsOneWidget);
      expect(find.text('References'), findsOneWidget);
      await tester.tap(find.text('References'));
      await tester.pumpAndSettle();
      expect(find.text('No matching files.'), findsOneWidget);
      expect(find.text('No files yet.'), findsNothing);
      expect(find.text('1 file'), findsOneWidget);
      await tester.tap(find.text('BSIT-3A'));
      await tester.pumpAndSettle();
      expect(find.text('Notes.pdf'), findsOneWidget);
      await tester.tap(find.byTooltip('Up to parent folder'));
      await tester.pumpAndSettle();
      expect(find.text('Your library'), findsOneWidget);
      await tester.tap(find.text('New folder'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final input = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      final create = find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate(
          (widget) => widget is FiloButton && widget.label == 'Create folder',
        ),
      );
      expect(tester.widget<FiloButton>(create).onPressed, isNull);
      expect(
        tester
            .getRect(dialog)
            .overlaps(tester.getRect(find.byType(MyFilesScreen))),
        isTrue,
      );
      expect(tester.takeException(), isNull);

      expect(find.text('Folder name'), findsOneWidget);
      await tester.enterText(input, 'bad/name');
      await tester.pumpAndSettle();
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(
        find.text('Enter a name without slashes, up to 255 characters.'),
        findsOneWidget,
      );
      await tester.enterText(input, 'Study notes');
      await tester.pump();
      expect(
        find.text('Enter a name without slashes, up to 255 characters.'),
        findsNothing,
      );
      expect(tester.widget<FiloButton>(create).onPressed, isNotNull);
      await tester.tap(find.byTooltip('Clear name'));
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(tester.widget<FiloButton>(create).onPressed, isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
                librarySnapshotProvider.overrideWith(
                  (ref) => LibrarySnapshot(),
                ),
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
            await tester.scrollUntilVisible(
              find.text('New folder'),
              100,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.text('New folder')),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('New folder'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.text('Cancel'));
            await tester.tap(find.text('Cancel'));
            await tester.pump(const Duration(milliseconds: 300));

            await tester.scrollUntilVisible(
              find.byTooltip('Switch to grid view'),
              100,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byTooltip('Switch to grid view')),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Switch to grid view'));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);

            await tester.scrollUntilVisible(
              find.text(file!.name),
              150,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.text(file!.name)),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(file.name));
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
