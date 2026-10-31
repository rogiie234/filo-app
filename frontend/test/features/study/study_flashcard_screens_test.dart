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
import 'package:filo/features/study/domain/study_ai.dart';
import 'package:filo/features/study/domain/study_inputs.dart';
import 'package:filo/features/study/presentation/study_decks_screen.dart';
import 'package:filo/features/study/presentation/study_flashcard.dart';
import 'package:filo/features/study/presentation/study_flashcard_study_screen.dart';
import 'package:filo/features/study/presentation/study_privacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> pumpDeck(WidgetTester tester) async {
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
    invoke = (_, body, __) async => {
      'cards': [
        for (var i = 1; i <= 3; i++)
          {'front': 'Question $i', 'back': 'Answer $i'},
      ],
      'dropped': 1,
      'missing': (body['count'] as int) - 3,
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
    if (finder.evaluate().isEmpty)
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pump();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder.hitTestable());
    await pumpDeck(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<String> deck({int count = 3}) => StudyDeckRepository(db).create(
    notebookId: notebook,
    title: 'Saved deck',
    settings: const StudyDeckSettings(count: 5),
    cards: [
      for (var i = 1; i <= count; i++)
        StudyCardInput(front: 'Question $i', back: 'Answer $i'),
    ],
  );

  testWidgets(
    'generation defaults, required topic, partial counts and saved list',
    (tester) async {
      await tester.pumpWidget(app(StudyDecksScreen(notebookId: notebook)));
      await pumpDeck(tester);
      expect(
        find.text('Generate flashcards to review the main ideas.'),
        findsOneWidget,
      );
      await tap(tester, button('Generate flashcards'));
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byType(DropdownButtonFormField<int>),
            )
            .initialValue,
        10,
      );
      expect(tester.widget<FiloButton>(button('Generate')).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Cells');
      await tester.pump();
      await tap(tester, button('Generate'));
      expect(calls, 1);
      expect(find.text('Deck saved.'), findsOneWidget);
      expect(find.text('1 invalid card was dropped.'), findsOneWidget);
      expect(find.text('7 requested cards were not returned.'), findsOneWidget);
      expect((await db.select(db.flashcardDecks).get()).single.title, 'Cells');
      await close(tester);
      await tester.pumpWidget(app(StudyDecksScreen(notebookId: notebook)));
      await pumpDeck(tester);
      expect(find.text('Cells'), findsOneWidget);
      expect(find.text('3 cards · 0 known'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'privacy Cancel prevents dispatch and waiting Cancel discards late cards',
    (tester) async {
      await db.customStatement('DELETE FROM ai_settings WHERE key=?', [
        StudyPrivacy.key,
      ]);
      final response = Completer<dynamic>();
      invoke = (_, __, ___) => response.future;
      await tester.pumpWidget(
        app(StudyDeckGenerateScreen(notebookId: notebook)),
      );
      await pumpDeck(tester);
      await tester.enterText(find.byType(TextField), 'Cells');
      await tester.pump();
      await tap(tester, button('Generate'));
      expect(find.text('Before you use AI Study'), findsOneWidget);
      await tap(tester, button('Cancel'));
      expect(calls, 0);
      await tap(tester, button('Generate'));
      await tap(tester, button('OK'));
      expect(find.text('Preparing your flashcards...'), findsOneWidget);
      await tap(tester, button('Cancel'));
      expect(guard.isBusy, isFalse);
      expect(find.text(studyAiMessages['CANCELLED']!), findsOneWidget);
      response.complete({
        'cards': [
          {'front': 'Late', 'back': 'Late'},
        ],
        'dropped': 0,
        'missing': 9,
      });
      await pumpDeck(tester);
      expect(await db.select(db.flashcardDecks).get(), isEmpty);
      await close(tester);
    },
  );

  testWidgets(
    'button marks, shuffle, missed replay and offline persisted statuses at 130%',
    (tester) async {
      final id = await deck();
      online = false;
      await tester.pumpWidget(
        app(StudyFlashcardStudyScreen(notebookId: notebook, deckId: id)),
      );
      await pumpDeck(tester);
      await tap(tester, find.byType(StudyFlashcard));
      expect(find.text('Answer 1'), findsOneWidget);
      await tap(tester, button('Still learning'));
      expect(find.text('Card 2 of 3'), findsOneWidget);
      await tap(tester, find.byTooltip('Shuffle remaining cards'));
      await tap(tester, button('Got it'));
      await tap(tester, button('Got it'));
      expect(find.text('Deck complete'), findsOneWidget);
      expect(find.text('2 known'), findsOneWidget);
      expect(find.text('1 still learning'), findsOneWidget);
      await tap(tester, button('Study missed cards again'));
      expect(find.text('Card 1 of 1'), findsOneWidget);
      await tap(tester, button('Got it'));
      expect(find.text('1 known'), findsOneWidget);
      expect(find.text('0 still learning'), findsOneWidget);
      await close(tester);
      await tester.pumpWidget(app(StudyDecksScreen(notebookId: notebook)));
      await pumpDeck(tester);
      expect(find.text('3 cards · 3 known'), findsOneWidget);
      await tap(tester, find.text('Saved deck'));
      expect(find.text('Question 1'), findsOneWidget);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets('horizontal swipes mark both directions', (tester) async {
    final id = await deck();
    await tester.pumpWidget(
      app(StudyFlashcardStudyScreen(notebookId: notebook, deckId: id)),
    );
    await pumpDeck(tester);
    await tester.drag(find.byType(StudyFlashcard), const Offset(220, 0));
    await pumpDeck(tester);
    await tester.drag(find.byType(StudyFlashcard), const Offset(-220, 0));
    await pumpDeck(tester);
    final cards = await db.select(db.flashcards).get();
    expect(cards.where((c) => c.status == 'known'), hasLength(1));
    expect(cards.where((c) => c.status == 'learning'), hasLength(1));
    expect(find.text('Card 3 of 3'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'rename and confirmed deck deletion; last-card deletion leaves empty deck',
    (tester) async {
      final id = await deck(count: 1);
      await tester.pumpWidget(app(StudyDecksScreen(notebookId: notebook)));
      await pumpDeck(tester);
      await tap(tester, find.byTooltip('Deck options for Saved deck'));
      await tap(tester, find.text('Rename deck'));
      await tester.enterText(find.byType(TextField), 'Renamed');
      await tester.pump();
      await tap(tester, find.text('Save'));
      expect(find.text('Renamed'), findsOneWidget);
      await tap(tester, find.text('Renamed'));
      await tap(tester, find.byTooltip('Delete card'));
      await tap(tester, button('Delete card'));
      expect(find.text('This deck has no cards.'), findsOneWidget);
      expect(await db.select(db.flashcards).get(), isEmpty);
      await tester.pageBack();
      await pumpDeck(tester);
      await tap(tester, find.byTooltip('Deck options for Renamed'));
      await tap(tester, find.text('Delete deck'));
      await tap(tester, button('Cancel'));
      expect((await db.select(db.flashcardDecks).get()).single.id, id);
      await tap(tester, find.byTooltip('Deck options for Renamed'));
      await tap(tester, find.text('Delete deck'));
      await tap(tester, button('Delete deck'));
      expect(await db.select(db.flashcardDecks).get(), isEmpty);
      await close(tester);
    },
  );

  testWidgets(
    'reduced motion flips immediately and exposes accessible card label',
    (tester) async {
      reduced = true;
      final id = await deck();
      await tester.pumpWidget(
        app(StudyFlashcardStudyScreen(notebookId: notebook, deckId: id)),
      );
      await pumpDeck(tester);
      final semantics = tester.ensureSemantics();
      await tester.tap(find.byType(StudyFlashcard));
      await tester.pump();
      expect(find.text('Answer 1'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Card 1 of 3. Answer. Answer 1'),
        findsOneWidget,
      );
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(StudyFlashcard),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(container.duration, Duration.zero);
      expect(container.transform, Matrix4.identity());
      semantics.dispose();
      await close(tester);
    },
  );

  testWidgets(
    'ten-deck boundary disables generation and still permits offline study',
    (tester) async {
      for (var i = 0; i < 10; i++) {
        await deck(count: 1);
      }
      online = false;
      await tester.pumpWidget(app(StudyDecksScreen(notebookId: notebook)));
      await pumpDeck(tester);
      expect(
        tester.widget<FiloButton>(button('Generate flashcards')).onPressed,
        isNull,
      );
      expect(
        find.text(
          'You can have up to 10 decks in a notebook. Delete a deck to add another.',
        ),
        findsOneWidget,
      );
      expect(calls, 0);
      await close(tester);
    },
  );
}
