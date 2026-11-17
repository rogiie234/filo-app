import 'package:filo/features/study/domain/study_ai.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/ai/ai_request_guard.dart';
import 'package:filo/core/ai/ai_request_providers.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/study/application/student_ai_providers.dart';
import 'package:filo/features/study/data/student_ai_client.dart';
import 'package:filo/features/study/data/study_repositories.dart';
import 'package:filo/features/study/presentation/study_quizzes_screen.dart';
import 'package:filo/features/study/presentation/study_quiz_play_screen.dart';

import 'study_quiz_sessions_test.dart' show quizInputs, quizSettings;

import 'package:filo/features/study/presentation/study_privacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> pumpQuiz(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late AppDatabase db;
  late String notebook;
  late AiRequestGuard guard;
  late StudentAiClient client;
  late StudyAiInvoke invoke;
  var online = true, reduced = false, calls = 0;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notebook = await NotebookRepository(db).create('Notebook');
    await StudyPrivacy(db).accept();
    guard = AiRequestGuard();
    online = true;
    reduced = false;
    calls = 0;
    invoke = (_, body, _) async => {
      'questions': [
        {
          'type': 'true_false',
          'prompt': 'Generated statement',
          'correct_boolean': true,
          'explanation': 'Generated explanation',
        },
      ],
      'dropped': 1,
      'missing': (body['count'] as int) - 1,
    };
    client = StudentAiClient(
      invoke: (function, body, abort) {
        calls++;
        return invoke(function, body, abort);
      },
      loadSources: (_) async => [],
      isOnline: () => online,
      currentAccount: () => 'student',
      guard: guard,
    );
  });
  tearDown(() async {
    await guard.close();
    await db.close();
  });
  Widget app(Widget home) => ProviderScope(
    overrides: [
      accountDatabaseProvider.overrideWith((ref) async => db),
      studentAiClientProvider.overrideWithValue(client),
      aiRequestGuardProvider.overrideWithValue(guard),
      connectivityProvider.overrideWith((ref) => Stream.value(online)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(1.3),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: home,
    ),
  );
  Finder button(String text) => find.widgetWithText(FiloButton, text);
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pump();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pump();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder.hitTestable());
    await pumpQuiz(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<String> quiz() => StudyQuizRepository(db).create(
    notebookId: notebook,
    title: 'Saved quiz',
    settings: quizSettings,
    questions: quizInputs,
  );
  testWidgets('AI busy uses a transient toast and retries without inline error', (
    tester,
  ) async {
    invoke = (_, _, _) async => throw const StudyAiFailure('AI_BUSY');
    await tester.pumpWidget(app(StudyQuizGenerateScreen(notebookId: notebook)));
    await pumpQuiz(tester);
    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.pump();
    await tap(tester, button('Generate'));
    const message =
        'The AI assistant is busy right now. Please try again in a few minutes.';
    expect(find.text(message), findsOneWidget);
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text(message)),
      findsOneWidget,
    );
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 5));
    await pumpQuiz(tester);
    expect(find.text(message), findsNothing);
    await tester.enterText(find.byType(TextField), 'Cells again');
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    await tap(tester, button('Generate'));
    expect(find.text(message), findsOneWidget);
    expect(calls, 2);
    await close(tester);
  });

  testWidgets('library uses empty CTA then circular add for saved items', (
    tester,
  ) async {
    Finder circle() => find.byWidgetPredicate(
      (widget) =>
          widget is FiloButton &&
          widget.label == 'Generate practice quiz' &&
          widget.iconOnly,
    );
    await tester.pumpWidget(app(StudyQuizzesScreen(notebookId: notebook)));
    await pumpQuiz(tester);
    expect(circle(), findsNothing);
    expect(button('Generate practice quiz'), findsOneWidget);
    await tester.runAsync(() => quiz());
    await pumpQuiz(tester);
    expect(circle(), findsOneWidget);
    await tap(tester, circle());
    expect(find.text('How many questions?'), findsOneWidget);
    await close(tester);
  });

  testWidgets('setup defaults, topic, partial results and save', (
    tester,
  ) async {
    await tester.pumpWidget(app(StudyQuizGenerateScreen(notebookId: notebook)));
    await pumpQuiz(tester);
    final counts = find.byType(FiloFilterChip);
    expect(counts, findsNWidgets(4));
    expect(
      tester
          .widget<FiloFilterChip>(
            find.widgetWithText(FiloFilterChip, '10 questions'),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(FiloFilterChip, '20 questions'));
    await tester.pump();
    expect(
      tester
          .widget<FiloFilterChip>(
            find.widgetWithText(FiloFilterChip, '20 questions'),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<FiloFilterChip>(
            find.widgetWithText(FiloFilterChip, '10 questions'),
          )
          .selected,
      isFalse,
    );
    await tester.tap(find.widgetWithText(FiloFilterChip, '10 questions'));
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(tester.widget<FiloButton>(button('Generate')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.pump();
    await tap(tester, button('Generate'));
    expect(calls, 1);
    expect(find.textContaining('Practice quiz created.'), findsOneWidget);
    expect(find.text('Practice quiz'), findsOneWidget);
    expect(button('Take quiz'), findsNothing);
    expect(
      find.textContaining('1 invalid question was dropped.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('9 requested questions were not returned.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets(
    'offline all question types, feedback, score, retake, history and reduced motion',
    (tester) async {
      online = false;
      reduced = true;
      final id = await quiz();
      await tester.pumpWidget(
        app(StudyQuizPlayScreen(notebookId: notebook, quizId: id)),
      );
      await pumpQuiz(tester);
      for (var pass = 0; pass < 2; pass++) {
        await tap(tester, find.widgetWithText(OutlinedButton, 'B'));
        await tap(tester, button('Check'));
        expect(find.text('Correct'), findsOneWidget);
        await tap(tester, button('Continue'));
        await tap(tester, find.widgetWithText(OutlinedButton, 'False'));
        await tap(tester, button('Check'));
        expect(find.text('Not quite'), findsOneWidget);
        await tap(tester, button('Continue'));
        await tester.enterText(find.byType(TextField), ' RED   blood cell ');
        await tester.pump();
        await tap(tester, button('Check'));
        await tap(tester, button('Continue'));
        expect(find.text('2 of 3 correct'), findsOneWidget);
        if (pass == 0) await tap(tester, button('Retake'));
      }
      expect(await db.select(db.practiceAttempts).get(), hasLength(2));
      await tap(tester, button('History'));
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('2 of 3 correct'),
        ),
        findsNWidgets(2),
      );
      expect(calls, 0);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
  testWidgets(
    'privacy Cancel blocks dispatch and request Cancel ignores late result',
    (tester) async {
      await db.customStatement('DELETE FROM ai_settings WHERE 1=1');
      final response = Completer<dynamic>();
      invoke = (_, _, _) => response.future;
      await tester.pumpWidget(
        app(StudyQuizGenerateScreen(notebookId: notebook)),
      );
      await pumpQuiz(tester);
      await tester.enterText(find.byType(TextField), 'Cells');
      await tester.pump();
      await tap(tester, button('Generate'));
      await tap(tester, button('Cancel'));
      expect(calls, 0);
      await tap(tester, button('Generate'));
      await tap(tester, button('OK'));
      expect(find.text('Preparing your practice quiz...'), findsOneWidget);
      expect(find.byType(FiloLinearProgressIndicator), findsOneWidget);
      expect(
        find.text(
          'Cancel stops waiting on this phone. The server may still finish.',
        ),
        findsOneWidget,
      );
      expect(calls, 1);
      await tap(tester, button('Cancel'));
      expect(guard.isBusy, isFalse);
      response.complete({
        'questions': [
          {
            'type': 'true_false',
            'prompt': 'Late',
            'correct_boolean': true,
            'explanation': 'Late',
          },
        ],
        'dropped': 0,
        'missing': 9,
      });
      await pumpQuiz(tester);
      expect(await db.select(db.practiceQuizzes).get(), isEmpty);
      await close(tester);
    },
  );
  testWidgets('deletion confirmation removes quiz and questions', (
    tester,
  ) async {
    await quiz();
    await tester.pumpWidget(app(StudyQuizzesScreen(notebookId: notebook)));
    await pumpQuiz(tester);
    await tester.tap(find.byTooltip('Options for Saved quiz'));
    await pumpQuiz(tester);
    await tester.tap(find.text('Delete quiz'));
    await pumpQuiz(tester);
    await tap(tester, button('Cancel'));
    expect(await db.select(db.practiceQuizzes).get(), hasLength(1));
    await tester.tap(find.byTooltip('Options for Saved quiz'));
    await pumpQuiz(tester);
    await tester.tap(find.text('Delete quiz'));
    await pumpQuiz(tester);
    await tap(tester, button('Delete quiz'));
    expect(await db.select(db.practiceQuestions).get(), isEmpty);
    await close(tester);
  });
  testWidgets(
    'leaving an unfinished attempt asks and discards without a score',
    (tester) async {
      final id = await quiz();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open quiz'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        StudyQuizPlayScreen(notebookId: notebook, quizId: id),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open quiz'));
      await pumpQuiz(tester);
      await tester.pageBack();
      await pumpQuiz(tester);
      expect(find.text('Leave this practice quiz?'), findsOneWidget);
      await tap(tester, button('Keep open'));
      expect(find.text('Choose B'), findsOneWidget);
      await tester.pageBack();
      await pumpQuiz(tester);
      await tap(tester, button('Leave'));
      expect(find.text('Open quiz'), findsOneWidget);
      expect(await db.select(db.practiceAttempts).get(), isEmpty);
      await close(tester);
    },
  );
}
