import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/core/ai/ai_request_providers.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/assessments/domain/ai_sources.dart';
import 'package:filo/features/study/application/student_ai_providers.dart';
import 'package:filo/features/study/application/study_providers.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_summary_usage.dart';
import 'package:filo/features/study/presentation/study_chat_message.dart';
import 'package:filo/features/study/presentation/study_privacy.dart';
import 'package:filo/features/study/presentation/study_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpSummary(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class FailingSummaryRepository extends StudySummaryRepository {
  FailingSummaryRepository(super.db);
  bool fail = false;
  @override
  Future<void> save(
    String notebookId,
    String content, {
    StudySummaryUsage? usage,
    bool Function()? canCommit,
  }) {
    if (fail) throw StateError('Synthetic disk error');
    return super.save(notebookId, content, usage: usage, canCommit: canCommit);
  }
}

void main() {
  late AppDatabase db;
  late String notebook;
  late AiRequestGuard guard;
  late StudentAiClient client;
  late StudyAiInvoke invoke;
  late FailingSummaryRepository repository;
  var online = true, calls = 0;
  String? copied;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = FailingSummaryRepository(db);
    notebook = await NotebookRepository(db).create('Summary notebook');
    await NotebookSourceRepository(db).add(
      notebookId: notebook,
      fileId: 'original',
      name: 'Lesson.txt',
      text: const LessonText(
        text: 'A readable source',
        sourceKey: 'att:source',
      ),
      extractedAt: DateTime.now(),
    );
    await StudyPrivacy(db).accept();
    online = true;
    calls = 0;
    copied = null;
    guard = AiRequestGuard();
    invoke = (_, _, _) async => {
      'answer': '**Summary**\n- Main idea',
      'mode': 'files',
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
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Widget app() => ProviderScope(
    overrides: [
      accountDatabaseProvider.overrideWith((ref) async => db),
      studentAiClientProvider.overrideWithValue(client),
      aiRequestGuardProvider.overrideWithValue(guard),
      studySummaryRepositoryProvider.overrideWith((ref) async => repository),
      connectivityProvider.overrideWith((ref) => Stream.value(online)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (_, child) => MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          textScaler: TextScaler.linear(1.3),
        ),
        child: child!,
      ),
      home: StudySummaryScreen(notebookId: notebook),
    ),
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pump();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder.hitTestable());
    await pumpSummary(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder button(String label) => find.widgetWithText(FiloButton, label);

  testWidgets(
    'generate, copy and reopen same saved summary offline at 130% text',
    (tester) async {
      await tester.pumpWidget(app());
      await pumpSummary(tester);
      await tap(tester, button('Summarize sources'));
      expect(calls, 1);
      expect(find.byType(StudyAnswerText), findsOneWidget);
      expect(find.text('17 source characters used.'), findsOneWidget);
      expect(find.textContaining('Saved '), findsOneWidget);
      await tap(tester, find.text('Copy summary'));
      expect(copied, '**Summary**\n- Main idea');
      final persisted = (await db.select(db.summaries).get()).single;
      await close(tester);
      online = false;
      await tester.pumpWidget(app());
      await pumpSummary(tester);
      expect(
        tester.widget<StudyAnswerText>(find.byType(StudyAnswerText)).text,
        persisted.content,
      );
      expect(find.text('17 source characters used.'), findsOneWidget);
      expect(find.text(studyAiMessages['OFFLINE']!), findsOneWidget);
      expect(
        tester.widget<FiloButton>(button('Summarize again')).onPressed,
        isNull,
      );
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'replacement needs confirmation and Cancel leaves old summary intact',
    (tester) async {
      await StudySummaryRepository(db).save(notebook, 'Old summary');
      await tester.pumpWidget(app());
      await pumpSummary(tester);
      expect(find.text('Usage details unavailable'), findsOneWidget);
      await tap(tester, button('Summarize again'));
      await tap(tester, button('Cancel'));
      expect(calls, 0);
      expect(
        tester.widget<StudyAnswerText>(find.byType(StudyAnswerText)).text,
        'Old summary',
      );
      await tap(tester, button('Summarize again'));
      final confirm = find.descendant(
        of: find.byType(FiloConfirmationDialog),
        matching: button('Summarize again'),
      );
      await tap(tester, confirm);
      expect(calls, 1);
      expect(
        (await db.select(db.summaries).get()).single.content,
        '**Summary**\n- Main idea',
      );
      await close(tester);
    },
  );

  testWidgets('privacy Cancel sends nothing; OK permits the first generation', (
    tester,
  ) async {
    await db.customStatement('DELETE FROM ai_settings WHERE key=?', [
      StudyPrivacy.key,
    ]);
    await tester.pumpWidget(app());
    await pumpSummary(tester);
    await tap(tester, button('Summarize sources'));
    expect(find.text('Before you use AI Study'), findsOneWidget);
    await tap(tester, button('Cancel'));
    expect(calls, 0);
    await tap(tester, button('Summarize sources'));
    await tap(tester, button('OK'));
    expect(calls, 1);
    expect(await StudyPrivacy(db).accepted(), isTrue);
    await close(tester);
  });

  testWidgets('waiting Cancel keeps existing summary and ignores late output', (
    tester,
  ) async {
    await StudySummaryRepository(db).save(notebook, 'Old summary');
    final response = Completer<dynamic>();
    invoke = (_, _, _) => response.future;
    await tester.pumpWidget(app());
    await pumpSummary(tester);
    await tap(tester, button('Summarize again'));
    await tap(
      tester,
      find.descendant(
        of: find.byType(FiloConfirmationDialog),
        matching: button('Summarize again'),
      ),
    );
    expect(find.text('Preparing your summary...'), findsOneWidget);
    expect(find.byType(Mascot), findsOneWidget);
    expect(
      tester.widget<StudyAnswerText>(find.byType(StudyAnswerText)).text,
      'Old summary',
    );
    await tap(tester, button('Cancel'));
    expect(find.text('Preparing your summary...'), findsNothing);
    expect(find.text(studyAiMessages['CANCELLED']!), findsOneWidget);
    expect(guard.isBusy, isFalse);
    response.complete({
      'answer': 'Late answer',
      'mode': 'files',
      'truncated': false,
    });
    await pumpSummary(tester);
    expect((await db.select(db.summaries).get()).single.content, 'Old summary');
    expect(find.text(studyAiMessages['CANCELLED']!), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'no sources disables generation but still displays retained summary and usage',
    (tester) async {
      await StudySummaryRepository(db).save(
        notebook,
        'Saved source summary',
        usage: StudySummaryUsage([
          const StudySourceUsage(
            key: 'att:source',
            name: 'Lesson.txt',
            originalCharacters: 50000,
            retainedCharacters: 40000,
          ),
        ]),
      );
      await db.delete(db.notebookSources).go();
      await tester.pumpWidget(app());
      await pumpSummary(tester);
      expect(
        tester.widget<FiloButton>(button('Summarize again')).onPressed,
        isNull,
      );
      expect(
        find.text('Add a readable source to generate a summary.'),
        findsOneWidget,
      );
      expect(find.text('40000 source characters used.'), findsOneWidget);
      expect(
        find.text('Only the first 40000 characters of Lesson.txt were used.'),
        findsOneWidget,
      );
      expect(calls, 0);
      await close(tester);
    },
  );

  testWidgets(
    'saved summary uses inert basic formatting rather than link/image widgets',
    (tester) async {
      const content =
          '**Bold**\n- Item\n[link](https://example.invalid)\n![image](https://example.invalid/a.png)';
      await StudySummaryRepository(db).save(notebook, content);
      await tester.pumpWidget(app());
      await pumpSummary(tester);
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(
        text.textSpan!.toPlainText(),
        contains('[link](https://example.invalid)'),
      );
      expect(
        text.textSpan!.children!.whereType<TextSpan>().any(
          (s) => s.style?.fontWeight == FontWeight.w800,
        ),
        isTrue,
      );
      expect(find.byType(Image), findsNothing);
      await close(tester);
    },
  );

  testWidgets(
    'save failure labels the new result unsaved and retry does not regenerate',
    (tester) async {
      await repository.save(notebook, 'Old summary');
      repository.fail = true;
      await tester.pumpWidget(app());
      await pumpSummary(tester);
      await tap(tester, button('Summarize again'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(FiloConfirmationDialog),
          matching: button('Summarize again'),
        ),
      );
      expect(find.byType(StudyAnswerText), findsNWidgets(2));
      expect(find.text('New summary — not confirmed saved'), findsOneWidget);
      expect(
        (await db.select(db.summaries).get()).single.content,
        'Old summary',
      );
      repository.fail = false;
      await tap(tester, button('Try saving again'));
      expect(calls, 1);
      expect(find.text('New summary — not confirmed saved'), findsNothing);
      expect(
        (await db.select(db.summaries).get()).single.content,
        '**Summary**\n- Main idea',
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}
