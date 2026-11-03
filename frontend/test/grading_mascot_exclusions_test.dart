import 'dart:async';

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
  for (final route in <Widget>[
    const GradebookScreen(classId: 'class'),
    const SubmissionsScreen(classId: 'class', postId: 'post'),
    const GradeScreen(classId: 'class', postId: 'post', studentId: 'student'),
  ]) {
    testWidgets(
      '${route.runtimeType} keeps loading, empty and failed reads neutral',
      (tester) async {
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
              child: MaterialApp(theme: theme, home: route),
            ),
          );
          await tester.pump();
          expect(find.byType(Mascot), findsNothing);
          snapshots.add(GradingData(userId: 'student', loaded: true));
          await tester.pump();
          await tester.pump();
          expect(find.byType(Mascot), findsNothing);
          snapshots.addError(StateError('Read failed'));
          await tester.pump();
          await tester.pump();
          expect(find.byType(Mascot), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.runAsync(snapshots.close);
        }
      },
    );
  }
}
