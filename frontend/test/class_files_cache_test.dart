import 'dart:async';

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/supabase/session_gate.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/features/files/application/files_providers.dart';
import 'package:filo/features/files/presentation/class_files.dart';
import 'package:filo/features/posts/application/post_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = DateTime.utc(2026, 11, 5);
ClassFileEntry _entry() => ClassFileEntry(
  CachePost(
    id: 'post',
    classId: 'class',
    authorId: 'teacher',
    kind: 'material',
    title: 'Notes',
    acceptLate: false,
    allowFiles: false,
    maxFiles: 5,
    createdAt: _date,
    updatedAt: _date,
  ),
  CachePostAttachment(
    id: 'file',
    postId: 'post',
    kind: 'file',
    name: 'Notes.pdf',
    storagePath: 'class/Notes.pdf',
    sortOrder: 0,
    createdAt: _date,
    updatedAt: _date,
  ),
);

void main() {
  test('display snapshots survive query disposal and clear on account verification change', () async {
    final db = AppDatabase(NativeDatabase.memory());
    // Isolated query fixture does not exercise parent-record constraints.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final entry = _entry();
    await db.into(db.cachePosts).insert(entry.post);
    await db.into(db.cachePostAttachments).insert(entry.attachment);
    String? user = 'teacher';
    final container = ProviderContainer(
      overrides: [
        verifiedUserIdProvider.overrideWith((ref) async => user),
        accountDatabaseProvider.overrideWith((ref) async => db),
      ],
    );
    await container.read(verifiedUserIdProvider.future);
    await container.read(accountDatabaseProvider.future);
    final listener = container.listen(classFilesProvider('class'), (_, _) {});
    expect(
      await container.read(classFilesProvider('class').future),
      hasLength(1),
    );
    listener.close();
    await container.pump();
    expect(container.read(classFileSnapshotsProvider)['class'], hasLength(1));
    user = null;
    container.invalidate(verifiedUserIdProvider);
    await container.read(verifiedUserIdProvider.future);
    expect(container.read(classFileSnapshotsProvider), isEmpty);
    container.dispose();
    await db.close();
  });

  testWidgets(
    'reopened cached files remain visible during refresh and an empty filter has no loader',
    (tester) async {
      var subscriptions = 0, cancellations = 0;
      final changes = StreamController<List<ClassFileEntry>>.broadcast(
        onListen: () => subscriptions++,
        onCancel: () => cancellations++,
      );
      final refresh = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          classFileSnapshotsProvider.overrideWith(
            (ref) => {
              'class': [_entry()],
            },
          ),
          classFilesProvider('class').overrideWith((ref) => changes.stream),
          postSyncProvider('class').overrideWith((ref) => refresh.future),
          streamLoadedProvider('class')
              .overrideWith((ref) => Stream.value(false)),
          localFilesProvider.overrideWith((ref) => Stream.value([])),
          downloadManagerProvider.overrideWith((ref) async => null),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await changes.close();
      });
      Future<void> show(bool open) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: open
                    ? const ClassFiles(hasSamples: false, classId: 'class')
                    : const SizedBox(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      await show(true);
      expect(find.text('Notes.pdf'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading class files'), findsNothing);
      await show(false);
      expect(cancellations, 1);
      await show(true);
      expect(subscriptions, 2);
      expect(find.text('Notes.pdf'), findsOneWidget);
      await tester.tap(find.text('Images'));
      await tester.pump();
      expect(find.text('No matching files.'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading class files'), findsNothing);
      await show(false);
      container.read(classFileSnapshotsProvider).clear();
      await show(true);
      expect(find.bySemanticsLabel('Loading class files'), findsOneWidget);
      expect(find.text('No files yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
