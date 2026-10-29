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
  bool fail = false;
  int writes = 0;
  @override
  Future<List<BankQuestion>> list() async {
    if (fail) throw StateError('Connection lost');
    return [
      BankQuestion({
        'id': 'a',
        'type': 'essay',
        'prompt': 'Alpha',
        'points': 2,
      }),
      BankQuestion({
        'id': 'b',
        'type': 'true_false',
        'prompt': 'Beta',
        'points': 1,
        'answer': {'boolean': false},
      }),
    ];
  }

  @override
  Future<void> save(
    String id,
    QuizQuestion question, {
    bool creating = false,
  }) async {
    writes++;
    if (fail) throw StateError('Connection lost');
  }
}

void main() {
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
        expect(bank.copyToQuiz().answerKey!.acceptedAnswers, ['One', 'Two']);
      }
    }
  });
  testWidgets(
    'picker retains hidden selections and returns unsaved copies in bank order',
    (tester) async {
      final bank = FakeBank();
      List<QuizQuestion>? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWith((ref) async => bank),
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showFiloBottomSheet<List<QuizQuestion>>(
                      context: context,
                      title: 'Add from question bank',
                      scrollBody: false,
                      builder: (_) => const QuestionBankScreen(picking: true),
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
  testWidgets(
    'load failure is retryable and never presented as an empty bank',
    (tester) async {
      final bank = FakeBank()..fail = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWith((ref) async => bank),
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
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
  testWidgets('bank edit retains input after failure and retries explicitly', (
    tester,
  ) async {
    final bank = FakeBank();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questionBankRepositoryProvider.overrideWith((ref) async => bank),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
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
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your edits are retained.'), findsOneWidget);
    expect(find.text('Retained edit'), findsOneWidget);
    expect(bank.writes, 1);
    bank.fail = false;
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(bank.writes, 2);
    expect(find.text('Question bank'), findsOneWidget);
  });
}
