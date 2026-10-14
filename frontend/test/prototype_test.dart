import 'package:filo/app.dart';
import 'package:filo/core/router/app_router.dart';
import 'package:filo/core/supabase/auth_providers.dart';
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
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [authUserIdProvider.overrideWith((ref) => Stream.value(null))],
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

  testWidgets('intro leads to sign-in and student preview', (tester) async {
    await launch(tester);
    expect(find.text('Learning,\ntogether.'), findsOneWidget);
    await tester.tap(find.text('Skip intro'));
    await tester.pumpAndSettle();
    expect(find.text('Hello,\ncurious mind.'), findsOneWidget);
    await tester.tap(find.text('Explore the preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student'));
    await tester.pumpAndSettle();
    expect(find.text('Your classes'), findsOneWidget);
    expect(find.text('Introduction to Computing'), findsOneWidget);
  });

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
