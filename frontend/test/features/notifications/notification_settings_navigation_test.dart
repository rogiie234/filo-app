import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:filo/features/onboarding/application/notification_permission.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/assessments/application/instructor_quiz_providers.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/class_screen.dart';
import 'package:filo/features/classes/presentation/class_banner.dart';
import 'package:filo/features/classes/presentation/classwork_list.dart';
import 'package:filo/features/exams/application/exam_providers.dart';
import 'package:filo/features/exams/domain/exam.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/presentation/notification_settings_screen.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/posts/application/post_providers.dart';
import 'package:filo/features/submissions/application/submission_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_settings_test_support.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  for (final role in AccountRole.values) {
    testWidgets('${role.name} class menu opens T3 focused on its class', (
      tester,
    ) async {
      const classFixture = ClassRoom(
        id: 'class',
        section: 'BSIT-3A',
        course: 'Computing',
        instructor: 'Teacher',
        color: 0xFF236B57,
        archived: true,
        joinCode: 'JOIN123',
      );
      final settings = FakeSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deadlineBridgeProvider.overrideWithValue(const NoDeadlineBridge()),
            connectivityProvider.overrideWithValue(const AsyncData(false)),
            notificationAccessProvider.overrideWith((ref) async => false),
            classCardsProvider.overrideWith(
              (ref) => Stream.value([classFixture]),
            ),
            classSyncLifecycleProvider.overrideWith((ref) {}),
            pendingClassRequestsProvider.overrideWith(
              (ref) => Stream.value({}),
            ),
            postSyncLifecycleProvider('class').overrideWith((ref) {}),
            postSyncProvider('class').overrideWith((ref) async {}),
            streamLoadedProvider('class')
                .overrideWith((ref) => Stream.value(false)),
            streamPostsProvider('class')
                .overrideWith((ref) => Stream.value([])),
            classFilesProvider('class').overrideWith((ref) => Stream.value([])),
            instructorQuizzesProvider('class')
                .overrideWith((ref) => Stream.value([])),
            instructorAssignmentsRefreshProvider('class')
                .overrideWith((ref) async {}),
            instructorQuizListRefreshProvider('class')
                .overrideWith((ref) async {}),
            classworkLoadedProvider('instructor_classwork_posts:class')
                .overrideWith((ref) => Stream.value(true)),
            classworkLoadedProvider('submissions:class')
                .overrideWith((ref) => Stream.value(true)),
            studentQuizCatalogProvider.overrideWith(
              (ref) => Stream.value(const StudentQuizCatalog([], loaded: true)),
            ),
            studentQuizNowProvider.overrideWith(
              (ref) => Stream.value(DateTime(2026)),
            ),
            submissionSyncLifecycleProvider('class').overrideWith((ref) {}),
            submissionSyncProvider('class').overrideWith((ref) async {}),
            classSubmissionsProvider('class')
                .overrideWith((ref) => Stream.value([])),
            returnedGradesProvider('class')
                .overrideWith((ref) => Stream.value([])),
            notificationSettingsRepositoryProvider.overrideWith(
              (ref) async => settings,
            ),
            notificationPreferencesProvider.overrideWith(
              (ref) => settings.watch(),
            ),
            notificationPreferencesRefreshProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ClassScreen(
              classId: 'class',
              profile: AccountProfile.fromJson({
                'id': 'user',
                'role': role.name,
                'display_name': 'Fixture',
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Class menu'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ClassBanner>(find.byType(ClassBanner)).color,
        classFixture.color,
      );
      expect(find.text('Class details'), findsNothing);
      expect(
        find.text('Copy code'),
        role == AccountRole.instructor ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Share class'),
        role == AccountRole.instructor ? findsOneWidget : findsNothing,
      );
      if (role == AccountRole.instructor) {
        final share = find
            .ancestor(
              of: find.text('Share class'),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            )
            .first;
        expect(tester.widget<TextButton>(share).onPressed, isNull);
      }
      await tester.tap(find.text('Notification settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NotificationSettingsScreen>(
              find.byType(NotificationSettingsScreen),
            )
            .initialClassId,
        'class',
      );
      expect(find.text('Selected class · Archived'), findsOneWidget);
      expect(
        tester
            .widget<NotificationSettingsScreen>(
              find.byType(NotificationSettingsScreen),
            )
            .embedded,
        isTrue,
      );
      expect(
        find.ancestor(
          of: find.byType(NotificationSettingsScreen),
          matching: find.byType(BottomSheet),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await settings.changes.close();
    });
  }
}
