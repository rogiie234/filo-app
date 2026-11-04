import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_banner.dart';
import 'package:filo/features/classes/presentation/class_banner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'banner sheet previews first, balances nine colors and requires a change',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(true)),
            classCardsProvider.overrideWith(
              (ref) => Stream.value(const [
                ClassRoom(
                  id: 'class',
                  section: 'BSIT-3A',
                  course: 'Course',
                  instructor: 'Teacher',
                  color: 0xFF236B57,
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: ClassBannerScreen(classId: 'class', embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(OutlinedButton), findsNWidgets(9));
      expect(
        tester.getTopLeft(find.byType(ClassBanner)).dy,
        lessThan(tester.getTopLeft(find.text('Banner color')).dy),
      );
      final tiles = find.byType(OutlinedButton);
      expect(
        tester.getTopLeft(tiles.at(0)).dy,
        tester.getTopLeft(tiles.at(2)).dy,
      );
      expect(
        tester.getTopLeft(tiles.at(3)).dy,
        greaterThan(tester.getTopLeft(tiles.at(2)).dy),
      );
      FiloButton save() => tester.widget<FiloButton>(
        find.byWidgetPredicate(
          (widget) => widget is FiloButton && widget.label == 'Save banner',
        ),
      );
      expect(save().onPressed, isNull);
      await tester.tap(find.text('Default'));
      await tester.pump();
      expect(save().onPressed, isNotNull);
      expect(find.text('Upload banner image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
