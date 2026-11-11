import 'dart:async';

import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_components.dart';
import 'package:filo/features/classes/presentation/classes_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('avatar shows skeleton while signing and initials for no photo', (
    tester,
  ) async {
    final pending = Completer<String?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classImageProvider(('avatars', 'teacher.png'))
              .overrideWith((ref) => pending.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: FiloAvatar(name: 'Teacher', path: 'teacher.png', size: 32),
          ),
        ),
      ),
    );
    expect(find.byType(FiloSkeleton), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
    pending.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.byType(FiloSkeleton), findsNothing);
    expect(find.text('T'), findsOneWidget);
  });

  testWidgets('signing failure ends skeleton and shows initials', (
    tester,
  ) async {
    final pending = Completer<String?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classImageProvider(('avatars', 'teacher.png'))
              .overrideWith((ref) => pending.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: FiloAvatar(name: 'Teacher', path: 'teacher.png'),
          ),
        ),
      ),
    );
    expect(find.byType(FiloSkeleton), findsOneWidget);
    pending.completeError(StateError('Unavailable'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FiloSkeleton), findsNothing);
    expect(find.text('T'), findsOneWidget);
  });

  testWidgets('network frame placeholder ends on decoded or cached image', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: FiloAvatar(
              name: 'Teacher',
              url: 'https://example.test/avatar.png',
            ),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final context = tester.element(find.byType(Image));
    const decoded = SizedBox();
    expect(
      image.frameBuilder!(context, decoded, null, false),
      isA<FiloSkeleton>(),
    );
    expect(image.frameBuilder!(context, decoded, 0, false), same(decoded));
    expect(image.frameBuilder!(context, decoded, null, true), same(decoded));
    expect(
      image.errorBuilder!(context, StateError('Offline'), null),
      isA<ColoredBox>(),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
