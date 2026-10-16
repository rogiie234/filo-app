import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/data/class_remote.dart';
import 'package:filo/features/classes/data/class_repository.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/classes_screen.dart';
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_repository_test.dart' show FakeRemote;

const cachedRoom = ClassRoom(
  id: 'real-class',
  section: 'BSIT-3A',
  course: 'Computing',
  instructor: 'Andrea',
  color: 0xFF236B57,
  schoolYear: '2026-2027',
  joinCode: 'FILO26',
);

class UiRepository extends ClassRepository {
  UiRepository(AppDatabase db, this.publish)
    : super(db, FakeRemote(), 'teacher');
  final void Function(ClassRoom room) publish;
  String joinResult = 'requested';
  String? submittedCode;
  ClassRow? createdValues;
  int creates = 0, pulls = 0;
  bool failPull = false;
  bool loseCreateResponse = false;
  @override
  Future<dynamic> requestJoin(String code) async {
    submittedCode = code;
    if (joinResult == 'requested') {
      publish(
        const ClassRoom(
          id: 'pending',
          section: 'Pending section',
          course: 'Data Structures',
          instructor: 'Sofia',
          color: 0xFF647C58,
          pending: true,
        ),
      );
    }
    return joinResult;
  }

  @override
  Future<ClassRow> createClass({
    required String course,
    required String section,
    required String schoolYear,
    String? bannerColor,
  }) async {
    creates++;
    createdValues = {
      'course': course.trim(),
      'section': section.trim(),
      'school_year': schoolYear.trim(),
      'banner_color': bannerColor,
    };
    publish(
      ClassRoom(
        id: 'created',
        section: section.trim(),
        course: course.trim(),
        instructor: 'Alex',
        color: 0xFF386D7A,
        schoolYear: schoolYear.trim(),
        joinCode: 'NEW123',
      ),
    );
    if (loseCreateResponse) throw const SocketException('response lost');
    return {'id': 'created'};
  }

  @override
  Future<void> sync() async {
    pulls++;
    if (failPull) throw StateError('offline');
  }
}

class Harness {
  Harness(
    this.repository,
    this.network,
    this.cards,
    this.rooms,
    this.captureKey,
  );
  final UiRepository repository;
  final StreamController<bool> network;
  final StreamController<List<ClassRoom>> cards;
  final List<ClassRoom> rooms;
  final GlobalKey captureKey;
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Nunito',
    )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<Harness> launch(
    WidgetTester tester, {
    AccountRole role = AccountRole.student,
    bool online = true,
    bool empty = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = AppDatabase(NativeDatabase.memory());
    final network = StreamController<bool>();
    final cards = StreamController<List<ClassRoom>>();
    final rooms = <ClassRoom>[if (!empty) cachedRoom];
    final repo = UiRepository(db, (room) {
      rooms.add(room);
      cards.add(List.of(rooms));
    });
    final capture = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classRepositoryProvider.overrideWith((ref) async => repo),
          classCardsProvider.overrideWith((ref) async* {
            yield List.of(rooms);
            yield* cards.stream;
          }),
          connectivityProvider.overrideWith((ref) async* {
            yield online;
            yield* network.stream;
          }),
          classSyncLifecycleProvider.overrideWith((ref) {}),
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: ClassesScreen(
              profile: AccountProfile.fromJson({
                'id': 'teacher',
                'role': role.name,
                'display_name': 'Alex',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand/icon.png'),
        capture.currentContext!,
      );
      if (!capture.currentContext!.mounted) return;
      await precacheImage(
        const AssetImage('assets/mascots/waving.png'),
        capture.currentContext!,
      );
      if (!capture.currentContext!.mounted) return;
      await precacheImage(
        const AssetImage('assets/mascots/curious.png'),
        capture.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await network.close();
        await cards.close();
        await db.close();
      });
    });
    return Harness(repo, network, cards, rooms, capture);
  }

  Future<void> capture(WidgetTester tester, Harness h, String name) async {
    final boundary =
        h.captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('../../qa/offline-classes-ui-20261016');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('student retains class card layout and all three class tabs', (
    tester,
  ) async {
    final h = await launch(tester);
    expect(find.textContaining('Preview'), findsNothing);
    expect(find.text('Your classes'), findsOneWidget);
    expect(find.text('Find a class'), findsOneWidget);
    expect(find.text('Join class'), findsOneWidget);
    expect(find.text('Create class'), findsNothing);
    await capture(tester, h, 'student-classes');
    await tester.tap(find.text('Computing'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final tab in ['Stream', 'Files', 'Classwork']) {
      expect(find.text(tab), findsWidgets);
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Stream').last);
    await tester.pumpAndSettle();
    expect(find.text('Nothing posted yet.'), findsOneWidget);
    await capture(tester, h, 'class-stream-tabs');
    await tester.tap(find.byTooltip('Class details'));
    await tester.pumpAndSettle();
    expect(find.text('School Year: 2026-2027'), findsOneWidget);
    expect(find.text('Class code: FILO26'), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.tap(find.text('Copy code'));
    await tester.pumpAndSettle();
    expect(copied, 'FILO26');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  for (final result in [
    'requested',
    'not_found',
    'already_member',
    'already_pending',
    'archived',
  ]) {
    testWidgets('join handles $result and keeps wrong-code sheet open', (
      tester,
    ) async {
      final h = await launch(tester);
      h.repository.joinResult = result;
      await tester.tap(find.text('Join class'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'filo26');
      await tester.tap(find.text('Request to join'));
      await tester.pumpAndSettle();
      expect(h.repository.submittedCode, 'FILO26');
      final expected = switch (result) {
        'requested' =>
          "Request sent. We'll notify you when your instructor approves.",
        'not_found' => 'Class code not found. Check the code and try again.',
        'already_member' => "You're already in this class.",
        'already_pending' => 'Your request is still waiting for approval.',
        _ => 'This class is archived and no longer accepts new students.',
      };
      expect(find.text(expected), findsWidgets);
      expect(
        find.text('Request to join'),
        result == 'not_found' ? findsOneWidget : findsNothing,
      );
      if (result == 'requested') {
        await tester.scrollUntilVisible(
          find.text('Waiting for approval'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<InkWell>(
                find
                    .ancestor(
                      of: find.text('Data Structures'),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .onTap,
          isNull,
        );
        expect(find.byType(NavigationBar), findsNothing);
      }
    });
  }
  testWidgets(
    'offline disables Join and keeps saved class visible after refresh',
    (tester) async {
      final h = await launch(tester, online: false);
      h.repository.failPull = true;
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Join class'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('Connect to the internet to join a class.'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text('Computing'), findsOneWidget);
      expect(
        find.text('Could not refresh your classes. Showing saved content.'),
        findsOneWidget,
      );
      h.network.add(true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Join class'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'instructor creates from existing layout and opens Stream with tabs',
    (tester) async {
      final h = await launch(tester, role: AccountRole.instructor, empty: true);
      expect(find.text('Join class'), findsNothing);
      expect(find.text('Create class'), findsOneWidget);
      await capture(tester, h, 'instructor-classes');
      await tester.tap(find.text('Create class'));
      await tester.pumpAndSettle();
      await capture(tester, h, 'create-class');
      await tester.tap(find.widgetWithText(FilledButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a course.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        ' Computing II ',
      );
      await tester.enterText(find.byType(TextFormField).at(1), ' BSIT-3B ');
      await tester.enterText(find.byType(TextFormField).at(2), '2026-2027');
      final teal = find.widgetWithText(ChoiceChip, 'Teal');
      await tester.ensureVisible(teal);
      await tester.pumpAndSettle();
      await tester.tap(teal);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(h.repository.creates, 1);
      expect(h.repository.createdValues, {
        'course': 'Computing II',
        'section': 'BSIT-3B',
        'school_year': '2026-2027',
        'banner_color': 'teal',
      });
      expect(find.text('BSIT-3B'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      for (final tab in ['Stream', 'Files', 'Classwork']) {
        expect(find.text(tab), findsWidgets);
      }
    },
  );
  testWidgets(
    'creation retry after failed pull does not create a second class',
    (tester) async {
      final h = await launch(tester, role: AccountRole.instructor, empty: true);
      await tester.tap(find.text('Create class'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Computing');
      await tester.enterText(find.byType(TextFormField).at(1), 'BSIT-3B');
      await tester.enterText(find.byType(TextFormField).at(2), '2026-2027');
      h.repository.failPull = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(find.text('Retry loading class'), findsOneWidget);
      h.repository.failPull = false;
      await tester.tap(find.text('Retry loading class'));
      await tester.pumpAndSettle();
      expect(h.repository.creates, 1);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
  testWidgets(
    'lost create response asks to check list instead of repeating insert',
    (tester) async {
      final h = await launch(tester, role: AccountRole.instructor, empty: true);
      h.repository.loseCreateResponse = true;
      await tester.tap(find.text('Create class'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Computing');
      await tester.enterText(find.byType(TextFormField).at(1), 'BSIT-3B');
      await tester.enterText(find.byType(TextFormField).at(2), '2026-2027');
      await tester.tap(find.widgetWithText(FilledButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Back to classes'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Back to classes'));
      await tester.pumpAndSettle();
      expect(h.repository.creates, 1);
      expect(find.text('BSIT-3B'), findsOneWidget);
    },
  );
  testWidgets('offline instructor keeps saved classes and cannot create', (
    tester,
  ) async {
    await launch(
      tester,
      role: AccountRole.instructor,
      online: false,
      scale: 1.3,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create class'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Computing'), findsOneWidget);
    expect(
      find.text('Connect to the internet to create a class.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'revoked open class becomes unavailable and back returns to list',
    (tester) async {
      final h = await launch(tester);
      await tester.tap(find.text('Computing'));
      await tester.pumpAndSettle();
      h.cards.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Class unavailable'), findsOneWidget);
      await tester.tap(find.text('Back to classes'));
      await tester.pumpAndSettle();
      expect(find.text('Your classes'), findsOneWidget);
    },
  );
  testWidgets(
    'existing classes layout fits a small phone at 130 percent text',
    (tester) async {
      await launch(tester, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Join class'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
