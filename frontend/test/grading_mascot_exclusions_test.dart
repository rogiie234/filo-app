import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/core/widgets/filo_widgets.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/grading/application/grading_providers.dart';
import 'package:filo/features/grading/domain/grading_models.dart';
import 'package:filo/features/grading/presentation/gradebook_screen.dart';
import 'package:filo/features/grading/presentation/grade_screen.dart';
import 'package:filo/features/grading/presentation/submissions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'gradebook labels repeated scores with student and assessment context',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final data = GradingData(
        userId: 'teacher',
        loaded: true,
        members: [
          for (final name in ['Ada', 'Ben'])
            {
              'student_id': name,
              'status': 'active',
              'profiles': {'display_name': name},
            },
        ],
        assignments: [
          {
            'id': 'post',
            'title': 'A long assessment title that needs its full label',
            'points': 10,
          },
        ],
        quizzes: [
          {'id': 'quiz', 'title': 'Unstarted quiz', 'total_points': 10},
        ],
        submissions: [
          for (final name in ['Ada', 'Ben'])
            {
              'id': name,
              'post_id': 'post',
              'student_id': name,
              'status': 'turned_in',
              'items': <Json>[],
            },
        ],
        grades: [
          for (final name in ['Ada', 'Ben'])
            {'submission_id': name, 'score': 5},
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => Stream.value(false)),
            classesProvider.overrideWith((ref) => Stream.value([])),
            gradingSyncProvider('class').overrideWith((ref) async {}),
            gradingDataProvider('class')
                .overrideWith((ref) => Stream.value(data)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GradebookScreen(classId: 'class'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Table'));
      await tester.pump();
      for (final name in ['Ada', 'Ben']) {
        final label =
            '$name, A long assessment title that needs its full label, 5';
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(find.byTooltip(label), findsOneWidget);
        final unstarted = tester.getSemantics(
          find.bySemanticsLabel('$name, Unstarted quiz, \u2014'),
        );
        expect(
          unstarted.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final route in <Widget>[
    const GradebookScreen(classId: 'class'),
    const SubmissionsScreen(classId: 'class', postId: 'post'),
    const GradeScreen(classId: 'class', postId: 'post', studentId: 'student'),
  ]) {
    testWidgets(
      '${route.runtimeType} keeps loading, empty and failed reads neutral',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final theme in [AppTheme.light, AppTheme.dark]) {
          final snapshots = StreamController<GradingData>.broadcast();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                connectivityProvider.overrideWith((ref) => Stream.value(false)),
                classesProvider.overrideWith((ref) => Stream.value([])),
                gradingSyncProvider('class').overrideWith((ref) async {}),
                gradingDataProvider('class')
                    .overrideWith((ref) => snapshots.stream),
              ],
              child: MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: route,
              ),
            ),
          );
          await tester.pump();
          expect(find.byType(Mascot), findsNothing);
          for (final element in find.byType(Scaffold).evaluate()) {
            expect(MediaQuery.disableAnimationsOf(element), isTrue);
          }
          snapshots.add(GradingData(userId: 'student', loaded: true));
          await tester.pump();
          await tester.pump();
          expect(find.byType(Mascot), findsNothing);
          for (final element in find.byType(Scaffold).evaluate()) {
            expect(MediaQuery.disableAnimationsOf(element), isTrue);
          }
          snapshots.addError(StateError('Read failed'));
          await tester.pump();
          await tester.pump();
          expect(find.byType(Mascot), findsNothing);
          for (final element in find.byType(Scaffold).evaluate()) {
            expect(MediaQuery.disableAnimationsOf(element), isTrue);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.runAsync(snapshots.close);
        }
      },
    );
  }
}
