import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:filo/core/notifications/deadline_reminders.dart';
import 'package:filo/core/notifications/push_events.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/notifications/data/alarm_repository.dart';
import 'package:filo/features/notifications/data/notification_destination_repository.dart';
import 'package:filo/core/sync/sync_coordinator.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

class StudyBridgeFixture extends DeadlineBridge {
  @override
  bool get supported => true;
  bool fail = false;
  int calls = 0;
  List<dynamic> completed = [];
  @override
  Future<List<dynamic>> reconcileStudy(String account, String lease) async {
    calls++;
    if (fail) throw StateError('Fixture scheduling failure');
    return completed;
  }
}

const alarmId = 'a0000000-0000-4000-8000-000000000001';
const accountId = 'a0000000-0000-4000-8000-000000000002';

class ChannelStudyBridge extends DeadlineBridge {
  @override
  bool get supported => true;
}

class DeferredStudyBridge extends StudyBridgeFixture {
  final response = Completer<List<dynamic>>();
  @override
  Future<List<dynamic>> reconcileStudy(String account, String lease) =>
      response.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late AlarmRepository repo;
  late StudyBridgeFixture bridge;
  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(),
      now: () => DateTime(2026, 11, 1, 10),
    );
    bridge = StudyBridgeFixture();
    repo = AlarmRepository(db, () => true, userId: accountId, bridge: bridge);
    await repo.setSetting('deadline_lease', 'fixture-session');
  });
  tearDown(() async => db.close());

  test('study channel carries the active lease and stays separate from deadline reconcile', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeadlineBridge.channel, (call) async {
          calls.add(call);
          return <dynamic>[];
        });
    try {
      await ChannelStudyBridge().reconcileStudy(accountId, 'session');
      expect(calls.single.method, 'studyReconcile');
      expect(calls.single.arguments, {
        'accountId': accountId,
        'lease': 'session',
      });
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeadlineBridge.channel, null);
    }
  });
  test(
    'late native completion cannot alter a switched account database',
    () async {
      await repo.saveStudy(id: alarmId, subject: 'Math', minute: 660, days: 0);
      var current = true;
      final deferred = DeferredStudyBridge();
      final stale = AlarmRepository(
        db,
        () => current,
        userId: accountId,
        bridge: deferred,
      );
      final result = stale.reconcileStudy();
      final check = expectLater(result, throwsA(isA<StudySchedulingFailure>()));
      current = false;
      deferred.response.complete([
        {
          'id': alarmId,
          'revision': jsonDecode(
            (await repo.setting('study_alarm:$alarmId'))!,
          )['revision'],
        },
      ]);
      await check;
      expect((await repo.readAlarms()).single.enabled, isTrue);
    },
  );

  test('one-time next occurrence uses calendar day and skips exact now', () {
    expect(
      nextStudyOnce(DateTime(2026, 12, 31, 23, 59), 1439),
      DateTime(2027, 1, 1, 23, 59),
    );
    expect(
      nextStudyOnce(DateTime(2026, 11, 1, 10), 601),
      DateTime(2026, 11, 1, 10, 1),
    );
  });
  test(
    'managed save, toggle and delete keep slots stable and deadlines untouched',
    () async {
      await db
          .into(db.deadlineReminders)
          .insert(
            DeadlineRemindersCompanion.insert(
              postId: 'post',
              fireAt: DateTime(2026, 11, 2),
              systemAlarmId: 1,
            ),
          );
      await repo.saveStudy(
        id: alarmId,
        subject: ' Biology ',
        minute: 660,
        days: 5,
      );
      final slots = await repo.readSlots(alarmId);
      expect(slots.map((s) => s.weekday), [1, 3]);
      final alarm = (await repo.readAlarms()).single;
      expect(alarm.subject, 'Biology');
      await repo.toggleStudy(alarm, false);
      expect((await repo.readAlarms()).single.enabled, isFalse);
      expect(
        (await repo.readSlots(alarmId)).map((s) => s.systemAlarmId),
        slots.map((s) => s.systemAlarmId),
      );
      await repo.saveStudy(
        id: alarmId,
        subject: 'Biology',
        minute: 700,
        days: 1,
      );
      expect(
        (await repo.readSlots(alarmId)).single.systemAlarmId,
        slots.first.systemAlarmId,
      );
      await repo.deleteStudy(alarmId);
      expect(await repo.readAlarms(), isEmpty);
      expect(await repo.readSlots(alarmId), isEmpty);
      expect(await repo.readReminders(), hasLength(1));
      expect(bridge.calls, 4);
    },
  );
  test('interrupted scheduling retains plan and retries without losing local changes', () async {
    bridge.fail = true;
    await expectLater(
      repo.saveStudy(id: alarmId, subject: 'History', minute: 610, days: 0),
      throwsA(isA<StudySchedulingFailure>()),
    );
    final meta = await repo.setting('study_alarm:$alarmId');
    expect(jsonDecode(meta!)['onceDate'], '2026-11-01');
    expect((await repo.readAlarms()).single.enabled, isTrue);
    expect(await repo.setting('study_error'), isNotEmpty);
    bridge.fail = false;
    await repo.reconcileStudy();
    expect(await repo.setting('study_alarm:$alarmId'), meta);
    expect(await repo.setting('study_error'), '');
  });
  test(
    'completion disables only matching one-time revision, never a newer edit',
    () async {
      await repo.saveStudy(id: alarmId, subject: 'Math', minute: 660, days: 0);
      final revision = jsonDecode(
        (await repo.setting('study_alarm:$alarmId'))!,
      )['revision'];
      bridge.completed = [
        {'id': alarmId, 'revision': revision},
      ];
      await repo.saveStudy(
        id: alarmId,
        subject: 'New Math',
        minute: 720,
        days: 0,
      );
      expect((await repo.readAlarms()).single.enabled, isTrue);
      bridge.completed = [
        {
          'id': alarmId,
          'revision': jsonDecode(
            (await repo.setting('study_alarm:$alarmId'))!,
          )['revision'],
        },
      ];
      await repo.reconcileStudy();
      expect((await repo.readAlarms()).single.enabled, isFalse);
    },
  );
  test('invalid input and account changes leave no partial write', () async {
    await expectLater(
      repo.saveStudy(id: alarmId, subject: ' ', minute: 1, days: 0),
      throwsArgumentError,
    );
    await expectLater(
      repo.saveStudy(
        id: alarmId,
        subject: 'Math',
        minute: 1,
        days: 0,
        classId: 'x',
        deckId: 'y',
      ),
      throwsArgumentError,
    );
    final stale = AlarmRepository(
      db,
      () => false,
      userId: accountId,
      bridge: bridge,
    );
    await expectLater(
      stale.saveStudy(id: alarmId, subject: 'Math', minute: 1, days: 0),
      throwsStateError,
    );
    expect(await repo.readAlarms(), isEmpty);
  });
  test('alarm metadata and enabled state survive reopening a separate account file', () async {
    final dir = await Directory.systemTemp.createTemp('filo-study-alarms-');
    final file = File('${dir.path}/account.sqlite');
    var disk = AppDatabase(NativeDatabase(file));
    try {
      var saved = AlarmRepository(
        disk,
        () => true,
        userId: accountId,
        bridge: bridge,
      );
      await saved.setSetting('deadline_lease', 'fixture-session');
      await saved.saveStudy(
        id: alarmId,
        subject: 'Physics',
        minute: 900,
        days: 64,
        enabled: false,
      );
      final meta = await saved.setting('study_alarm:$alarmId');
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      saved = AlarmRepository(
        disk,
        () => true,
        userId: accountId,
        bridge: bridge,
      );
      expect((await saved.readAlarms()).single.enabled, isFalse);
      expect(await saved.setting('study_alarm:$alarmId'), meta);
      expect(await repo.readAlarms(), isEmpty);
    } finally {
      await disk.close();
      await dir.delete(recursive: true);
    }
  });
  test(
    'study taps contain identifiers, dedupe and defer while an exam is active',
    () {
      final events = PushEvents();
      addTearDown(events.dispose);
      final tap = {
        'kind': 'study',
        'accountId': accountId,
        'alarmId': alarmId,
        'nonce': 'fixture',
      };
      events.receiveReminder(tap);
      events.receiveReminder(tap);
      expect(events.take(accountId, allowOpen: false), isNull);
      final event = events.take(accountId, allowOpen: true)!;
      expect(event.alarmId, alarmId);
      expect(event.id, isNull);
      expect(events.take(accountId, allowOpen: true), isNull);
      events.receiveReminder({...tap, 'nonce': 'foreign'});
      expect(events.take(alarmId, allowOpen: true), isNull);
    },
  );
  test('study destinations use current stored links and cached authorization without inbox writes', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test-key');
    final sync = SyncCoordinator(db, client, accountId, () => true);
    try {
      await db.saveProfile(
        CacheProfilesCompanion.insert(
          id: accountId,
          role: 'student',
          displayName: 'Student',
        ),
      );
      await repo.saveStudy(id: alarmId, subject: 'Math', minute: 660, days: 1);
      final destinations = NotificationDestinationRepository(
        db: db,
        client: client,
        sync: sync,
        userId: accountId,
        online: () => false,
        isCurrent: () => true,
        prepare: (_) async => fail('Offline tap must not prepare remotely'),
      );
      expect(
        (await destinations.resolveStudyAlarm(alarmId)).screen,
        NotificationScreen.study,
      );
      final now = DateTime.now();
      await db
          .into(db.notebooks)
          .insert(
            NotebooksCompanion.insert(
              id: 'notebook',
              name: 'Math',
              createdAt: now,
              updatedAt: now,
              lastOpenedAt: now,
            ),
          );
      await db
          .into(db.flashcardDecks)
          .insert(
            FlashcardDecksCompanion.insert(
              id: 'deck',
              notebookId: 'notebook',
              title: 'Cards',
              settings: '{}',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await repo.saveStudy(
        id: alarmId,
        subject: 'Math',
        minute: 660,
        days: 1,
        deckId: 'deck',
      );
      final deck = await destinations.resolveStudyAlarm(alarmId);
      expect(deck.screen, NotificationScreen.deck);
      expect(deck.notebookId, 'notebook');
      await db.delete(db.flashcardDecks).go();
      await expectLater(
        destinations.resolveStudyAlarm(alarmId),
        throwsA(isA<NotificationUnavailable>()),
      );
      await db.saveProfile(
        CacheProfilesCompanion.insert(
          id: 'teacher',
          role: 'instructor',
          displayName: 'Teacher',
        ),
      );
      await db
          .into(db.cacheClasses)
          .insert(
            CacheClassesCompanion.insert(
              id: 'class',
              ownerId: 'teacher',
              course: 'Math',
              section: 'A',
              schoolYear: '2026',
              joinCode: 'ABCDEF',
            ),
          );
      await db
          .into(db.cacheClassMembers)
          .insert(
            CacheClassMembersCompanion.insert(
              id: 'member',
              classId: 'class',
              studentId: accountId,
              status: const Value('active'),
            ),
          );
      await repo.saveStudy(
        id: alarmId,
        subject: 'Math',
        minute: 660,
        days: 1,
        classId: 'class',
      );
      expect(
        (await destinations.resolveStudyAlarm(alarmId)).screen,
        NotificationScreen.classroom,
      );
      await db
          .update(db.cacheClassMembers)
          .write(const CacheClassMembersCompanion(status: Value('removed')));
      await expectLater(
        destinations.resolveStudyAlarm(alarmId),
        throwsA(isA<NotificationUnavailable>()),
      );
      expect(await db.select(db.cacheNotifications).get(), isEmpty);
    } finally {
      sync.dispose();
      await client.dispose();
    }
  });
}
