import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/classes/domain/class_banner.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_banner.dart';
import 'package:filo/features/classes/presentation/classes_widgets.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledImage extends ImageProvider<_ControlledImage> {
  final frame = Completer<ImageInfo>();
  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _ControlledImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(frame.future);
}

double _contrast(Color a, Color b) =>
    (math.max(a.computeLuminance(), b.computeLuminance()) + .05) /
    (math.min(a.computeLuminance(), b.computeLuminance()) + .05);

void main() {
  test(
    'eight persisted IDs, light variants and safe default remain compatible',
    () {
      expect(classBannerColors.keys, [
        'forest',
        'teal',
        'sage',
        'pine',
        'ocean',
        'slate',
        'olive',
        'plum',
      ]);
      expect(classBannerColor('sage'), 0xFFD4DACE);
      expect(classBannerColor('olive'), 0xFFD5D8C9);
      expect(classBannerColor('forest'), 0xFF236B57);
      expect(classBannerColor(null), classBannerColor('forest'));
      expect(classBannerColor('unknown'), classBannerColor('forest'));
      for (final entry in classBannerColors.entries) {
        expect(
          ClassBanner.foreground(entry.value),
          ['sage', 'olive'].contains(entry.key) ? FiloColors.ink : Colors.white,
        );
      }
    },
  );

  test('text and icons meet contrast on base, pattern and brightest photo', () {
    for (final brightness in Brightness.values) {
      for (final value in classBannerColors.values) {
        final ink = ClassBanner.foreground(value, brightness: brightness);
        final base = ClassBanner.presetBackground(value, brightness);
        final pattern = Color.alphaBlend(
          ClassBanner.landscapeTint(value, brightness: brightness),
          base,
        );
        for (final fill in [base, pattern]) {
          expect(_contrast(ink, fill), greaterThanOrEqualTo(4.5));
        }
      }
    }
    expect(
      _contrast(
        Colors.white,
        Color.alphaBlend(ClassBanner.imageScrim, Colors.white),
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  Future<void> mount(WidgetTester tester, Widget child, ThemeData theme) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        themeAnimationDuration: Duration.zero,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  Finder patterns() => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is ResizeImage &&
        (w.image as ResizeImage).imageProvider is AssetImage &&
        ((w.image as ResizeImage).imageProvider as AssetImage).assetName ==
            'assets/illustrations/class-banner-landscape.png',
  );

  testWidgets(
    'presets wrap at 130%, expose text and hide decorative landscape',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final theme in [AppTheme.light, AppTheme.dark]) {
          for (final entry in classBannerColors.entries) {
            await mount(
              tester,
              ClassBanner(
                color: entry.value,
                section: 'BSIT - a long Section name that wraps',
                instructor: 'Instructor with a long display name',
              ),
              theme,
            );
            expect(patterns(), findsOneWidget);
            expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
            final title = tester.widget<Text>(
              find.text('BSIT - a long Section name that wraps'),
            );
            expect(
              title.style!.color,
              ClassBanner.foreground(entry.value, brightness: theme.brightness),
            );
            expect(
              find.bySemanticsLabel('Instructor with a long display name'),
              findsOneWidget,
            );
            expect(find.byType(ExcludeSemantics), findsWidgets);
            expect(tester.takeException(), isNull);
          }
        }
        await mount(
          tester,
          const ClassBanner(
            color: 0xFFFFFFFF,
            section: 'Default',
            instructor: 'Instructor',
          ),
          AppTheme.light,
        );
        final landscape = tester.widget<Image>(patterns());
        expect(landscape.color, Colors.black.withValues(alpha: .3));
        expect(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == Color(classBannerColor(null)),
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'loading, decoded bright image and error use the same safe renderer',
    (tester) async {
      final image = _ControlledImage();
      await mount(
        tester,
        ClassBanner(
          section: 'Bright image',
          instructor: 'Instructor',
          image: image,
        ),
        AppTheme.dark,
      );
      expect(patterns(), findsOneWidget);
      expect(
        tester
            .widget<Image>(
              find.byWidgetPredicate(
                (widget) => widget is Image && identical(widget.image, image),
              ),
            )
            .fit,
        BoxFit.cover,
      );
      final info = await tester.runAsync(() async {
        final data = await rootBundle.load('assets/gallery/bright_banner.png');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return ImageInfo(image: frame.image);
      });
      image.frame.complete(info!);
      await tester.pump();
      await tester.pump();
      expect(patterns(), findsNothing);
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>();
      expect(
        gradients.any((g) => g.colors.first == ClassBanner.imageScrim),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final failed = _ControlledImage();
      await mount(
        tester,
        ClassBanner(
          section: 'Failed image',
          instructor: 'Instructor',
          image: failed,
        ),
        AppTheme.light,
      );
      failed.frame.completeError(StateError('Fixture decode failure'));
      await tester.pump();
      expect(patterns(), findsOneWidget);
      expect(find.text('Failed image'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await image.evict();
      await failed.evict();
    },
  );

  testWidgets(
    'offline private banner falls back and pending class stays disabled',
    (tester) async {
      var taps = 0;
      await mount(
        tester,
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: ClassCard(
            room: const ClassRoom(
              id: 'class',
              section: 'Offline class',
              course: 'Course',
              instructor: 'Instructor',
              color: 0xFFD4DACE,
              bannerPath: 'class/banner.png',
              pending: true,
            ),
            onTap: () => taps++,
          ),
        ),
        AppTheme.light,
      );
      await tester.pump();
      expect(patterns(), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Offline class')).style!.color,
        Colors.white,
      );
      await tester.tap(find.text('Offline class'));
      expect(taps, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
