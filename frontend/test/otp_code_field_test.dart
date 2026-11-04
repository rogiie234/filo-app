import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/auth/presentation/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'six boxes share one formatted editor in ${theme.brightness.name}',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        String? submitted;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 272,
                  child: OtpCodeField(
                    controller: controller,
                    focusNode: focus,
                    enabled: true,
                    onSubmitted: (value) => submitted = value,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(TextField), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(OtpCodeField),
            matching: find.byType(Container),
          ),
          findsNWidgets(6),
        );
        await tester.enterText(find.byType(TextField), '12a34567');
        await tester.pump();
        expect(controller.text, '123456');
        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          expect(find.text(digit), findsOneWidget);
        }
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.autofillHints, isNull);
        expect(field.enableIMEPersonalizedLearning, isFalse);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(submitted, '123456');
        final boxes = find.descendant(
          of: find.byType(OtpCodeField),
          matching: find.byType(Container),
        );
        await tester.tapAt(tester.getCenter(boxes.at(2)));
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 3),
        );
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '129456',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
        expect(controller.text, '129456');
        controller.clear();
        await tester.pump();
        expect(find.text('1'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'incorrect-code state highlights all six boxes in both palettes',
    (tester) async {
      final controller = TextEditingController(text: '123456');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 272,
                  child: OtpCodeField(
                    controller: controller,
                    focusNode: focus,
                    enabled: true,
                    hasError: true,
                    onSubmitted: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        for (final element
            in find
                .descendant(
                  of: find.byType(OtpCodeField),
                  matching: find.byType(Container),
                )
                .evaluate()) {
          final decoration =
              (element.widget as Container).decoration as BoxDecoration;
          expect(
            (decoration.border as Border).top.color,
            theme.colorScheme.error,
          );
          expect(decoration.boxShadow, isNotEmpty);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
