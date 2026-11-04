import 'dart:async';

import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/supabase/supabase_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_screen.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/posts/application/post_providers.dart';
import 'package:filo/features/posts/presentation/stream_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(
    () => binding.platformDispatcher.clearAccessibilityFeaturesTestValue(),
  );
  testWidgets('delete hides immediately and restores after server failure', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    var requests = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) {
        requests++;
        return gate.future;
      }),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classSyncLifecycleProvider.overrideWith((ref) {}),
          postSyncLifecycleProvider('class').overrideWith((ref) {}),
          postSyncProvider('class').overrideWith((ref) async {}),
          streamLoadedProvider('class')
              .overrideWith((ref) => Stream.value(true)),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          classCardsProvider.overrideWith(
            (ref) => Stream.value([
              const ClassRoom(
                id: 'class',
                section: 'Section',
                course: 'Course',
                instructor: 'Teacher',
                color: 0xFF236B57,
              ),
            ]),
          ),
          streamPostsProvider('class').overrideWith(
            (ref) => Stream.value([
              ClassPost(
                id: 'post',
                classId: 'class',
                title: 'Keep this post',
                message: 'Message',
                assignment: false,
                createdAt: DateTime.utc(2026, 11, 4),
              ),
            ]),
          ),
          supabaseClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ClassScreen(
            classId: 'class',
            profile: AccountProfile.fromJson({
              'id': 'owner',
              'role': 'instructor',
              'display_name': 'Teacher',
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<StreamPostCard>(find.byType(StreamPostCard)).onDelete!();
    await tester.pumpAndSettle();
    expect(find.text('Keep this post'), findsOneWidget);
    await tester.tap(find.widgetWithText(FiloButton, 'Delete post'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Keep this post'), findsNothing);
    gate.complete(
      http.Response(
        '{"code":"42501","message":"denied"}',
        403,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep this post'), findsOneWidget);
    expect(
      find.text('Could not confirm deletion. Refresh and try again.'),
      findsOneWidget,
    );
  });
}
