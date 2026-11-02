import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/core/ai/ai_request_providers.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/assessments/data/file_text_cache.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/study/application/study_source_reader.dart';
import 'package:filo/features/study/application/student_ai_providers.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:filo/features/study/presentation/study_home_screen.dart';
import 'package:filo/features/study/presentation/study_notebook_screen.dart';
import 'package:filo/features/study/presentation/study_privacy.dart';
import 'package:filo/features/study/presentation/study_source_picker.dart';
import 'package:filo/features/study/presentation/study_saved_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'study_source_reader_test.dart' show TextFixtureExtractor, sourceFixture;

// Allow real file/isolate futures to drain without running a platform extractor.
Future<void> settleStudy(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  late AppDatabase db;
  late Directory root;
  late FilesRepository files;
  late StudySourceReader reader;
  late AiRequestGuard guard;
  late StudentAiClient client;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    guard = AiRequestGuard();
    client = StudentAiClient(
      invoke: (_, __, ___) async =>
          throw StateError('Read-only flow must not dispatch'),
      loadSources: (_) async => [],
      isOnline: () => false,
      currentAccount: () => 'student',
      guard: guard,
    );
    root = await Directory.systemTemp.createTemp('study-ui-');
    files = FilesRepository(db, FileStorage(root));
    reader = StudySourceReader(
      files: files,
      sources: NotebookSourceRepository(db),
      cache: FileTextCache(db),
      extractor: TextFixtureExtractor(),
      cancel: AiCancelToken(),
      isCurrent: () => true,
    );
  });
  tearDown(() async {
    reader.cancel.cancel();
    await guard.close();
    await db.close();
    await root.delete(recursive: true);
  });

  Widget app(Widget child) => ProviderScope(
    overrides: [
      accountDatabaseProvider.overrideWith((ref) async => db),
      filesRepositoryProvider.overrideWith((ref) async => files),
      studySourceReaderProvider.overrideWith((ref) async => reader),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
      aiRequestGuardProvider.overrideWithValue(guard),
      studentAiClientProvider.overrideWithValue(client),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );

  testWidgets(
    'offline home creates, opens all four empty tools, renames and deletes at 130% text',
    (tester) async {
      await tester.pumpWidget(app(const StudyHomeScreen()));
      await settleStudy(tester);
      expect(find.text('Start your first notebook.'), findsOneWidget);
      expect(
        find.text("You're offline. Showing saved content."),
        findsOneWidget,
      );
      await tester.tap(find.text('New notebook'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Biology');
      await tester.pump();
      await tester.tap(find.text('Create notebook'));
      await settleStudy(tester);
      expect(find.text('General knowledge'), findsOneWidget);
      for (final entry in {
        'Chat': 'Ask a question to start a chat.',
        'Summary': 'Generate a short summary of your sources.',
        'Flashcards': 'Generate flashcards to review the main ideas.',
        'Practice quiz': 'No practice quizzes saved yet.',
      }.entries) {
        await tester.scrollUntilVisible(
          find.text(entry.key),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(entry.key));
        await settleStudy(tester);
        expect(find.text(entry.value), findsOneWidget);
        if (entry.key == 'Practice quiz')
          expect(find.text('Generate practice quiz'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Notebook options').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Science');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settleStudy(tester);
      expect(find.text('Science'), findsOneWidget);
      await tester.tap(find.byTooltip('Notebook options').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Delete this notebook and everything in it? Your original files are not affected.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FiloButton, 'Delete'));
      await settleStudy(tester);
      expect(find.text('Start your first notebook.'), findsOneWidget);
      expect(
        await tester.runAsync(() => NotebookRepository(db).watchAll().first),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'saved tools show persisted content without generating or changing it',
    (tester) async {
      final id = await NotebookRepository(db).create('Saved tools');
      await StudySummaryRepository(db).save(id, 'Saved summary text');
      final chat = await StudyChatRepository(db).create(id, 'Saved chat');
      await StudyChatRepository(db).addMessage(
        chatId: chat,
        role: 'assistant',
        content: 'Saved answer',
        mode: 'general',
      );
      await StudyDeckRepository(db).create(
        notebookId: id,
        title: 'Saved deck',
        settings: const StudyDeckSettings(count: 5),
        cards: const [
          StudyCardInput(front: 'Card question', back: 'Card answer'),
        ],
      );
      await StudyQuizRepository(db).create(
        notebookId: id,
        title: 'Saved quiz',
        settings: const StudyQuizSettings(count: 5, types: ['true_false']),
        questions: const [
          StudyQuestionInput(
            type: 'true_false',
            prompt: 'Saved statement',
            explanation: 'Saved explanation',
            correctBoolean: true,
          ),
        ],
      );
      for (final entry in {
        StudyTool.chat: ('Saved chat', 'Saved answer'),
        StudyTool.summary: ('', 'Saved summary text'),
        StudyTool.decks: ('Saved deck', 'Card answer'),
        StudyTool.quizzes: ('Saved quiz', 'Saved explanation'),
      }.entries) {
        await tester.pumpWidget(
          app(StudySavedScreen(notebookId: id, tool: entry.key)),
        );
        await settleStudy(tester);
        if (entry.value.$1.isNotEmpty) {
          await tester.tap(find.text(entry.value.$1));
          await settleStudy(tester);
        }
        expect(find.text(entry.value.$2), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(
        (await tester.runAsync(
          () => StudyChatRepository(db).watchMessages(chat).first,
        ))!.length,
        1,
      );
    },
  );

  testWidgets(
    'notebook limit is explained without creating a twenty-first notebook',
    (tester) async {
      for (var i = 0; i < 20; i++) {
        await NotebookRepository(db).create('Notebook $i');
      }
      await tester.pumpWidget(app(const StudyHomeScreen()));
      await settleStudy(tester);
      await tester.tap(find.text('New notebook'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'You can have up to 20 notebooks. Delete one to add another.',
        ),
        findsOneWidget,
      );
      expect(
        (await tester.runAsync(() => NotebookRepository(db).watchAll().first))!
            .length,
        20,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'picker processes a failed class file and a good personal file independently',
    (tester) async {
      final id = await NotebookRepository(db).create('Files');
      await tester.runAsync(() async {
        await sourceFixture(
          db,
          root,
          'bad',
          attachment: 'bad',
          name: 'empty.txt',
          text: '',
        );
        await sourceFixture(
          db,
          root,
          'good',
          name: 'personal.txt',
          text: 'Personal text',
        );
      });
      await tester.pumpWidget(app(StudySourcePicker(notebookId: id)));
      await settleStudy(tester);
      await tester.tap(find.text('empty.txt'));
      await tester.tap(find.text('My files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('personal.txt'));
      await tester.tap(find.text('Add files'));
      await settleStudy(tester);
      expect(find.textContaining('Ready'), findsOneWidget);
      await tester.tap(find.text('Downloaded from classes'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No readable text found in this file.'),
        findsOneWidget,
      );
      final sources = (await tester.runAsync(
        () => NotebookSourceRepository(db).watch(id).first,
      ))!;
      expect(sources.length, 1);
      expect(sources.single.name, 'personal.txt');
      await tester.runAsync(
        () => File('${root.path}/bad.txt').writeAsString('Readable now'),
      );
      await tester.tap(find.text('Try again'));
      await settleStudy(tester);
      expect(find.textContaining('Ready'), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => NotebookSourceRepository(db).watch(id).first,
        ))!.length,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'a missing original shows a note and leaves its saved text intact',
    (tester) async {
      final id = await NotebookRepository(db).create('Saved');
      final file = (await tester.runAsync(
        () => sourceFixture(db, root, 'source', attachment: 'source'),
      ))!;
      await tester.runAsync(
        () => reader.add(id, file, operation: AiCancelToken()),
      );
      await tester.runAsync(
        () => File('${root.path}/${file.relativePath}').delete(),
      );
      await tester.pumpWidget(app(StudyNotebookScreen(notebookId: id)));
      await settleStudy(tester);
      expect(
        find.text(
          'An original file is no longer on this phone. Its saved text is still available.',
        ),
        findsOneWidget,
      );
      expect(
        (await tester.runAsync(
          () => NotebookSourceRepository(db).watch(id).first,
        ))!.single.extractedText,
        'Local text',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'privacy cancel prevents dispatch, OK persists, and menu-style review remains available',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        app(
          Consumer(
            builder: (context, ref, _) => Column(
              children: [
                TextButton(
                  onPressed: () async {
                    if (await ensureStudyPrivacy(context, ref)) requests++;
                  },
                  child: const Text('Request'),
                ),
                TextButton(
                  onPressed: () =>
                      ensureStudyPrivacy(context, ref, showAgain: true),
                  child: const Text('Review'),
                ),
              ],
            ),
          ),
        ),
      );
      await settleStudy(tester);
      await tester.tap(find.text('Request'));
      await settleStudy(tester);
      expect(find.text('Before you use AI Study'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FiloButton, 'Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FiloButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(await StudyPrivacy(db).accepted(), isFalse);
      await tester.tap(find.text('Request'));
      await settleStudy(tester);
      await tester.ensureVisible(find.widgetWithText(FiloButton, 'OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FiloButton, 'OK'));
      await settleStudy(tester);
      expect(requests, 1);
      expect(await StudyPrivacy(db).accepted(), isTrue);
      await tester.tap(find.text('Request'));
      await settleStudy(tester);
      expect(requests, 2);
      expect(find.text('Before you use AI Study'), findsNothing);
      await tester.tap(find.text('Review'));
      await settleStudy(tester);
      expect(find.text('Before you use AI Study'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FiloButton, 'Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FiloButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test(
    'study privacy is account-specific and independent of instructor consent',
    () async {
      await FileTextCache(db).acceptPrivacy();
      expect(await StudyPrivacy(db).accepted(), isFalse);
      await StudyPrivacy(db).accept();
      final other = AppDatabase(NativeDatabase.memory());
      try {
        expect(await StudyPrivacy(other).accepted(), isFalse);
        expect(await StudyPrivacy(db).accepted(), isTrue);
      } finally {
        await other.close();
      }
    },
  );
}
