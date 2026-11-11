import 'dart:async';

import '../../support/accessibility.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/assessments/data/question_bank_repository.dart';
import 'package:filo/features/assessments/domain/bank_question.dart';
import 'package:filo/features/assessments/domain/quiz_draft.dart';
import 'package:filo/features/assessments/presentation/question_bank_screen.dart';

class UnusedBankClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Bank widget fixtures must not use the SDK client.');
}

class FakeBank extends QuestionBankRepository {
  FakeBank() : super(UnusedBankClient(), 'owner', () => true);
  bool fail = false, failDelete = false;
  int deletes = 0;
  int writes = 0;
  String? requestedCourse;
  List<BankQuestion> extra = [];
  Future<void>? waiting;
  @override
  Future<List<BankQuestion>> list({String? course}) async {
    requestedCourse = course;
    await waiting;
    if (fail) throw StateError('Connection lost');
    return [
      BankQuestion({
        'id': 'a',
        'course': 'Course',
        'type': 'essay',
        'prompt': 'Alpha',
        'points': 2,
      }),
      BankQuestion({
        'id': 'b',
        'course': 'Course',
        'type': 'true_false',
        'prompt': 'Beta',
        'points': 1,
        'answer': {'boolean': false},
      }),
      ...extra,
    ];
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    if (failDelete) throw StateError('Network lost');
    extra.removeWhere((row) => row.id == id);
  }

  @override
  Future<void> save(
    String id,
    QuizQuestion question, {
    bool creating = false,
    String? course,
  }) async {
    writes++;
    if (fail) throw StateError('Connection lost');
  }
}

void main() {
  testWidgets('selected question invalidated before copy is refused', (
    tester,
  ) async {
    final selected = BankQuestion({
      'id': 'changing',
      'course': 'Course',
      'type': 'true_false',
      'prompt': 'Changing question',
      'points': 1,
      'answer': {'boolean': true},
    });
    final bank = FakeBank()..extra = [selected];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionBankRepositoryProvider.overrideWith((ref) async => bank),
          connectivityProvider.overrideWithValue(const AsyncData(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: QuestionBankScreen(picking: true, course: 'Course'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Changing question'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Changing question'));
    await tester.pumpAndSettle();
    selected.row['answer'] = {};
    await tester.tap(find.widgetWithText(FiloButton, 'Add selected (1)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(BankQuestion.invalidContentMessage),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(BankQuestion.invalidContentMessage), findsOneWidget);
    expect(find.byType(QuestionBankScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'malformed legacy answers fail closed; irrelevant stale fields are ignored',
    () {
      BankQuestion row(String type, {Object? options, Object? answer}) =>
          BankQuestion({
            'id': 'legacy',
            'type': type,
            'prompt': 'Legacy',
            'points': 1,
            'options': options,
            'answer': answer,
          });
      expect(row('essay', options: {}, answer: []).tryCopyToQuiz(), isNotNull);
      expect(
        row(
          'true_false',
          options: {},
          answer: {'boolean': false},
        ).tryCopyToQuiz(),
        isNotNull,
      );
      for (final options in [
        null,
        {},
        [1],
        [
          {'text': 'A', 'is_correct': 'true'},
        ],
        [
          {'text': 'A', 'is_correct': true},
          {'text': 'B', 'is_correct': true},
        ],
      ]) {
        final invalid = row('multiple_choice', options: options);
        expect(invalid.tryCopyToQuiz(), isNull);
        expect(invalid.copyToQuiz, throwsStateError);
      }
      for (final answer in [
        null,
        [],
        {},
        {
          'accepted': [1],
        },
        {'accepted': []},
      ]) {
        expect(row('identification', answer: answer).tryCopyToQuiz(), isNull);
      }
      expect(row('true_false', answer: {}).tryCopyToQuiz(), isNull);
      expect(row('unknown').tryCopyToQuiz(), isNull);
    },
  );

  testWidgets('offline bank offers no legacy deletion or copy actions', (
    tester,
  ) async {
    final bank = FakeBank()
      ..extra = [
        BankQuestion({
          'id': 'bad',
          'course': 'Course',
          'type': 'multiple_choice',
          'prompt': 'Broken legacy',
          'points': 1,
          'options': {},
        }),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionBankRepositoryProvider.overrideWith((ref) async => bank),
          connectivityProvider.overrideWithValue(const AsyncData(false)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuestionBankScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        "You're offline. Connect, then refresh to use the question bank.",
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);
    expect(bank.deletes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final picking in [false, true]) {
    testWidgets('invalid bank row remains visible; picking=$picking', (
      tester,
    ) async {
      final bank = FakeBank()
        ..extra = [
          BankQuestion({
            'id': 'bad',
            'course': 'Course',
            'type': 'multiple_choice',
            'prompt': 'Broken legacy',
            'points': 1,
            'options': {},
          }),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWith((ref) async => bank),
            connectivityProvider.overrideWithValue(const AsyncData(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: QuestionBankScreen(picking: picking, course: 'Course'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Broken legacy'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(BankQuestion.invalidContentMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (picking) {
        expect(
          find.widgetWithText(CheckboxListTile, 'Broken legacy'),
          findsNothing,
        );
      } else {
        final panel = find.ancestor(
          of: find.text('Broken legacy'),
          matching: find.byType(FiloPanel),
        );
        expect(
          find.descendant(of: panel, matching: find.text('Edit')),
          findsNothing,
        );
        bank.failDelete = true;
        await tester.tap(
          find.descendant(of: panel, matching: find.text('Delete')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FiloButton, 'Delete').last);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Deletion not confirmed. Refresh the bank before trying again.',
          ),
          findsOneWidget,
        );
        bank.failDelete = false;
        await tester.tap(find.widgetWithText(TextButton, 'Retry'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Broken legacy'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text('Broken legacy'),
              matching: find.byType(FiloPanel),
            ),
            matching: find.text('Delete'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FiloButton, 'Delete').last);
        await tester.pumpAndSettle();
        expect(bank.deletes, 2);
        expect(find.text('Broken legacy'), findsNothing);
      }
    });
  }

  testWidgets(
    'course picker excludes other courses and unassigned legacy questions',
    (tester) async {
      final bank = FakeBank()
        ..extra = [
          BankQuestion({
            'id': 'math',
            'course': 'Math',
            'type': 'essay',
            'prompt': 'Other course',
            'points': 1,
          }),
          BankQuestion({
            'id': 'old',
            'type': 'essay',
            'prompt': 'Legacy unassigned',
            'points': 1,
          }),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWith((ref) async => bank),
            connectivityProvider.overrideWithValue(const AsyncData(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: QuestionBankScreen(picking: true, course: ' course '),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bank.requestedCourse, ' course ');
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Other course'), findsNothing);
      expect(find.text('Legacy unassigned'), findsNothing);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWith((ref) async => bank),
            connectivityProvider.overrideWithValue(const AsyncData(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: QuestionBankScreen(
                key: ValueKey('empty'),
                picking: true,
                course: 'Science',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No saved questions for this course yet.'),
        findsOneWidget,
      );
      expect(find.text('Other course'), findsNothing);
    },
  );
  testWidgets(
    'bank refresh keeps loaded questions and recovers after failure',
    (tester) async {
      final bank = FakeBank();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWith((ref) async => bank),
            connectivityProvider.overrideWithValue(const AsyncData(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const QuestionBankScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pending = Completer<void>();
      bank.waiting = pending.future;
      await tester.tap(find.byTooltip('Refresh bank'));
      await tester.pump();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Refreshing question bank\u2026'), findsNothing);
      expect(find.byType(FiloLinearProgressIndicator), findsNothing);
      for (final button in tester.widgetList<TextButton>(
        find.widgetWithText(TextButton, 'Edit'),
      )) {
        expect(button.onPressed, isNull);
      }
      pending.completeError(StateError('fixture network'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load the question bank. Connect and retry.'),
        findsOneWidget,
      );
      bank.waiting = null;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final palette in [AppTheme.light, AppTheme.dark]) {
    group('${palette.brightness.name} / 130%', () {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      setUp(() {
        binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
      });
      tearDown(() {
        binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      test('all bank shapes round trip into independent quiz copies', () {
        for (final type in [
          'multiple_choice',
          'true_false',
          'identification',
          'essay',
        ]) {
          final source = QuizQuestion.newQuestion(type)
            ..payload.addAll({
              'prompt': 'Prompt',
              'points': 3,
              'explanation': 'Explanation',
              if (type == 'multiple_choice') ...{
                'options': ['A', 'B'],
                'correct_option_index': 1,
              },
              if (type == 'true_false') 'correct_boolean': false,
              if (type == 'identification') 'accepted_answers': ['One', 'Two'],
            });
          final bank = BankQuestion({
            'id': 'bank',
            ...BankQuestion.content(source),
          });
          final first = bank.copyToQuiz(), second = bank.copyToQuiz();
          expect(first.validationErrors(), isEmpty);
          expect(BankQuestion.content(first), BankQuestion.content(source));
          expect(first.id, isNull);
          expect(first.options, isEmpty);
          expect(first.localId, isNot(second.localId));
          first.payload['prompt'] = 'Edited copy';
          if (type == 'identification') {
            (first.payload['accepted_answers'] as List).clear();
          }
          expect(second.prompt, 'Prompt');
          expect(bank.copyToQuiz().prompt, 'Prompt');
          if (type == 'identification') {
            expect(bank.copyToQuiz().answerKey!.acceptedAnswers, [
              'One',
              'Two',
            ]);
          }
        }
      });
      a11yScreenTest(
        'picker retains hidden selections and returns unsaved copies in bank order',
        (tester) async {
          final bank = FakeBank();
          List<QuizQuestion>? result;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                questionBankRepositoryProvider.overrideWith(
                  (ref) async => bank,
                ),
                connectivityProvider.overrideWith((ref) => Stream.value(true)),
              ],
              child: MaterialApp(
                theme: palette,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        result = await showFiloBottomSheet<List<QuizQuestion>>(
                          context: context,
                          title: 'Add from question bank',
                          scrollBody: false,
                          builder: (_) => const QuestionBankScreen(
                            picking: true,
                            course: 'Course',
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Alpha'));
          await tester.enterText(find.byType(TextField), 'Beta');
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(CheckboxListTile, 'Beta'));
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Essay').last);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '');
          await tester.pumpAndSettle();
          expect(find.text('Beta'), findsNothing);
          await tester.tap(find.text('Add selected (2)'));
          await tester.pumpAndSettle();
          expect(result!.map((q) => q.prompt), ['Alpha', 'Beta']);
          expect(result!.every((q) => q.id == null), isTrue);
          expect(bank.writes, 0);
        },
      );
      a11yScreenTest(
        'load failure is retryable and never presented as an empty bank',
        (tester) async {
          final bank = FakeBank()..fail = true;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                questionBankRepositoryProvider.overrideWith(
                  (ref) async => bank,
                ),
                connectivityProvider.overrideWith((ref) => Stream.value(true)),
              ],
              child: MaterialApp(
                theme: palette,
                home: const QuestionBankScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Retry'), findsOneWidget);
          expect(find.textContaining('No saved questions yet.'), findsNothing);
          bank.fail = false;
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(find.text('Alpha'), findsOneWidget);
          expect(find.text('Beta'), findsOneWidget);
        },
      );
      a11yScreenTest(
        'bank edit retains input after failure and retries explicitly',
        (tester) async {
          final bank = FakeBank();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                questionBankRepositoryProvider.overrideWith(
                  (ref) async => bank,
                ),
                connectivityProvider.overrideWith((ref) => Stream.value(true)),
              ],
              child: MaterialApp(
                theme: palette,
                home: const QuestionBankScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit').first);
          await tester.pumpAndSettle();
          final prompt = find.byWidgetPredicate(
            (w) => w is TextFormField && w.initialValue == 'Alpha',
          );
          await tester.enterText(prompt, 'Retained edit');
          bank.fail = true;
          await tester.scrollUntilVisible(
            find.text('Save changes'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save changes'));
          await tester.pumpAndSettle();
          expect(bank.writes, 1);
          final editorScroll = find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.textContaining('Your edits are retained.'),
            -200,
            scrollable: editorScroll,
          );
          expect(
            find.textContaining('Your edits are retained.'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('Retained edit'),
            150,
            scrollable: editorScroll,
          );
          expect(find.text('Retained edit'), findsOneWidget);
          bank.fail = false;
          await tester.scrollUntilVisible(
            find.text('Save changes'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save changes'));
          await tester.pumpAndSettle();
          expect(bank.writes, 2);
          expect(find.text('Question bank'), findsOneWidget);
        },
      );
    });
  }
}
