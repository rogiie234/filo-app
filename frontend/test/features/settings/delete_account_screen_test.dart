import 'dart:async';

import 'package:filo/core/account_deletion_journal.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/settings/application/account_deletion.dart';
import 'package:filo/features/settings/data/account_deletion_repository.dart';
import 'package:filo/features/settings/presentation/delete_account_screen.dart';
import 'package:filo/features/settings/presentation/deletion_recovery_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_deletion_test.dart'
    show MemoryJournal, FakeDeletion, FakeRemoval;

void main() {
  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is FiloButton && w.label == label);
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(target);
    await tester.pump();
  }

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    bool online = true,
    bool dark = false,
    bool instructor = false,
    Future<InstructorDeletionEligibility> Function()? eligibility,
    DeletionStage? stage,
    bool recovery = false,
    FakeDeletion? remote,
  }) async {
    final store = MemoryJournal();
    if (stage != null) {
      store.saved['a'] = DeletionRecord(
        'a',
        's',
        stage,
        instructor: instructor,
      );
    }
    final repo = remote ?? (await tester.runAsync(() async => FakeDeletion()))!;
    final container = ProviderContainer(
      overrides: [
        deletionJournalStoreProvider.overrideWithValue(store),
        deletionSessionProvider.overrideWithValue((
          userId: 'a',
          sessionId: 's',
        )),
        loginSessionProvider.overrideWith((ref) => Stream.value(null)),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        accountDeletionRepositoryProvider.overrideWithValue(repo),
        if (eligibility != null)
          instructorDeletionEligibilityProvider('a')
              .overrideWith((ref) => eligibility()),
        accountDeletionCleanupProvider.overrideWithValue(FakeRemoval()),
        deletionSessionCleanupProvider.overrideWithValue((_) async {}),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(repo.client.dispose);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: recovery
              ? const DeletionRecoveryGate(child: Text('private child'))
              : DeleteAccountScreen(userId: 'a', instructor: instructor),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  for (final dark in [false, true]) {
    testWidgets('exact input and warning at 130 percent dark=$dark', (
      tester,
    ) async {
      await mount(tester, dark: dark);
      expect(find.text(studentDeletionWarning), findsOneWidget);
      for (final value in ['', 'delete', ' DELETE', 'DELETE ', 'wrong']) {
        await reveal(tester, find.byType(TextField));
        await tester.enterText(find.byType(TextField), value);
        await tester.pump();
        await reveal(tester, button('Delete my account'));
        expect(
          tester.widget<FiloButton>(button('Delete my account')).onPressed,
          isNull,
        );
      }
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await reveal(tester, button('Delete my account'));
      expect(
        tester.widget<FiloButton>(button('Delete my account')).onPressed,
        isNotNull,
      );
      await reveal(tester, button('Cancel'));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('offline exact word stays disabled with requested explanation', (
    tester,
  ) async {
    await mount(tester, online: false);
    await reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await reveal(tester, button('Delete my account'));
    expect(
      find.text('Connect to the internet to delete your account.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FiloButton>(button('Delete my account')).onPressed,
      isNull,
    );
  });
  testWidgets(
    'busy blocks navigation and duplicate taps; lost response clears confirmation',
    (tester) async {
      final repo = (await tester.runAsync(() async => FakeDeletion()))!;
      final response = Completer<DeletionStage>();
      repo.outcome = () => response.future;
      final container = await mount(tester, remote: repo);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await reveal(tester, button('Delete my account'));
      await tester.tap(button('Delete my account'));
      await tester.pump();
      await tester.pump();
      expect(repo.calls, 1);
      expect(
        tester.widget<FiloButton>(find.byType(FiloButton).first).onPressed,
        isNull,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      response.completeError(TimeoutException('fixture'));
      await tester.pump();
      await tester.pump();
      expect(
        container.read(deletionJournalProvider).requireValue['a']!.stage,
        DeletionStage.uncertain,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.widget<FiloButton>(button('Retry')).onPressed, isNull);
    },
  );
  testWidgets(
    'signed-out cleanup journal routes to local-only recovery before private child',
    (tester) async {
      final container = await mount(
        tester,
        online: false,
        stage: DeletionStage.cleanup,
        recovery: true,
      );
      expect(find.text('private child'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(
        tester.widget<FiloButton>(button('Remove local files')).onPressed,
        isNotNull,
      );
      await reveal(tester, button('Remove local files'));
      await tester.tap(button('Remove local files'));
      await tester.pump();
      await tester.pump();
      expect(container.read(deletionJournalProvider).requireValue, isEmpty);
      expect(find.text('private child'), findsOneWidget);
    },
  );
  testWidgets('pending recovery never resubmits automatically', (tester) async {
    final repo = (await tester.runAsync(() async => FakeDeletion()))!;
    await mount(tester, stage: DeletionStage.pending, remote: repo);
    expect(repo.calls, 0);
    expect(find.byType(TextField), findsNothing);
    await reveal(tester, button('Resume deletion'));
    expect(button('Resume deletion'), findsOneWidget);
    expect(button('Cancel'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'instructor eligible recovery warning at 130 percent dark=$dark',
      (tester) async {
        await mount(
          tester,
          instructor: true,
          dark: dark,
          eligibility: () async =>
              const InstructorDeletionEligibility(0, hasRecoveryClasses: true),
        );
        expect(find.text(instructorDeletionWarning), findsOneWidget);
        expect(find.text(studentDeletionWarning), findsNothing);
        await reveal(tester, find.text(recoveryClassesWarning));
        await reveal(tester, find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'DELETE');
        await tester.pump();
        await reveal(tester, button('Delete my account'));
        expect(
          tester.widget<FiloButton>(button('Delete my account')).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final count in [1, 4]) {
    testWidgets('instructor $count class block disables deletion', (
      tester,
    ) async {
      await mount(
        tester,
        instructor: true,
        eligibility: () async => InstructorDeletionEligibility(count),
      );
      expect(find.text('Delete your classes first'), findsOneWidget);
      await reveal(tester, button('Delete my account'));
      expect(
        tester.widget<FiloButton>(button('Delete my account')).onPressed,
        isNull,
      );
    });
  }
  testWidgets('instructor failed eligibility retries without inventing zero', (
    tester,
  ) async {
    var fail = true;
    await mount(
      tester,
      instructor: true,
      eligibility: () async {
        if (fail) throw StateError('fixture');
        return const InstructorDeletionEligibility(0);
      },
    );
    expect(
      find.text("Couldn't check your classes. Try again."),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text(instructorDeletionWarning), findsOneWidget);
    expect(find.text(recoveryClassesWarning), findsNothing);
  });
  testWidgets(
    'instructor pending restart bypasses forbidden eligibility reads',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        instructor: true,
        stage: DeletionStage.pending,
        recovery: false,
        eligibility: () async {
          calls++;
          throw StateError('must not read');
        },
      );
      expect(calls, 0);
      expect(find.text(instructorDeletionWarning), findsOneWidget);
      expect(find.text(studentDeletionWarning), findsNothing);
    },
  );
}
