import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'shared destructive dialog scrolls at 320dp and dismisses safely in ${theme.brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => FiloMotionScope(
              enabled: false,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showFiloConfirmation(
                      context,
                      title: 'Delete this practice quiz?',
                      message: 'This quiz, its questions and all its attempts will be deleted from this device. Your original files are not affected.',
                      confirmLabel: 'Delete quiz',
                      cancelLabel: 'Cancel',
                      confirmDestructive: true,
                      icon: FiloIcons.delete,
                      animate: false,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(FiloModalDialog), findsOneWidget);
        final icon = tester.widget<FiloIcon>(find.descendant(
          of: find.byType(FiloModalDialog), matching: find.byType(FiloIcon)));
        expect(icon.color, theme.colorScheme.onErrorContainer);
        final confirm = find.byWidgetPredicate(
          (widget) => widget is FiloButton && widget.label == 'Delete quiz',
        );
        expect(tester.widget<FiloButton>(confirm).destructive, isTrue);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(result, isFalse);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'shared form keeps typed confirmation disabled until exact match',
    (tester) async {
      final input = TextEditingController();
      addTearDown(input.dispose);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showFiloDialog<bool>(
                    context: context,
                    animate: false,
                    builder: (dialog) =>
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: input,
                          builder: (_, value, _) => FiloModalDialog(
                            title: 'Delete class?',
                            destructive: true,
                            icon: FiloIcons.delete,
                            content: TextField(
                              controller: input,
                              decoration: const InputDecoration(
                                labelText: 'Section name',
                              ),
                            ),
                            actions: [
                              FiloButton(
                                label: 'Delete class',
                                destructive: true,
                                onPressed: value.text == 'BSIT-3A'
                                    ? () => Navigator.pop(dialog, true)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final confirm = find.byWidgetPredicate(
        (widget) => widget is FiloButton && widget.label == 'Delete class',
      );
      expect(tester.widget<FiloButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'bsit-3a');
      await tester.pump();
      expect(tester.widget<FiloButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'BSIT-3A');
      await tester.pump();
      expect(tester.widget<FiloButton>(confirm).onPressed, isNotNull);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );
}
