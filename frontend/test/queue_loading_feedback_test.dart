import 'dart:async';

import 'package:filo/core/widgets/filo_motion_widgets.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/grading/application/grading_providers.dart';
import 'package:filo/features/grading/domain/grading_models.dart';
import 'package:filo/features/grading/presentation/work_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fast local reads never mount loading feedback; slow ones do', (
    tester,
  ) async {
    const loading = MaterialApp(
      home: FiloDelayedLoading(child: Text('Loading files')),
    );
    await tester.pumpWidget(loading);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Loading files'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(loading);
    await tester.pump(const Duration(milliseconds: 249));
    expect(find.text('Loading files'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Loading files'), findsOneWidget);
  });

  for (final loaded in [false, true]) {
    test(
      'empty review snapshot loaded=$loaded distinguishes refresh from first load',
      () async {
        const room = ClassRoom(
          id: 'class',
          section: 'Section',
          course: 'Course',
          instructor: 'Instructor',
          color: 0,
        );
        final snapshots = StreamController<GradingData>();
        final refresh = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            classCardsProvider.overrideWith((ref) => Stream.value([room])),
            gradingDataProvider('class')
                .overrideWith((ref) => snapshots.stream),
            gradingSyncProvider('class').overrideWith((ref) => refresh.future),
          ],
        );
        final subscription = container.listen(
          workQueueProvider(false),
          (_, _) {},
        );
        await container.read(classCardsProvider.future);
        final dataReady = container.read(gradingDataProvider('class').future);
        snapshots.add(GradingData(userId: 'teacher', loaded: loaded));
        await dataReady;
        await container.pump();
        final queue = container.read(workQueueProvider(false));
        expect(queue.entries, isEmpty);
        expect(queue.loading, !loaded);
        expect(queue.loaded, loaded);
        refresh.complete();
        await container.pump();
        expect(container.read(workQueueProvider(false)).loading, isFalse);
        subscription.close();
        container.dispose();
        await snapshots.close();
      },
    );
  }
}
