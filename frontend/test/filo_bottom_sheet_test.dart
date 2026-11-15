import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final title in [
    'File actions',
    'Move to folder',
    'Drive backup',
    'Class options',
    'Notification settings',
    'Class settings',
    'Change banner',
    'Generate with AI',
    'Find your classroom.',
  ]) {
    testWidgets(
      '$title shares an accessible, keyboard-safe header and actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showFiloBottomSheet<String>(
                      context: context,
                      title: title,
                      animate: false,
                      builder: (sheet) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TextField(
                              decoration: InputDecoration(labelText: 'Entry'),
                              maxLines: 4,
                            ),
                            FiloSheetAction(
                              label: 'Delete',
                              icon: FiloIcons.delete,
                              destructive: true,
                              onTap: () => Navigator.pop(sheet, 'delete'),
                            ),
                            const FiloSheetAction(
                              label: 'Unavailable',
                              icon: FiloIcons.folder,
                              onTap: null,
                            ),
                            FiloButton(
                              label: 'Save',
                              onPressed: () => Navigator.pop(sheet, 'save'),
                            ),
                          ],
                        ),
                      ),
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
        expect(find.text(title), findsOneWidget);
        expect(find.byTooltip('Close'), findsOneWidget);
        expect(
          tester.getSize(find.byTooltip('Close')).width,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getRect(find.text(title)).right,
          lessThanOrEqualTo(tester.getRect(find.byTooltip('Close')).left),
        );
        final handle = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 40 &&
              w.constraints?.maxHeight == 4,
        );
        expect(tester.getCenter(handle).dx, closeTo(160, 1));
        await tester.ensureVisible(find.text('Delete'));
        final delete = tester.widget<Text>(find.text('Delete'));
        expect(delete.style!.color, AppTheme.light.colorScheme.error);
        expect(
          tester
              .widget<FiloSheetAction>(
                find.widgetWithText(FiloSheetAction, 'Unavailable'),
              )
              .onTap,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(result, 'save');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long folder pickers remain lazy and preserve their selection result',
    (tester) async {
      var built = 0;
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showFiloBottomSheet<int>(
                    context: context,
                    title: 'Move to folder',
                    animate: false,
                    scrollBody: false,
                    builder: (sheet) => ListView.builder(
                      itemCount: 1000,
                      itemBuilder: (_, index) {
                        built++;
                        return FiloSheetAction(
                          label: 'Folder $index',
                          icon: FiloIcons.folder,
                          onTap: () => Navigator.pop(sheet, index),
                        );
                      },
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
      expect(built, lessThan(40));
      await tester.tap(find.text('Folder 0'));
      await tester.pumpAndSettle();
      expect(result, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
