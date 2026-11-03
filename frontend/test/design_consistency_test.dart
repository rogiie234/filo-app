import 'dart:io';

import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/presentation/class_banner.dart';
import 'package:filo/features/classes/presentation/classes_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('neutral dialog opt-out reaches its builder and controls', (
    tester,
  ) async {
    bool? reduced;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFiloDialog<void>(
                context: context,
                animate: false,
                builder: (dialog) {
                  reduced = MediaQuery.disableAnimationsOf(dialog);
                  return AlertDialog(
                    title: const Text('Neutral confirmation'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(reduced, isTrue);
    expect(find.text('Neutral confirmation'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  test('production presentation colors and fonts come from the foundation', () {
    // IconData families identify bundled glyphs, not text styling. Development
    // surfaces and generated Firebase configuration are outside screen acceptance.
    const exceptions = {
      'core/widgets/filo_icons.dart',
      'core/widgets/component_gallery.dart',
      'component_gallery_main.dart',
      'firebase_options.dart',
    };
    final raw = RegExp(
      r'\bColors\.|\bColor\s*\(\s*(?:0x|\d)|'
      r'\bColor\.from(?:ARGB|RGBO)\s*\(|'
      r'\bfont(?:Size|Family)\s*:|\bFontWeight\.|\bFiloColors\.',
    );
    final findings = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final relative = file.path.replaceAll('\\', '/').substring(4);
      if (!relative.endsWith('.dart') ||
          relative.endsWith('.g.dart') ||
          relative.startsWith('core/theme/') ||
          relative.endsWith('_dev_screen.dart') ||
          exceptions.contains(relative)) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (raw.hasMatch(lines[index].split('//').first)) {
          findings.add('$relative:${index + 1}: ${lines[index].trim()}');
        }
      }
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('${theme.brightness.name} shared design at 320dp / 130%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
                disableAnimations: true,
              ),
              child: FiloTextScale(child: child!),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(FiloSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Brand(),
                    const SizedBox(height: FiloSpacing.screen),
                    const ClassBanner(
                      section: 'A long section name that must wrap',
                      instructor: 'An instructor with a long readable name',
                      avatar: SizedBox.square(
                        dimension: 40,
                        child: ColoredBox(color: Colors.white),
                      ),
                    ),
                    const FiloAvatar(name: 'Student name', size: 40),
                    const SizedBox(height: FiloSpacing.s16),
                    FiloButton(label: 'Save changes', onPressed: () {}),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Continue'),
                    ),
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    const FiloPanel(child: Text('Readable panel content')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(FiloButton)).height,
        greaterThanOrEqualTo(FiloControlSize.primary),
      );
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Continue')).height,
        greaterThanOrEqualTo(FiloControlSize.primary),
      );
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Cancel')).height,
        greaterThanOrEqualTo(FiloControlSize.compact),
      );
      expect(
        find.descendant(
          of: find.byType(FiloAvatar),
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ClassBanner),
          matching: find.byType(ClipOval),
        ),
        findsOneWidget,
      );
      final panel = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FiloPanel),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        (panel.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(FiloRadii.large),
      );
    });
  }
}
