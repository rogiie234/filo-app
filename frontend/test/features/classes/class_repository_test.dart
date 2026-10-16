import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/data/class_remote.dart';
import 'package:filo/features/classes/data/class_repository.dart';
import 'package:filo/features/classes/data/class_member_repository.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const stamp = '2026-10-15T10:00:00Z';
ClassRow profile(String id, String role) => {
  'id': id,
  'role': role,
  'display_name': id,
  'created_at': stamp,
  'updated_at': stamp,
};
ClassRow room({String id = 'c1', String updated = stamp}) => {
  'id': id,
  'owner_id': 'teacher',
  'course': 'Computing',
  'section': 'A',
  'school_year': '2026',
  'join_code': id,
  'created_at': stamp,
  'updated_at': updated,
};
ClassRow member({
  String status = 'active',
  String updated = stamp,
  String classId = 'c1',
}) => {
  'id': 'm$classId',
  'class_id': classId,
  'student_id': 'student',
  'status': status,
  'requested_at': stamp,
  'created_at': stamp,
  'updated_at': updated,
};

class FakeRemote implements ClassRemote {
  bool offline = false;
  Completer<void>? block;
  final data = <String, List<ClassRow>>{
    'profiles': [
      profile('teacher', 'instructor'),
      profile('student', 'student'),
    ],
    'classes': [room()],
    'class_members': [member()],
  };
  final calls = <(String, DateTime?)>[];
  final rpcCalls = <List<dynamic>>[];
  ClassRow? createdValues;
  @override
  Future<List<ClassRow>> read(
    String table, {
    DateTime? since,
    String? id,
    bool inventory = false,
  }) async {
    if (offline) throw const SocketException('offline');
    calls.add((table, since));
    await block?.future;
    return data[table]!
        .where(
          (r) =>
              (id == null || id == r['id']) &&
              (since == null ||
                  !DateTime.parse(r['updated_at'] as String).isBefore(since)),
        )
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  @override
  Future<ClassRow> createClass(ClassRow values) async {
    createdValues = values;
    final created = {...room(id: 'new-class'), ...values};
    data['classes']!.add(created);
    return created;
  }

  @override
  Future<dynamic> call(String name, ClassRow params) async {
    rpcCalls.add([name, params]);
    return null;
  }
}

void main() {
  late AppDatabase db;
  late FakeRemote remote;
  late ClassRepository repository;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeRemote();
    repository = ClassRepository(db, remote, 'student');
  });
  tearDown(() => db.close());

  test(
    'class card provider joins cached owner and pending membership',
    () async {
      remote.data['classes'] = [
        {...room(), 'archived_at': stamp, 'banner_color': 'teal'},
      ];
      remote.data['class_members'] = [member(status: 'pending')];
      await repository.sync();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          classRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(classCardsProvider, (_, _) {});
      addTearDown(subscription.close);
      final future = container.read(classCardsProvider.future);
      await container.pump();
      final cards = await future;
      expect(cards.single.instructor, 'teacher');
      expect(cards.single.pending, isTrue);
      expect(cards.single.archived, isTrue);
      expect(cards.single.joinCode, 'c1');
      expect(cards.single.color, 0xFF386D7A);
    },
  );
  test(
    'creation sends allowed metadata and leaves ID and join code to server',
    () async {
      final created = await repository.createClass(
        course: ' Computing ',
        section: ' A ',
        schoolYear: ' 2026 ',
      );
      expect(created['id'], 'new-class');
      expect(remote.createdValues, {
        'owner_id': 'student',
        'course': 'Computing',
        'section': 'A',
        'school_year': '2026',
        'banner_color': null,
      });
      expect(
        () => repository.createClass(
          course: '',
          section: 'A',
          schoolYear: '2026',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'one sync populates cache and offline reads survive failed sync',
    () async {
      await repository.sync();
      remote.offline = true;
      await expectLater(repository.sync(), throwsA(isA<SocketException>()));
      expect(
        (await repository.watchClasses().first).single.course,
        'Computing',
      );
      expect(
        (await ClassMemberRepository(
          repository,
        ).watchMembers('c1').first).single.status,
        'active',
      );
      expect((await db.select(db.syncState).get()).length, 2);
    },
  );
  test('cache survives closing and reopening the account database', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp(
      'filo-class-cache-',
    );
    final file = File('${directory.path}/account.sqlite');
    var disk = AppDatabase(NativeDatabase(file));
    try {
      await ClassRepository(disk, remote, 'student').sync();
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      remote.offline = true;
      expect(
        (await ClassRepository(
          disk,
          remote,
          'student',
        ).watchClasses().first).single.id,
        'c1',
      );
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
    }
  });
  for (final status in ['removed', 'left', 'declined']) {
    test('$status evicts student class and cascades members', () async {
      await repository.sync();
      remote.data['class_members'] = [
        member(status: status, updated: '2026-10-15T11:00:00Z'),
      ];
      await repository.sync();
      expect(await repository.watchClasses().first, isEmpty);
      expect(await db.select(db.cacheClassMembers).get(), isEmpty);
    });
  }
  test('pending membership stays cached and status changes sync', () async {
    remote.data['class_members'] = [member(status: 'pending')];
    await repository.sync();
    expect(
      (await db.select(db.cacheClassMembers).get()).single.status,
      'pending',
    );
    remote.data['class_members'] = [member(updated: '2026-10-15T11:00:00Z')];
    await repository.sync();
    expect(
      (await db.select(db.cacheClassMembers).get()).single.status,
      'active',
    );
  });
  test('owner keeps class when a student is removed', () async {
    repository = ClassRepository(db, remote, 'teacher');
    await repository.sync();
    remote.data['class_members'] = [member(status: 'removed')];
    await repository.sync();
    expect((await repository.watchClasses().first).length, 1);
  });
  test('deleted class and RLS-hidden class disappear', () async {
    await repository.sync();
    remote.data['classes'] = [
      {...room(), 'deleted_at': stamp},
    ];
    await repository.sync();
    expect(await repository.watchClasses().first, isEmpty);
    remote.data['classes'] = [room()];
    await repository.sync();
    expect((await repository.watchClasses().first).length, 1);
    remote.data['classes'] = [];
    await repository.sync();
    expect(await repository.watchClasses().first, isEmpty);
  });
  test(
    'new membership fetches unchanged old class and cursors are independent',
    () async {
      remote.data['classes'] = [room(updated: '2026-10-15T12:00:00Z')];
      await repository.sync();
      remote.data['classes']!.add(room(id: 'c2'));
      remote.data['class_members']!.add(
        member(classId: 'c2', updated: '2026-10-15T11:00:00Z'),
      );
      await repository.sync();
      expect(
        (await repository.watchClasses().first).map((r) => r.id),
        containsAll(['c1', 'c2']),
      );
      expect(
        remote.calls.any(
          (c) =>
              c.$1 == 'classes' &&
              c.$2?.isAtSameMomentAs(DateTime.parse('2026-10-15T12:00:00Z')) ==
                  true,
        ),
        isTrue,
      );
    },
  );
  test('failed transaction preserves data and cursors, then retries', () async {
    await repository.sync();
    remote.data['classes'] = [
      {...room(updated: '2026-10-15T11:00:00Z'), 'course': ''},
    ];
    await expectLater(repository.sync(), throwsA(anything));
    expect((await repository.watchClasses().first).single.course, 'Computing');
    expect(
      (await db.select(db.syncState).get()).every(
        (s) => s.lastSyncedAt?.isAtSameMomentAs(DateTime.parse(stamp)) == true,
      ),
      isTrue,
    );
    remote.data['classes'] = [
      {...room(updated: '2026-10-15T11:00:00Z'), 'course': 'Updated'},
    ];
    await repository.sync();
    expect((await repository.watchClasses().first).single.course, 'Updated');
  });
  test('simultaneous refreshes share a single pull', () async {
    remote.block = Completer<void>();
    final first = repository.sync();
    final second = repository.sync();
    expect(identical(first, second), isTrue);
    remote.block!.complete();
    await Future.wait([first, second]);
  });
  test('documented class and membership RPC arguments are exact', () async {
    await repository.requestJoin(' filo26 ');
    await repository.leave('c1');
    await repository.archive('c1');
    await repository.restore('c1');
    await repository.delete('c1', 'A');
    await repository.restoreDeleted('c1');
    final members = ClassMemberRepository(repository);
    await members.decide('mc1', true);
    await members.approveAll('c1');
    await members.remove('c1', 'student');
    await members.classmates('c1');
    expect(remote.rpcCalls, [
      [
        'request_join',
        {'p_code': 'FILO26'},
      ],
      [
        'leave_class',
        {'p_class': 'c1'},
      ],
      [
        'archive_class',
        {'p_class': 'c1'},
      ],
      [
        'restore_class',
        {'p_class': 'c1'},
      ],
      [
        'delete_class',
        {'p_class': 'c1', 'p_section': 'A'},
      ],
      [
        'restore_deleted_class',
        {'p_class': 'c1'},
      ],
      [
        'decide_join',
        {'p_member': 'mc1', 'p_approve': true},
      ],
      [
        'approve_all_pending',
        {'p_class': 'c1'},
      ],
      [
        'remove_member',
        {'p_class': 'c1', 'p_student': 'student'},
      ],
      [
        'list_classmates',
        {'p_class': 'c1'},
      ],
    ]);
  });
  testWidgets('opt-in lifecycle syncs on open, reconnect and resume', (
    tester,
  ) async {
    final network = StreamController<bool>();
    final counting = CountingRepository(db, remote);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classRepositoryProvider.overrideWith((ref) async => counting),
          connectivityProvider.overrideWith((ref) => network.stream),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(classSyncLifecycleProvider);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(counting.pulls, greaterThan(0));
    network.add(false);
    await tester.pumpAndSettle();
    final before = counting.pulls;
    network.add(true);
    await tester.pumpAndSettle();
    expect(counting.pulls, greaterThan(before));
    final reconnect = counting.pulls;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(counting.pulls, greaterThan(reconnect));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await network.close();
      await db.close();
    });
  });
}

class CountingRepository extends ClassRepository {
  CountingRepository(AppDatabase db, ClassRemote remote)
    : super(db, remote, 'student');
  int pulls = 0;
  @override
  Future<void> sync() async {
    pulls++;
  }
}
