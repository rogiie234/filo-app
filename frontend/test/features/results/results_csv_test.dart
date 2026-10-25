import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/features/results/application/results_providers.dart';
import 'package:filo/features/results/presentation/instructor_results_screen.dart';
import 'package:filo/features/results/domain/results.dart';
import 'package:filo/features/results/domain/results_csv.dart';

import 'results_screens_test.dart' show quizFixture, sessionFixture;

void main() {
  QuizMonitoring fixture({int? threshold = 70}) => QuizMonitoring({
    'quiz': {...quizFixture(), 'passing_percent': threshold, 'has_essay': true},
    'members': [
      for (final id in ['Ada', 'Ben', 'Cam', 'Dee', 'Eve'])
        {
          'student_id': id,
          'profile': {'display_name': id},
        },
    ],
    'sessions': [
      sessionFixture('Ada', 'submitted', score: 7, leaves: 2),
      sessionFixture('Ben', 'in_progress', score: 9, leaves: 3),
      sessionFixture('Dee', 'auto_submitted', score: 6, complete: false),
      sessionFixture('Eve', 'voided', score: 10),
    ],
    'second_chances': [
      {'student_id': 'Eve'},
    ],
  });

  test('headers, statuses, provisional scores and current attempts', () {
    final data = fixture();
    final csv = resultsCsv(data, monitoringStudents(data));
    expect(
      csv,
      startsWith(
        '\uFEFF"Student name","Status","Score","Total points","Percentage","Passed","Essays graded","Leave count"\r\n',
      ),
    );
    expect(csv, contains('"Ada","Graded","7","10","70","Yes","Yes","2"\r\n'));
    expect(csv, contains('"Ben","In progress","","10","","","No","3"'));
    expect(csv, contains('"Cam","Not started","","10","","","No","0"'));
    expect(csv, contains('"Dee","Essay to grade","6","10","60","","No","0"'));
    expect(csv, contains('"Eve","Not started","","10","","","No","0"'));
    expect(csv, isNot(contains('"100"')));
    expect(csv, endsWith('\r\n'));
    final absent = fixture(threshold: null);
    expect(
      resultsCsv(absent, monitoringStudents(absent)),
      isNot(contains('"Passed"')),
    );
  });

  test(
    'rounding, equality, below threshold, zero total and unavailable score',
    () {
      final data = fixture();
      final row = data.json['sessions'][0] as Map;
      final quiz = data.json['quiz'] as Map;
      quiz['total_points'] = 3;
      quiz['passing_percent'] = 67;
      row['total_score'] = 2;
      expect(
        resultsCsv(data, monitoringStudents(data)),
        contains('"2","3","67","Yes"'),
      );
      quiz['passing_percent'] = 68;
      expect(
        resultsCsv(data, monitoringStudents(data)),
        contains('"2","3","67","No"'),
      );
      quiz['total_points'] = 0;
      row['total_score'] = 0;
      expect(
        resultsCsv(data, monitoringStudents(data)),
        contains('"0","0","0","No"'),
      );
      row['total_score'] = null;
      expect(
        resultsCsv(data, monitoringStudents(data)),
        contains('"Ada","Graded","","0","","","Yes","2"'),
      );
      row['grading_complete'] = false;
      quiz['has_essay'] = false;
      expect(
        resultsCsv(data, monitoringStudents(data)),
        contains('"Ada","Submitted"'),
      );
    },
  );

  test('exports only selected rows in selected sort order', () {
    final data = fixture();
    final selected = monitoringStudents(data, sort: 'Most leaves first');
    final csv = resultsCsv(data, selected);
    expect(csv.indexOf('"Ben"'), lessThan(csv.indexOf('"Ada"')));
    final filtered = monitoringStudents(
      data,
      search: 'be',
      filter: 'In progress',
    );
    final small = resultsCsv(data, filtered);
    expect(small, contains('"Ben"'));
    expect(small, isNot(contains('"Ada"')));
    expect(small.split('\r\n'), hasLength(3));
  });

  test(
    'formula characters including whitespace and CSV special characters',
    () {
      final data = fixture();
      for (final name in ['=SUM(1)', '+1', '-1', '@SUM(1)', ' \t=1']) {
        final student = {
          'student_id': 'Cam',
          'profile': {'display_name': name},
        };
        expect(resultsCsv(data, [student]), contains('"\'$name"'));
      }
      final student = {
        'student_id': 'Cam',
        'profile': {'display_name': 'Peña, "Ana"\nTwo'},
      };
      expect(resultsCsv(data, [student]), contains('"Peña, ""Ana""\nTwo"'));
    },
  );

  test('safe filenames use Philippine date and fallback', () {
    final now = DateTime.utc(2026, 10, 25, 17);
    expect(
      resultsCsvFilename('../Quiz: One?', now),
      'Quiz_One_results_2026-10-26.csv',
    );
    expect(resultsCsvFilename('///', now), 'quiz_results_2026-10-26.csv');
    expect(resultsCsvFilename('x' * 200, now).length, lessThan(110));
  });

  Widget screen(QuizMonitoring? data) => ProviderScope(
    overrides: [
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
      quizMonitoringProvider('quiz').overrideWith(
        (ref) => Stream.value(
          ResultsState(data: data, cached: true, readOnly: true),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const InstructorResultsScreen(quizId: 'quiz'),
    ),
  );

  testWidgets(
    'cached archived export is enabled offline; empty search disables it',
    (tester) async {
      final data = fixture();
      (data.json['quiz'] as Map)['class'] = {
        'archived_at': '2026-01-01T00:00:00Z',
      };
      await tester.pumpWidget(screen(data));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Results options'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
            .enabled,
        isTrue,
      );
      await tester.tapAt(const Offset(20, 200));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nobody-matches');
      await tester.pump();
      await tester.tap(find.byTooltip('Results options'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
            .enabled,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('no authorized snapshot disables export', (tester) async {
    await tester.pumpWidget(screen(null));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Results options'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
          .enabled,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'writes under the existing cache directory and reaches share sheet',
    (tester) async {
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      late Directory root;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('filo-csv-regression-');
      });
      late Completer<void> shared;
      String? sharedPath;
      messenger.setMockMethodCallHandler(pathChannel, (_) async => root.path);
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        try {
          expect(call.method, 'share');
          final args = call.arguments as Map;
          sharedPath = (args['paths'] as List).single as String;
          final file = File(sharedPath!);
          expect(file.parent.parent.path, root.path);
          expect(
            file.parent.uri.pathSegments.where((p) => p.isNotEmpty).last,
            startsWith('filo-results-'),
          );
          final bytes = await file.readAsBytes();
          expect(
            bytes,
            utf8.encode(resultsCsv(fixture(), monitoringStudents(fixture()))),
          );
          expect(bytes.take(3).toList(), [239, 187, 191]);
          shared.complete();
        } catch (error, stack) {
          shared.completeError(error, stack);
        }
        return 'dev.fluttercommunity.plus/share/dismissed';
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(pathChannel, null);
        messenger.setMockMethodCallHandler(shareChannel, null);
        if (await root.exists()) await root.delete(recursive: true);
      });
      await tester.pumpWidget(screen(fixture()));
      await tester.pumpAndSettle();
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      await tester.runAsync(() async {
        // Start disk I/O and its completion in the real async zone.
        shared = Completer<void>();
        menu.onSelected!('csv');
        await shared.future.timeout(const Duration(seconds: 5));
        await Future.doWhile(() async {
          if (await root.list().isEmpty) return false;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return true;
        }).timeout(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
      expect(sharedPath, isNotNull);
      expect(find.text("Couldn't export results. Try again."), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending export prevents duplicate dispatch and failure allows retry',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final path = Completer<String>();
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
            expect(call.method, 'getTemporaryDirectory');
            calls++;
            return path.future;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(screen(fixture()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Results options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tap(find.byTooltip('Results options'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Exporting...'));
      await tester.pump();
      expect(calls, 1);
      path.completeError(
        PlatformException(code: 'temporary_directory_unavailable'),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 200));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't export results. Try again."), findsOneWidget);
      await tester.tap(find.byTooltip('Results options'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
