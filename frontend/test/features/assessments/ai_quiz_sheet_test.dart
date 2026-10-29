import 'dart:async';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/features/assessments/application/ai_providers.dart';
import 'package:filo/features/assessments/data/ai_quiz_client.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/data/lesson_text_extractor.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/assessments/presentation/ai_quiz_sheet.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class PickedFileFixture extends PlatformFile {
  PickedFileFixture(this.name, this.bytes);
  @override
  final String name;
  final int? bytes;
  @override
  Uri get uri => Uri.file('/not-opened.txt');
  @override
  int? lengthSync() => bytes;
  @override
  Future<int?> length() async => bytes;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected file read');
}

class PickerFixture extends FilePickerPlatform {
  List<PlatformFile> files = [];
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
    expect(type, FileType.custom);
    expect(allowedExtensions, containsAll(['pdf', 'txt', 'png']));
    return files;
  }
}

const contextFixture = AiSourceContext(
  sources: [SourcePrefix('att:one', 'lesson.txt', 4)],
  difficulty: 'medium',
);
Future<AppDatabase> seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customStatement(
    'INSERT INTO file_text_cache VALUES(?,?,?,?,?,?,?)',
    [
      'att:one',
      'Rule',
      4,
      DateTime.now().millisecondsSinceEpoch,
      lessonCacheByteCap,
      '[]',
      lessonExtractorRevision,
    ],
  );
  return db;
}

Widget screen(FileTextCache cache, AiQuizClient client, {bool online = true}) =>
    ProviderScope(
      overrides: [
        fileTextCacheProvider.overrideWith((ref) async => cache),
        aiQuizClientProvider.overrideWithValue(client),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        classFilesProvider('class')
            .overrideWith((ref) => Stream.value(<ClassFileEntry>[])),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: AiQuizSheet(
                classId: 'class',
                quizId: 'quiz',
                initialContext: contextFixture,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'phone picker reads current length API; cancel and bad files retain ready text',
    (tester) async {
      final db = await seed();
      addTearDown(db.close);
      final cache = FileTextCache(db);
      await cache.acceptPrivacy();
      final previous = FilePickerPlatform.instance, picker = PickerFixture();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = previous);
      final client = AiQuizClient(
        invoke: (_) async => throw StateError('Unexpected request'),
        isOnline: () => true,
        currentUser: () => 'owner',
      );
      await tester.pumpWidget(screen(cache, client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From phone'));
      await tester.pumpAndSettle();
      final pick = find.widgetWithText(OutlinedButton, 'Select from phone');
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(find.text('lesson.txt'), findsOneWidget);
      picker.files = [
        PickedFileFixture('unknown.txt', null),
        PickedFileFixture('large.txt', LessonTextExtractor.maxFileBytes + 1),
      ];
      await tester.tap(pick);
      await tester.pumpAndSettle();
      expect(find.textContaining('Size unavailable'), findsOneWidget);
      expect(
        find.textContaining('file size could not be read'),
        findsOneWidget,
      );
      expect(find.textContaining('limit is 10 MB'), findsOneWidget);
      expect(find.textContaining('Ready · 4 characters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('count controls stop at 20 and permit reducing the total', (
    tester,
  ) async {
    final db = await seed();
    addTearDown(db.close);
    final cache = FileTextCache(db);
    await cache.acceptPrivacy();
    final client = AiQuizClient(
      invoke: (_) async => throw StateError('Unexpected request'),
      isOnline: () => true,
      currentUser: () => 'owner',
    );
    await tester.pumpWidget(screen(cache, client));
    await tester.pumpAndSettle();
    final more = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'More Essay questions',
    );
    await tester.ensureVisible(more);
    for (var i = 0; i < 9; i++) {
      await tester.tap(more);
      await tester.pump();
    }
    expect(find.text('20 of 20 questions'), findsOneWidget);
    expect(tester.widget<IconButton>(more).onPressed, isNull);
    await tester.tap(find.byTooltip('Fewer Essay questions'));
    await tester.pump();
    expect(find.text('19 of 20 questions'), findsOneWidget);
    expect(tester.widget<IconButton>(more).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'first use needs OK; offline disables generation without losing ready source',
    (tester) async {
      final db = await seed();
      addTearDown(db.close);
      final cache = FileTextCache(db);
      final client = AiQuizClient(
        invoke: (_) async => throw StateError('Unexpected network'),
        isOnline: () => false,
        currentUser: () => 'owner',
      );
      await tester.pumpWidget(screen(cache, client, online: false));
      await tester.pumpAndSettle();
      expect(find.text('Before using AI'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await cache.privacyAccepted(), true);
      expect(find.textContaining('Ready · 4 characters'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Generate'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancel keeps sources/counts, displays safe message and ignores late failure',
    (tester) async {
      final db = await seed();
      addTearDown(db.close);
      final cache = FileTextCache(db);
      await cache.acceptPrivacy();
      final result = Completer<dynamic>();
      var calls = 0;
      final client = AiQuizClient(
        invoke: (_) {
          calls++;
          return result.future;
        },
        isOnline: () => true,
        currentUser: () => 'owner',
      );
      await tester.pumpWidget(screen(cache, client));
      await tester.pumpAndSettle();
      final generate = find.widgetWithText(FilledButton, 'Generate');
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pump();
      final cancel = find.widgetWithText(TextButton, 'Cancel');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text(aiErrorMessages['CANCELLED']!), findsOneWidget);
      expect(find.textContaining('Ready · 4 characters'), findsOneWidget);
      expect(find.text('11 of 20 questions'), findsOneWidget);
      result.completeError(StateError('PRIVATE_ERROR'));
      await tester.pump();
      expect(calls, 1);
      expect(find.textContaining('PRIVATE_ERROR'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
