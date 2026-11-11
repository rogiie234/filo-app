import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'four-destination dock fits narrow enlarged text and retains disabled navigation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final direction in TextDirection.values) {
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: Directionality(textDirection: direction, child: child!),
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: FiloNavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (value) =>
                      setState(() => selected = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.school_outlined),
                      label: 'Classes',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        label: Text('2'),
                        child: Icon(Icons.assignment_outlined),
                      ),
                      label: 'To review',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_outlined),
                      label: 'Files',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      label: 'AI Study',
                      enabled: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Files'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          2,
        );
        await tester.tap(find.text('AI Study'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
