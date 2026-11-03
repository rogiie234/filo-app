import 'dart:async';

import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/grading/application/grading_providers.dart';
import 'package:filo/features/grading/data/grading_repository.dart';
import 'package:filo/features/grading/domain/grading_models.dart';
import 'package:filo/features/grading/presentation/grade_screen.dart';
import 'package:filo/features/grading/presentation/submissions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Grades implements GradingRepository {
  _Grades() {
    data = GradingData(
      userId: 'teacher',
      loaded: true,
      assignments: [
        {'id': 'post', 'title': 'Assignment', 'points': 10},
      ],
      members: [
        {
          'student_id': 'student',
          'display_name': 'Student',
          'status': 'active',
        },
      ],
      submissions: [
        {
          'id': 'submission',
          'student_id': 'student',
          'post_id': 'post',
          'status': 'turned_in',
          'submitted_at': '2026-11-03T00:00:00Z',
          'items': <Json>[],
        },
      ],
      grades: [grade],
    );
  }
  final grade = <String, dynamic>{
    'submission_id': 'submission',
    'score': 5,
    'feedback': '',
    'returned_at': null,
  };
  late GradingData data;
  Completer<void>? pending;
  bool fail = false;
  int changed = 1;
  @override
  Future<GradingData> read(String classId) async => data;
  @override
  Future<void> save(
    String classId,
    String postId,
    String studentId,
    int score,
    String feedback,
  ) async {
    await pending?.future;
    if (fail) throw StateError('Unconfirmed write');
    grade['score'] = score;
    grade['feedback'] = feedback;
  }

  @override
  Future<int> returnOne(String classId, String submissionId) async {
    await pending?.future;
    if (fail) throw StateError('Unconfirmed return');
    return changed;
  }

  @override
  Future<int> returnAll(String classId, String postId) =>
      returnOne(classId, 'submission');
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected call ${invocation.memberName}');
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate')
          calls.add(call.arguments as String);
        return null;
      },
    );
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  Future<void> mount(
    WidgetTester tester,
    _Grades grades, {
    bool bulk = false,
  }) async {
    final date = DateTime.utc(2026, 11, 3);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
          classesProvider.overrideWith(
            (ref) => Stream.value([
              CacheClassesData(
                id: 'class',
                ownerId: 'teacher',
                course: 'Course',
                section: 'Section',
                schoolYear: '2026',
                joinCode: 'CODE',
                createdAt: date,
                updatedAt: date,
              ),
            ]),
          ),
          gradingRepositoryProvider.overrideWith((ref) async => grades),
          gradingDataProvider('class')
              .overrideWith((ref) => Stream.value(grades.data)),
          gradingSyncProvider('class').overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: FiloMotionScope(
            child: bulk
                ? const SubmissionsScreen(classId: 'class', postId: 'post')
                : const GradeScreen(
                    classId: 'class',
                    postId: 'post',
                    studentId: 'student',
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.byType(Mascot), findsNothing);
    expect(find.byType(FiloSuccessMoment), findsNothing);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final fail in [false, true]) {
    testWidgets(
      'grade save feedback follows confirmed result (failure=$fail)',
      (tester) async {
        final grades = _Grades()
          ..fail = fail
          ..pending = Completer<void>();
        await mount(tester, grades);
        await tester.enterText(find.byType(TextFormField).first, '8');
        await tap(tester, find.widgetWithText(FilledButton, 'Save'));
        expect(calls, isEmpty);
        grades.pending!.complete();
        await tester.pumpAndSettle();
        expect(calls, fail ? isEmpty : ['HapticFeedbackType.lightImpact']);
        expect(find.byType(FiloSuccessMoment), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final bulk in [false, true]) {
    for (final count in [0, 1]) {
      testWidgets(
        'return feedback only for positive confirmation (bulk=$bulk,count=$count)',
        (tester) async {
          final grades = _Grades()..changed = count;
          await mount(tester, grades, bulk: bulk);
          final action = bulk
              ? find.textContaining('Return all graded')
              : find.widgetWithText(OutlinedButton, 'Return');
          await tap(tester, action);
          await tap(tester, find.text('Cancel'));
          expect(calls, isEmpty);
          await tap(tester, action);
          await tap(tester, find.widgetWithText(FilledButton, 'Return'));
          expect(
            calls,
            count == 0 ? isEmpty : ['HapticFeedbackType.lightImpact'],
          );
          expect(find.byType(Mascot), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
