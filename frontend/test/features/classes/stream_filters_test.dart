import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/classes/application/preview_controller.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_screen.dart';
import 'package:filo/features/posts/presentation/stream_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AnnouncementPreview extends PreviewController {
  @override
  PreviewState build() => const PreviewState(
    posts: [
      ClassPost(
        id: 'notice',
        classId: 'it119',
        title: 'Notice',
        message: 'Details',
      ),
    ],
  );
}

void main() {
  testWidgets(
    'post type chips filter cached content and survive class tab changes',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ClassScreen(classId: 'it119'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final filter in {
        'Announcements': 'announcement',
        'Materials': 'material',
        'Assignments': 'assignment',
      }.entries) {
        await tester.tap(find.text(filter.key));
        await tester.pumpAndSettle();
        final cards = tester
            .widgetList<StreamPostCard>(find.byType(StreamPostCard))
            .toList();
        expect(cards, hasLength(1));
        expect(cards.single.post.postType, filter.value);
        expect(find.text('No posts yet'), findsNothing);
      }
      await tester.tap(find.text('Classwork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stream'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StreamPostCard>(find.byType(StreamPostCard))
            .post
            .postType,
        'assignment',
      );
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.byType(StreamPostCard), findsNWidgets(3));
    },
  );

  testWidgets(
    'empty filter offers reset without claiming the Stream is empty',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
            previewProvider.overrideWith(_AnnouncementPreview.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ClassScreen(classId: 'it119'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final material = find.text('Materials');
      await tester.ensureVisible(material);
      await tester.tap(material);
      await tester.pumpAndSettle();
      expect(find.text('No saved posts match this filter.'), findsOneWidget);
      expect(find.text('No posts yet'), findsNothing);
      await tester.ensureVisible(find.text('Show all posts'));
      await tester.tap(find.text('Show all posts'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StreamPostCard), findsOneWidget);
    },
  );
}
