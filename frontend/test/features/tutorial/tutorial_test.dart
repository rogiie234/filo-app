import 'package:drift/native.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/tutorial/tutorial_host.dart';
import 'package:filo/features/tutorial/tutorial_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTutorialRepository extends TutorialRepository {
  FakeTutorialRepository(super.database);
  bool seen = false, failSave = false;
  bool? completed;
  @override
  Future<bool> dismissed(String id) async => seen;
  @override
  Future<void> dismiss(String id, {required bool completed}) async {
    if (failSave) throw StateError('disk unavailable');
    seen = true;
    this.completed = completed;
  }
}

void main() {
  test('account-local dismissals persist, distinguish skip and completion, and isolate tours', () async {
    final a = AppDatabase(NativeDatabase.memory());
    final b = AppDatabase(NativeDatabase.memory());
    addTearDown(a.close);
    addTearDown(b.close);
    final repository = TutorialRepository(a);
    expect(await repository.dismissed('main_v1'), isFalse);
    await repository.dismiss('main_v1', completed: false);
    expect(await TutorialRepository(a).dismissed('main_v1'), isTrue);
    expect(await repository.dismissed('class_v1'), isFalse);
    expect(await TutorialRepository(b).dismissed('main_v1'), isFalse);
    await repository.dismiss('main_v1', completed: true);
    final row = await a
        .customSelect(
          "SELECT value FROM app_settings WHERE key='tutorial_main_v1'",
        )
        .getSingle();
    expect(row.read<String>('value'), 'completed');
  });

  late AppDatabase database;
  late FakeTutorialRepository repository;
  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = FakeTutorialRepository(database);
  });
  tearDown(() => database.close());

  Future<void> mount(
    WidgetTester tester, {
    bool reduced = false,
    bool ready = true,
    int replay = 0,
    bool missing = false,
    double scale = 1,
    VoidCallback? onAction,
    ValueChanged<int>? onDestination,
  }) async {
    final target = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tutorialRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(800, 600),
              disableAnimations: reduced,
              textScaler: TextScaler.linear(scale),
            ),
            child: TutorialHost(
              id: 'main_v1',
              ready: ready,
              replay: replay,
              targets: missing ? {} : {'action': target},
              steps: const [
                TutorialStep(
                  'Welcome tour',
                  'Explore safely.',
                  'waving',
                  destination: 0,
                ),
                TutorialStep(
                  'Highlighted action',
                  'This button creates a class.',
                  'curious',
                  target: 'action',
                  destination: 1,
                ),
                TutorialStep(
                  'Tour finished',
                  'Replay from Settings.',
                  'cheerful_note',
                ),
              ],
              onDestination: onDestination ?? (_) {},
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: ElevatedButton(
                    key: target,
                    onPressed: onAction ?? () {},
                    child: const Text('Create real class'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Next changes pose and destination, highlights exact control, blocks actions, Back and completion work',
    (tester) async {
      final destinations = <int>[];
      var creates = 0;
      await mount(
        tester,
        onAction: () => creates++,
        onDestination: destinations.add,
      );
      expect(tester.widget<Mascot>(find.byType(Mascot)).pose, 'waving');
      await tap(tester, 'Show me');
      expect(destinations, [0, 1]);
      expect(tester.widget<Mascot>(find.byType(Mascot)).pose, 'curious');
      final paint = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .singleWhere(
            (widget) => widget.painter.runtimeType.toString() == '_Spotlight',
          );
      final Rect highlight = (paint.painter as dynamic).target as Rect;
      final action = tester.getRect(find.text('Create real class'));
      expect(highlight.contains(action.center), isTrue);
      await tester.tapAt(action.center);
      await tester.pump();
      expect(creates, 0);
      await tap(tester, 'Back');
      expect(find.text('Welcome tour'), findsOneWidget);
      await tap(tester, 'Show me');
      await tap(tester, 'Next');
      expect(tester.widget<Mascot>(find.byType(Mascot)).pose, 'cheerful_note');
      await tap(tester, 'Got it');
      expect(repository.completed, isTrue);
      expect(find.byType(Mascot), findsNothing);
      await tester.tap(find.text('Create real class'));
      expect(creates, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Skip persists, suppressed on reopen, explicit replay opens again',
    (tester) async {
      await mount(tester);
      await tap(tester, 'Skip tutorial');
      expect(repository.completed, isFalse);
      await tester.pumpWidget(const SizedBox());
      await mount(tester);
      expect(find.text('Welcome tour'), findsNothing);
      await mount(tester, replay: 1);
      expect(find.text('Welcome tour'), findsOneWidget);
    },
  );

  testWidgets(
    'waits for readiness and handles a missing target without activating anything',
    (tester) async {
      await mount(tester, ready: false, missing: true);
      expect(find.text('Welcome tour'), findsNothing);
      await mount(tester, missing: true);
      await tap(tester, 'Show me');
      expect(find.text('Retry highlight'), findsOneWidget);
      await tap(tester, 'Retry highlight');
      await tap(tester, 'Skip step');
      expect(find.text('Tour finished'), findsOneWidget);
    },
  );

  testWidgets('storage failure offers recovery and retry', (tester) async {
    repository.failSave = true;
    await mount(tester);
    await tap(tester, 'Skip tutorial');
    expect(find.text('Close without saving'), findsOneWidget);
    repository.failSave = false;
    await tap(tester, 'Skip tutorial');
    expect(find.text('Welcome tour'), findsNothing);
  });

  testWidgets('system Back dismisses the tutorial without leaving the screen', (
    tester,
  ) async {
    await mount(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(repository.completed, isFalse);
    expect(find.text('Welcome tour'), findsNothing);
    expect(find.text('Create real class'), findsOneWidget);
  });

  testWidgets('platform Reduce Motion suppresses transitions independently', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await mount(tester);
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(const ValueKey('tutorial_content')),
    );
    expect(switcher.duration, Duration.zero);
    await tap(tester, 'Skip tutorial');
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  testWidgets(
    'large text and reduced motion retain reachable controls and exclude background semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, reduced: true, scale: 2);
      final switcher = tester.widget<AnimatedSwitcher>(
        find.byKey(const ValueKey('tutorial_content')),
      );
      expect(switcher.duration, Duration.zero);
      expect(
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!
            .toStringDeep(),
        isNot(contains('Create real class')),
      );
      await tap(tester, 'Show me');
      await tap(tester, 'Next');
      await tap(tester, 'Got it');
      expect(repository.completed, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
