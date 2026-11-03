import 'dart:async';

import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/study/presentation/study_flashcard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate')
          calls.add(call.arguments as String);
        return null;
      },
    );
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  Widget app(
    Widget child, {
    bool reduced = false,
    TextDirection direction = TextDirection.ltr,
  }) => MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: direction,
        child: FiloMotionScope(child: Scaffold(body: child)),
      ),
    ),
  );

  testWidgets(
    'button translates 3dp with a static shadow and resets on disable',
    (tester) async {
      Widget button(bool enabled) =>
          app(FiloButton(label: 'Action', onPressed: enabled ? () {} : null));
      await tester.pumpWidget(button(true));
      final origin = tester.getTopLeft(find.byType(FilledButton));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester.getTopLeft(find.byType(FilledButton)).dy,
        closeTo(origin.dy + 3, .01),
      );
      final shadows = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FiloButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .expand((d) => d.boxShadow ?? <BoxShadow>[]);
      expect(
        shadows.any((s) => s.blurRadius == 6 && s.offset == const Offset(0, 3)),
        isTrue,
      );
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.getTopLeft(find.byType(FilledButton)).dy,
        closeTo(origin.dy, .01),
      );
      final held = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump();
      await tester.pumpWidget(button(false));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byType(FilledButton)).dy,
        closeTo(origin.dy, .01),
      );
      await held.cancel();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mid-animation reduced motion and hidden tickers settle without replay',
    (tester) async {
      double value = 0;
      Widget sample(double target, bool reduced, bool ticker) => app(
        TickerMode(
          enabled: ticker,
          child: FiloMotionTween(
            value: target,
            duration: const Duration(seconds: 1),
            builder: (_, current, __) {
              value = current;
              return const SizedBox();
            },
          ),
        ),
        reduced: reduced,
      );
      await tester.pumpWidget(sample(0, false, true));
      await tester.pumpWidget(sample(1, false, true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(value, inExclusiveRange(0, 1));
      await tester.pumpWidget(sample(1, true, true));
      expect(value, 1);
      await tester.pumpWidget(sample(1, false, true));
      expect(value, 1);
      await tester.pumpWidget(sample(0, false, true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(sample(0, false, false));
      expect(value, 0);
      await tester.pumpWidget(sample(0, false, true));
      expect(value, 0);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'card drag cancellation resets scale and disabled cards do not press',
    (tester) async {
      var taps = 0;
      Widget sample(bool enabled) => app(
        Center(
          child: FiloCard(
            onTap: enabled ? () => taps++ : null,
            child: const Text('Card'),
          ),
        ),
      );
      await tester.pumpWidget(sample(true));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Card')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final transform = find
          .descendant(
            of: find.byType(FiloCardTap),
            matching: find.byType(Transform),
          )
          .first;
      expect(
        tester.widget<Transform>(transform).transform.storage[0],
        closeTo(.98, .001),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Transform>(transform).transform.storage[0], 1);
      await gesture.cancel();
      await tester.pumpWidget(sample(false));
      await tester.tap(find.text('Card'));
      expect(taps, 0);
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'page distance respects direction and neutral routes are instant',
    (tester) async {
      const child = SizedBox(key: ValueKey('page'), width: 40, height: 40);
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => FiloPageTransitions.transition(
                context,
                const AlwaysStoppedAnimation(0),
                child,
              ),
            ),
            direction: direction,
          ),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('page'))).dx,
          direction == TextDirection.ltr ? 24 : -24,
        );
      }
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FiloPageTransitions.transition(
              context,
              const AlwaysStoppedAnimation(.2),
              child,
            ),
          ),
          reduced: true,
        ),
      );
      expect(tester.getTopLeft(find.byKey(const ValueKey('page'))).dx, 0);
      final route = FiloInstantRoute<void>(builder: (_) => child);
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    },
  );

  testWidgets('native nav semantics remain and chip check uses a stable slot', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              FiloNavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => selected = value),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(
                    icon: Icon(Icons.folder),
                    selectedIcon: Icon(Icons.folder_open),
                    label: 'Files',
                  ),
                ],
              ),
              FiloFilterChip(
                label: 'Chosen',
                selected: selected == 1,
                onSelected: (_) => setState(() => selected = 1),
              ),
            ],
          ),
        ),
      ),
    );
    final before = tester.getSize(find.byType(FilterChip));
    await tester.tap(find.text('Files'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    expect(tester.getSize(find.byType(FilterChip)), before);
    expect(calls, isEmpty);
  });

  testWidgets(
    'first six stagger once; refresh, empty and remount consume opportunity',
    (tester) async {
      final bucket = PageStorageBucket();
      Widget sample(bool ready, int generation) => app(
        PageStorage(
          bucket: bucket,
          child: FiloFirstListLoad(
            key: ValueKey(generation),
            id: 'list',
            ready: ready,
            child: Column(
              children: [
                for (var i = 0; i < 8; i++)
                  FiloListItem(
                    index: i,
                    child: SizedBox(
                      key: ValueKey('row$i'),
                      height: 20,
                      width: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(sample(false, 0));
      await tester.pumpWidget(sample(true, 0));
      expect(tester.getTopLeft(find.byKey(const ValueKey('row0'))).dy, 12);
      expect(tester.getTopLeft(find.byKey(const ValueKey('row6'))).dy, 120);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('row0'))).dy,
        closeTo(0, .01),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('row5'))).dy,
        closeTo(112, .01),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(sample(false, 0));
      await tester.pumpWidget(sample(true, 1));
      expect(tester.getTopLeft(find.byKey(const ValueKey('row0'))).dy, 0);
      Widget emptySample(int count) => app(
        PageStorage(
          bucket: bucket,
          child: FiloFirstListLoad(
            id: 'empty',
            ready: true,
            hasItems: count > 0,
            child: Column(
              children: [
                for (var i = 0; i < count; i++)
                  FiloListItem(
                    index: i,
                    child: SizedBox(
                      key: ValueKey('empty-row$i'),
                      height: 20,
                      width: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(emptySample(0));
      await tester.pumpWidget(emptySample(2));
      expect(tester.getTopLeft(find.byKey(const ValueKey('empty-row0'))).dy, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'success sparkles finish once, reduced motion and lifecycle skip them',
    (tester) async {
      await tester.pumpWidget(app(const FiloSuccessMoment()));
      expect(find.byIcon(FiloIcons.sparkle), findsNWidgets(3));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(FiloIcons.sparkle), findsNothing);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byIcon(FiloIcons.sparkle), findsNothing);
      await tester.pumpWidget(
        app(const FiloSuccessMoment(key: ValueKey('new')), reduced: true),
      );
      expect(find.byIcon(FiloIcons.sparkle), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switch tick is user-only; confirmed feedback waits and platform failure is harmless',
    (tester) async {
      var value = false;
      var completed = false;
      final result = Completer<bool>();
      late StateSetter rebuild;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Column(
                children: [
                  FiloSwitch(
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  ),
                  FiloButton(
                    label: completed ? 'Confirmed' : 'Confirm',
                    onPressed: () async {
                      if (await result.future && context.mounted) {
                        FiloHaptics.confirmed(context);
                        setState(() => completed = true);
                      }
                    },
                  ),
                ],
              );
            },
          ),
          reduced: true,
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(calls, ['HapticFeedbackType.selectionClick']);
      rebuild(() => value = false);
      await tester.pump();
      expect(calls, hasLength(1));
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(calls, hasLength(1));
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => throw PlatformException(code: 'feedback_unavailable'),
      );
      result.complete(true);
      await tester.pump();
      await tester.pump();
      expect(find.text('Confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
