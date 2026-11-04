import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/app.dart';
import 'package:filo/core/widgets/entry_artwork.dart';
import 'package:filo/core/router/app_router.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/features/classes/application/preview_controller.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito.ttf'));
    await loader.load();
  });
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String route = '/',
    PreviewRole role = PreviewRole.student,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Keep fixture settling deterministic while the intro has ambient motion.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        authUserIdProvider.overrideWith((ref) => Stream.value(null)),
        loginSessionProvider.overrideWith((ref) => Stream.value(null)),
        verifiedUserIdProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    container.read(previewProvider.notifier).chooseRole(role);
    container.read(appRouterProvider).go(route);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('intro leads to sign-in without a preview entry', (tester) async {
    await launch(tester);
    expect(find.text('Learning,\ntogether.'), findsOneWidget);
    await tester.tap(find.text('Skip intro'));
    await tester.pumpAndSettle();
    expect(find.text('Hello,\ncurious mind.'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-heading')), findsNothing);
    expect(find.text('Explore the preview'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('all intro pages advance and About Filo restarts the intro', (
    tester,
  ) async {
    await launch(tester);
    for (final title in ['Small steps.\nBig wins.', 'Stay curious.']) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Filo'));
    await tester.pumpAndSettle();
    expect(find.text('Learning,\ntogether.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets(
    'intro progress and primary actions remain reachable on a small phone',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await launch(tester, size: const Size(320, 568), scale: 1.3);
      for (var page = 1; page <= 3; page++) {
        expect(find.bySemanticsLabel('Page $page of 3'), findsOneWidget);
        expect(find.text('$page of 3'), findsNothing);
        final action = find.text(page == 3 ? 'Get started' : 'Next');
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(568));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final signIn = find.text('Continue with Google');
      expect(signIn, findsOneWidget);
      expect(tester.getRect(signIn).bottom, lessThanOrEqualTo(568));
      await tester.ensureVisible(find.text('Hello,\ncurious mind.'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Next slides without a spinner and ignores repeated taps in flight',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await launch(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in ['Skip intro', 'Get started']) {
    testWidgets('$action keeps mascot aligned without route movement', (
      tester,
    ) async {
      await launch(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      await tester.pumpAndSettle();
      if (action == 'Get started') {
        for (var page = 0; page < 2; page++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      final before = tester.getRect(
        find.byType(EntryMascot).hitTestable().first,
      );
      await tester.tap(find.text(action));
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
      final route = ModalRoute.of(
        tester.element(find.text('Continue with Google')),
      ) as PageRoute;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      expect(find.byKey(const ValueKey('sign-in-heading')), findsOneWidget);
      final after = tester.getRect(find.byType(EntryMascot).first);
      expect(after.top, closeTo(before.top, .01));
      expect(after.size, before.size);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getRect(find.byType(EntryMascot).first), after);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('student navigation, file filters, and pending join request', (
    tester,
  ) async {
    final container = await launch(tester, route: '/classes');
    await tester.tap(find.text('Introduction to Computing'));
    await tester.pumpAndSettle();
    expect(find.text('A fresh start.'), findsOneWidget);
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PDFs'));
    await tester.pumpAndSettle();
    expect(find.text('Introduction to computing.pdf'), findsOneWidget);
    expect(find.text('Week 1 learning guide.docx'), findsNothing);
    await tester.tap(find.text('Classwork'));
    await tester.pumpAndSettle();
    expect(find.text('Activity 1: Technology around us'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to classes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'FILO26');
    await tester.tap(find.text('Request to join'));
    await tester.pumpAndSettle();
    expect(container.read(previewProvider).classes.last.pending, isTrue);
    await tester.scrollUntilVisible(
      find.text('Waiting for approval'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Waiting for approval'), findsOneWidget);
  });

  testWidgets('instructor validates and creates a post in the stream', (
    tester,
  ) async {
    final container = await launch(
      tester,
      route: '/classes/it119/post/new',
      role: PreviewRole.instructor,
    );
    await tester.tap(find.text('Post').last);
    await tester.pumpAndSettle();
    expect(find.text('Give your post a title.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Our next meeting',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Bring your questions.',
    );
    await tester.tap(find.text('Post').last);
    await tester.pumpAndSettle();
    expect(
      container.read(previewProvider).posts.first.title,
      'Our next meeting',
    );
    expect(find.text('Our next meeting'), findsOneWidget);
  });

  testWidgets('instructor publishes sample assessment and sees classwork', (
    tester,
  ) async {
    final container = await launch(
      tester,
      route: '/classes/it119/assessment/new',
      role: PreviewRole.instructor,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Computing check-in',
    );
    await tester.ensureVisible(find.text('Generate with AI'));
    await tester.tap(find.text('Generate with AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use sample questions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await tester.pumpAndSettle();
    final assessment = container.read(previewProvider).assessments.single;
    expect(assessment.questions.length, 2);
    expect(assessment.draft, isFalse);
    await tester.tap(find.text('Classwork'));
    await tester.pumpAndSettle();
    expect(find.text('Computing check-in'), findsOneWidget);
  });

  testWidgets('requested screens fit a small phone at 130 percent text scale', (
    tester,
  ) async {
    final container = await launch(
      tester,
      size: const Size(320, 568),
      scale: 1.3,
      role: PreviewRole.instructor,
    );
    for (final route in [
      '/',
      '/sign-in',
      '/classes',
      '/classes/it119',
      '/classes/it119/post/new',
      '/classes/it119/assessment/new',
    ]) {
      container.read(appRouterProvider).go(route);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Layout overflow on $route',
      );
    }
  });
}
