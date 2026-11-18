import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/core/ai/ai_request_providers.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/data/files_repository.dart';
import 'package:filo/features/files/data/file_storage.dart';
import 'package:filo/features/study/application/student_ai_providers.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/presentation/study_chat_message.dart';
import 'package:filo/features/study/presentation/study_chat_screen.dart';
import 'package:filo/features/study/presentation/study_privacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpChat(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late AppDatabase db;
  late String notebook;
  late AiRequestGuard guard;
  late StudentAiClient client;
  late StreamController<bool> connectivity;
  late StudyAiInvoke invoke;
  var elapsed = Duration.zero;
  var online = true;
  var calls = 0;
  String? copied;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notebook = await NotebookRepository(db).create('Notebook');
    await StudyPrivacy(db).accept();
    online = true;
    elapsed = Duration.zero;
    calls = 0;
    copied = null;
    connectivity = StreamController<bool>.broadcast(sync: true);
    guard = AiRequestGuard(elapsed: () => elapsed);
    invoke = (_, body, _) async => {
      'answer': '**Answer**\n- A point',
      'mode': (body['sources'] as List).isEmpty ? 'general' : 'files',
      'truncated': false,
    };
    client = StudentAiClient(
      invoke: (function, body, abort) {
        calls++;
        return invoke(function, body, abort);
      },
      loadSources: (_) async => (await db.select(db.notebookSources).get())
          .map(
            (s) => StudyAiSource(
              key: s.sourceKey,
              name: s.name,
              text: s.extractedText,
            ),
          )
          .toList(),
      isOnline: () => online,
      currentAccount: () => 'student',
      guard: guard,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings') return {'value': false};
          return null;
        });
  });
  tearDown(() async {
    await guard.close();
    await connectivity.close();
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget app() => ProviderScope(
    overrides: [
      accountDatabaseProvider.overrideWith((ref) async => db),
      filesRepositoryProvider.overrideWith(
        (ref) async => FilesRepository(db, FileStorage(Directory.systemTemp)),
      ),
      studentAiClientProvider.overrideWithValue(client),
      aiRequestGuardProvider.overrideWithValue(guard),
      connectivityProvider.overrideWith(
        (ref) => Stream<bool>.multi((sink) {
          sink.add(online);
          final sub = connectivity.stream.listen(sink.add);
          sink.onCancel = sub.cancel;
        }),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(1.3)),
        child: child!,
      ),
      home: StudyChatScreen(notebookId: notebook),
    ),
  );

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await pumpChat(tester);
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('thinking dots animate and respect reduced motion', (
    tester,
  ) async {
    Widget view(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(body: StudyThinkingLabel()),
      ),
    );
    await tester.pumpWidget(view(false));
    String visibleDots() {
      final text = tester.widget<Text>(find.byType(Text).last);
      final spans = (text.textSpan! as TextSpan).children!;
      return (spans[1] as TextSpan).text!;
    }

    expect(visibleDots(), '.');
    await tester.pump(const Duration(milliseconds: 450));
    expect(visibleDots(), '..');
    await tester.pumpWidget(view(true));
    expect(visibleDots(), '...');
    await tester.pump(const Duration(seconds: 2));
    expect(visibleDots(), '...');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'send and copy, cooldown, persisted history and confirmed deletion at 130% text',
    (tester) async {
      await tester.pumpWidget(app());
      await pumpChat(tester);
      expect(find.widgetWithText(AppBar, 'Filo'), findsOneWidget);
      expect(find.text('Hi, I’m Filo.'), findsOneWidget);
      expect(find.text('General knowledge'), findsOneWidget);
      await enter(tester, 'Explain cells');
      tester.testTextInput.hide();
      await pumpChat(tester);
      expect(calls, 1);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Send message',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Copy answer'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Copy answer'));
      await tester.pump();
      expect(copied, '**Answer**\n- A point');
      elapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));
      await tester.enterText(find.byType(TextField), 'Another question');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Send message',
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Chat options'));
      await pumpChat(tester);
      await tester.tap(find.text('History'));
      await pumpChat(tester);
      expect(find.text('Chats are kept for 30 days.'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Explain cells'), findsOneWidget);
      expect(find.textContaining('30 days left'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Explain cells'));
      await pumpChat(tester);
      await tester.tap(find.byTooltip('Chat options'));
      await pumpChat(tester);
      await tester.tap(find.text('Delete chat'));
      await pumpChat(tester);
      await tester.ensureVisible(
        find.widgetWithText(FiloButton, 'Delete chat'),
      );
      await tester.tap(find.widgetWithText(FiloButton, 'Delete chat'));
      await pumpChat(tester);
      expect(find.text('Hi, I’m Filo.'), findsOneWidget);
      expect(await db.select(db.chatMessages).get(), isEmpty);
      expect(tester.takeException(), isNull);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'offline history is readable and sending is disabled with offline status',
    (tester) async {
      final repo = StudyChatRepository(db);
      final id = await repo.create(notebook, 'Saved chat');
      await repo.addMessage(
        chatId: id,
        role: 'assistant',
        content: 'Offline answer',
        mode: 'general',
      );
      online = false;
      await tester.pumpWidget(app());
      await pumpChat(tester);
      expect(find.text('Offline answer'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Draft');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Send message',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(studyAiMessages['OFFLINE']!), findsNothing);
      expect(
        find.text("You're offline. Showing saved content."),
        findsOneWidget,
      );
      expect(calls, 0);
      await disposeApp(tester);
    },
  );

  testWidgets('privacy cancel prevents the first send and keeps the question', (
    tester,
  ) async {
    await db.customStatement('DELETE FROM ai_settings WHERE key=?', [
      StudyPrivacy.key,
    ]);
    await tester.pumpWidget(app());
    await pumpChat(tester);
    await enter(tester, 'Private question');
    tester.testTextInput.hide();
    await pumpChat(tester);
    expect(find.text('Before you use AI Study'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FiloButton, 'Cancel'));
    await tester.tap(find.widgetWithText(FiloButton, 'Cancel'));
    await pumpChat(tester);
    expect(calls, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Private question',
    );
    expect(await db.select(db.chats).get(), isEmpty);
    await tester.tap(find.byTooltip('Send message'));
    await pumpChat(tester);
    await tester.ensureVisible(find.widgetWithText(FiloButton, 'OK'));
    await tester.tap(find.widgetWithText(FiloButton, 'OK'));
    await pumpChat(tester);
    expect(calls, 1);
    expect(await StudyPrivacy(db).accepted(), isTrue);
    await disposeApp(tester);
  });

  testWidgets(
    'sending clears composer and thinking has no cancel or save flash',
    (tester) async {
      final reply = Completer<dynamic>();
      invoke = (_, _, _) => reply.future;
      await tester.pumpWidget(app());
      await pumpChat(tester);
      await enter(tester, 'Question');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(StudyThinkingLabel), findsOneWidget);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.enabled, isTrue);
      expect(composer.readOnly, isTrue);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Not confirmed saved'), findsNothing);
      reply.complete({
        'answer': 'Saved answer',
        'mode': 'general',
        'truncated': false,
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(find.text('Not confirmed saved'), findsNothing);
        expect(find.text('Try saving again'), findsNothing);
        expect(find.text('Thinking...'), findsNothing);
      }
      expect(find.text('Saved answer'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byType(StudyThinkingLabel), findsNothing);
      expect(calls, 1);
      expect((await db.select(db.chatMessages).get()).length, 2);
      await disposeApp(tester);
    },
  );

  testWidgets('Filo bubbles wrap at narrow width with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  StudyChatBubble(
                    key: const ValueKey('question'),
                    content: 'Explain this idea in a few simple steps.',
                    role: 'user',
                    mode: 'general',
                  ),
                  StudyChatBubble(
                    key: const ValueKey('answer'),
                    content: '**A useful idea**\n- Read the example carefully.\n- Check the source.',
                    role: 'assistant',
                    mode: 'files',
                    unsaved: true,
                    time: DateTime(2026, 11, 16, 10, 30),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await pumpChat(tester);
    expect(find.text('Filo'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Answers use your files'), findsOneWidget);
    expect(find.text('Not confirmed saved'), findsOneWidget);
    expect(find.byTooltip('Copy answer'), findsOneWidget);
    expect(find.text('Delivered'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('answer'))).width,
      lessThanOrEqualTo(272),
    );
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('file mode uses saved notebook text', (tester) async {
    await NotebookSourceRepository(db).add(
      notebookId: notebook,
      fileId: 'file',
      name: 'lesson.txt',
      text: const LessonText(text: 'Lesson text', sourceKey: 'att:lesson'),
      extractedAt: db.now(),
    );
    await tester.pumpWidget(app());
    await pumpChat(tester);
    expect(find.text('Answers use your files'), findsOneWidget);
    await enter(tester, 'Explain');
    expect(
      (await db.select(db.chatMessages).get()).every((m) => m.mode == 'files'),
      isTrue,
    );
    await disposeApp(tester);
  });

  testWidgets('attachment opens the existing local source picker', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await pumpChat(tester);
    await tester.tap(find.byTooltip('Add source files'));
    await pumpChat(tester);
    expect(find.text('Add up to 3 files'), findsOneWidget);
    expect(find.text('Downloaded from classes'), findsOneWidget);
    expect(find.text('My files'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.byTooltip('Close'));
    await pumpChat(tester);
    await disposeApp(tester);
  });

  testWidgets(
    'formatting is limited and links, images and HTML remain inert text',
    (tester) async {
      const text =
          '**Bold**\n- Item\n1. Numbered\n[link](https://example.invalid)\n![image](https://example.invalid/a.png)\n<script>text</script>';
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: StudyAnswerText(text))),
      );
      final widget = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(
        widget.textSpan!.toPlainText(),
        contains('Bold\n• Item\n1. Numbered'),
      );
      expect(
        widget.textSpan!.toPlainText(),
        contains('[link](https://example.invalid)'),
      );
      expect(widget.textSpan!.toPlainText(), contains('<script>text</script>'));
      expect(find.byType(Image), findsNothing);
      expect(
        widget.textSpan!.children!.whereType<TextSpan>().any(
          (s) => s.style?.fontWeight == FontWeight.w800,
        ),
        isTrue,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    'shared cooldown stream reaches zero without reopening the screen',
    (tester) async {
      final events = <Duration>[];
      final subscription = guard.watchChatCooldown().listen(events.add);
      await tester.pump();
      guard.markChatDispatched();
      await tester.pump();
      expect(events.last, const Duration(seconds: 3));
      elapsed = const Duration(seconds: 1);
      await tester.pump(const Duration(seconds: 1));
      expect(events.last, const Duration(seconds: 2));
      elapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 2));
      expect(events.last, Duration.zero);
      await tester.runAsync(() => subscription.cancel());
    },
  );
}
