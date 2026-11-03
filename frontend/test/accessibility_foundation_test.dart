import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + .05) / (values.first + .05);
}

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    final name = theme.brightness.name;
    test('$name semantic text and essential control pairs meet contrast', () {
      final colors = theme.colorScheme;
      final tokens = theme.extension<FiloThemeTokens>()!;
      for (final pair in [
        (colors.onSurface, colors.surface),
        (colors.onSurfaceVariant, colors.surface),
        (colors.onPrimary, colors.primary),
        (colors.onPrimaryContainer, colors.primaryContainer),
        (tokens.hint, colors.surface),
        (colors.error, colors.errorContainer),
        (tokens.warning, tokens.warningTint),
        (tokens.success, tokens.successTint),
        (tokens.info, tokens.infoTint),
        (tokens.onLime, tokens.lime),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      for (final background in [colors.surface, tokens.mint]) {
        expect(
          contrast(tokens.controlBorder, background),
          greaterThanOrEqualTo(3),
        );
      }
      expect(
        theme.inputDecorationTheme.enabledBorder!.borderSide.color,
        tokens.controlBorder,
      );
      expect(tokens.copyWith().controlBorder, tokens.controlBorder);
      expect(tokens.lerp(tokens, .5).controlBorder, tokens.controlBorder);
    });

    testWidgets('$name native action targets and labels at 320dp / 130%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: FiloTextScale(child: child!),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FiloButton(
                    label: 'Save a long descriptive action',
                    onPressed: () {},
                  ),
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: () {},
                    icon: const Icon(Icons.close),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Retry')),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Class section',
                      errorText:
                          'Enter the section provided by your instructor.',
                    ),
                  ),
                  FiloSwitchListTile(
                    value: true,
                    onChanged: (_) {},
                    title: const Text(
                      'Available offline with a long descriptive label',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(IconButton)).shortestSide,
        greaterThanOrEqualTo(48),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets(
    'failed form reveals first invalid field, keeps inline errors and reading order',
    (tester) async {
      final key = GlobalKey<FormState>();
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FiloTextScale(
              child: Form(
                key: key,
                child: ListView(
                  children: [
                    TextFormField(
                      focusNode: first,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter your name.' : null,
                    ),
                    TextFormField(
                      focusNode: second,
                      decoration: const InputDecoration(labelText: 'School'),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter your school.' : null,
                    ),
                    TextButton(
                      onPressed: () => validateFiloForm(key),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(first.hasFocus, isTrue);
      expect(second.hasFocus, isFalse);
      expect(find.text('Enter your name.'), findsOneWidget);
      expect(find.text('Enter your school.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Alex');
      expect(validateFiloForm(key), isFalse);
      await tester.pumpAndSettle();
      expect(second.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(second.hasFocus, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bounded empty state scrolls to recovery at 130%', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.3),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 272,
                height: 180,
                child: EmptyState(
                  title: 'No saved files are available on this device.',
                  message: 'Connect to refresh your saved content and then try again.',
                  action: FiloButton(
                    label: 'Retry',
                    onPressed: () => retried = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('dialog closing restores focus to its triggering action', (
    tester,
  ) async {
    final trigger = FocusNode();
    addTearDown(trigger.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: trigger,
              onPressed: () => showFiloDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  scrollable: true,
                  title: const Text('Edit name'),
                  content: const TextField(
                    autofocus: true,
                    decoration: InputDecoration(labelText: 'Name'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    trigger.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(trigger.hasFocus, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(trigger.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
