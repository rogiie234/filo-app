import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/supabase/supabase_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/data/class_repository.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/posts/application/post_providers.dart';
import 'package:filo/features/posts/presentation/create_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Classes extends Fake implements ClassRepository {
  @override
  String get userId => 'owner';
}

void main() {
  for (final succeeds in [true, false]) {
    testWidgets('publication success=$succeeds closes only confirmed success', (
      tester,
    ) async {
      var publications = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/classes')) {
            return http.Response(
              '{"owner_id":"owner","archived_at":null,"deleted_at":null}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          publications++;
          return succeeds
              ? http.Response('', 201)
              : http.Response(
                  '{"code":"42501","message":"denied"}',
                  403,
                  headers: {'content-type': 'application/json'},
                );
        }),
      );
      addTearDown(client.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
            classRepositoryProvider.overrideWith((ref) async => _Classes()),
            supabaseClientProvider.overrideWithValue(client),
            postRepositoryProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreatePostScreen(classId: 'class'),
                    ),
                  ),
                  child: const Text('Stream'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Stream'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).bottomNavigationBar,
        isNull,
      );
      expect(find.text('Delete post'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Announcement');
      final post = find.widgetWithText(FiloButton, 'Post');
      expect(
        tester
            .widget<Scaffold>(find.byType(Scaffold).last)
            .floatingActionButton,
        isNotNull,
      );
      expect(tester.widget<FiloButton>(post).minHeight, 64);
      await tester.tap(post);
      await tester.pumpAndSettle();
      expect(publications, 1);
      expect(
        find.byType(CreatePostScreen),
        succeeds ? findsNothing : findsOneWidget,
      );
      if (!succeeds)
        expect(
          find.textContaining('Posting permission was denied'),
          findsOneWidget,
        );
    });
  }
}
