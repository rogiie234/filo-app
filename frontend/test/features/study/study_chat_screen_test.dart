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

  testWidgets(
    'send and copy, cooldown, persisted history and confirmed deletion at 130% text',
    (tester) async {
      await tester.pumpWidget(app());
      await pumpChat(tester);
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
      expect(find.text('Ask a question to start a chat.'), findsOneWidget);
      expect(await db.select(db.chatMessages).get(), isEmpty);
      expect(tester.takeException(), isNull);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'offline history is readable and sending is disabled with its reason',
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
      expect(find.text(studyAiMessages['OFFLINE']!), findsOneWidget);
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
    'thinking cancel preserves the question, late output is ignored, and retry is explicit',
    (tester) async {
      final reply = Completer<dynamic>();
      invoke = (_, _, _) => reply.future;
      await tester.pumpWidget(app());
      await pumpChat(tester);
      await enter(tester, 'Question');
      tester.testTextInput.hide();
      await pumpChat(tester);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Mascot && widget.pose == 'thinking',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Cancel'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Cancel'));
      await pumpChat(tester);
      reply.complete({
        'answer': 'Late answer',
        'mode': 'general',
        'truncated': false,
      });
      await pumpChat(tester);
      expect(find.text('Late answer'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Question',
      );
      expect(calls, 1);
      elapsed = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 3));
      invoke = (_, _, _) async => {
        'answer': 'Retried answer',
        'mode': 'general',
        'truncated': false,
      };
      await tester.tap(find.byTooltip('Send message'));
      await pumpChat(tester);
      expect(calls, 2);
      expect((await db.select(db.chatMessages).get()).length, 2);
      await disposeApp(tester);
    },
  );

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
