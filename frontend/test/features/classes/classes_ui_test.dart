import 'package:filo/core/widgets/entry_background.dart';
import 'package:filo/features/home/presentation/home_screen.dart';
import 'package:filo/features/settings/application/theme_settings.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:filo/features/posts/application/post_providers.dart';

import 'package:filo/core/notifications/deadline_providers.dart';
import 'package:drift/native.dart';
import 'package:filo/core/connectivity/connectivity_provider.dart';
import 'package:filo/core/theme/app_theme.dart';
import 'package:filo/data/local/app_database.dart';
import 'package:filo/data/local/database_providers.dart';
import 'package:filo/core/supabase/auth_providers.dart';
import 'package:filo/features/classes/application/class_providers.dart';
import 'package:filo/features/classes/data/class_remote.dart';
import 'package:filo/features/classes/data/class_repository.dart';
import 'package:filo/features/classes/domain/prototype_models.dart';
import 'package:filo/features/classes/presentation/classes_screen.dart';
import 'package:filo/features/classes/presentation/classes_widgets.dart'
    show RedDotBadge, ClassCardSkeleton;
import 'package:filo/features/onboarding/data/profile_repository.dart';
import 'package:filo/features/onboarding/application/notification_permission.dart';
import 'package:filo/core/sync/sync_providers.dart';
import 'package:filo/features/drive_backup/data/drive_backup_service.dart';
import 'package:filo/features/notifications/application/notification_providers.dart';
import 'package:filo/features/notifications/presentation/inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:filo/core/widgets/filo_button.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_repository_test.dart' show FakeRemote;
import '../notifications/notification_settings_test_support.dart';

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

final _classCleanups = <Future<void> Function()>[];

void testClasses(String description, WidgetTesterCallback body) =>
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump();
        while (_classCleanups.isNotEmpty) {
          await _classCleanups.removeLast()();
        }
        await tester.pump();
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
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
    bool homeThemeFailure = false,
    double scale = 1,
    bool? notificationAccess,
    Stream<int>? unread,
    ThemeData? theme,
    Size viewport = const Size(390, 844),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = AppDatabase(NativeDatabase.memory());
    final settings = FakeSettingsRepository();
    final network = StreamController<bool>.broadcast();
    final cards = StreamController<List<ClassRoom>>.broadcast();
    final rooms = <ClassRoom>[if (!empty) cachedRoom];
    final repo = UiRepository(db, (room) {
      rooms.add(room);
      cards.add(List.of(rooms));
    });
    final capture = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (homeThemeFailure)
            themeSettingsRepositoryProvider.overrideWith(
              (ref) async => throw StateError('fixture theme read failure'),
            ),
          authUserIdProvider.overrideWith((ref) => Stream.value('teacher')),
          accountDatabaseProvider.overrideWith((ref) async => db),
          deadlineBridgeProvider.overrideWithValue(const NoDeadlineBridge()),
          classRepositoryProvider.overrideWith((ref) async => repo),
          postSyncProvider.overrideWith((ref, id) async {}),
          streamPostsProvider.overrideWith((ref, id) => Stream.value([])),
          classCardsProvider.overrideWith((ref) async* {
            yield List.of(rooms);
            yield* cards.stream;
          }),
          connectivityProvider.overrideWith((ref) async* {
            yield online;
            yield* network.stream;
          }),
          classSyncLifecycleProvider.overrideWith((ref) {}),
          unreadNotificationCountProvider.overrideWith(
            (ref) => unread ?? Stream.value(0),
          ),
          inboxRepositoryProvider.overrideWith(
            (ref) async => throw StateError('Fixture storage unavailable'),
          ),
          inboxProvider.overrideWith((ref) => Stream.value([])),
          inboxRefreshProvider.overrideWith((ref) async {}),
          notificationSettingsRepositoryProvider.overrideWith(
            (ref) async => settings,
          ),
          notificationPreferencesProvider.overrideWith(
            (ref) => settings.watch(),
          ),
          notificationPreferencesRefreshProvider.overrideWith((ref) async {}),
          if (notificationAccess != null) ...[
            notificationAccessProvider.overrideWith(
              (ref) async => notificationAccess,
            ),
            syncLifecycleProvider.overrideWith((ref) {}),
            driveBackupProvider.overrideWith((ref) async => null),
            pendingClassRequestsProvider.overrideWith(
              (ref) => Stream.value({}),
            ),
          ],
        ],
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme ?? AppTheme.light,
            home: homeThemeFailure
                ? HomeScreen(
                    profile: AccountProfile.fromJson({
                      'id': 'teacher',
                      'role': role.name,
                      'display_name': 'Alex',
                      'email': 'alex@example.invalid',
                    }),
                  )
                : ClassesScreen(
                    profile: AccountProfile.fromJson({
                      'id': 'teacher',
                      'role': role.name,
                      'display_name': 'Alex',
                      'email': 'alex@example.invalid',
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
    _classCleanups.add(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final closing = Future.wait([
        settings.changes.close(),
        network.close(),
        cards.close(),
        db.close(),
      ]);
      await tester.pumpAndSettle();
      await closing;
    });
    return Harness(repo, network, cards, rooms, capture);
  }

  testClasses('theme read failure cannot block return from Create class', (
    tester,
  ) async {
    await launch(
      tester,
      role: AccountRole.instructor,
      empty: true,
      homeThemeFailure: true,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final subscription = container.listen(themeSettingsProvider, (_, _) {});
    try {
      await expectLater(
        container.read(themeSettingsProvider.future),
        throwsStateError,
      );
      await tester.pump();
      expect(find.text('Your classes'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Create class'));
      await tester.tap(find.byTooltip('Create class'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to classes'));
      await tester.pumpAndSettle();
      expect(find.text('Your classes'), findsOneWidget);
      expect(find.text('Could not load your theme setting.'), findsNothing);
      expect(container.read(themeSettingsProvider).hasError, isTrue);
    } finally {
      subscription.close();
    }
  });

  testClasses('school year modal prevents past starts and earlier endings', (
    tester,
  ) async {
    await launch(tester, role: AccountRole.instructor, empty: true);
    await tester.ensureVisible(find.byTooltip('Create class'));
    await tester.tap(find.byTooltip('Create class'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).at(2));
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    final year = DateTime.now().year;
    expect(find.text('Starting year'), findsOneWidget);
    expect(find.text('Ending year'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    final startWheel = tester.widget<CupertinoPicker>(
      find.byType(CupertinoPicker).first,
    );
    expect(find.text('${year - 1}'), findsNothing);
    startWheel.onSelectedItemChanged!(2);
    await tester.pump();
    final endWheel = tester.widget<CupertinoPicker>(
      find.byType(CupertinoPicker).last,
    );
    expect(endWheel.scrollController!.selectedItem, 0);
    await tester.tap(find.text('Use school year'));
    await tester.pumpAndSettle();
    expect(find.text('${year + 2}-${year + 3}'), findsOneWidget);
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('${year + 2}-${year + 3}'), findsOneWidget);
  });

  testClasses('create action floats and preview follows course and section', (
    tester,
  ) async {
    await launch(tester, role: AccountRole.instructor, empty: true);
    await tester.ensureVisible(find.byTooltip('Create class'));
    await tester.tap(find.byTooltip('Create class'));
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(scaffold.floatingActionButton, isNotNull);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Computing preview',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'BSIT-4B');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Class card preview'));
    await tester.pumpAndSettle();
    expect(find.text('Computing preview'), findsOneWidget);
    expect(find.text('BSIT-4B'), findsOneWidget);
    final upload = tester.widget<FiloButton>(
      find.widgetWithText(FiloButton, 'Upload banner image'),
    );
    expect(upload.outlined, isTrue);
    expect(upload.minHeight, greaterThanOrEqualTo(48));
    expect(find.byType(OutlinedButton), findsNWidgets(9));
    expect(
      tester.getTopLeft(find.text('Class card preview')).dy,
      lessThan(tester.getTopLeft(find.text('Banner')).dy),
    );
    final defaultTile = find.widgetWithText(OutlinedButton, 'Default');
    final forestTile = find.widgetWithText(OutlinedButton, 'Forest');
    expect(tester.getSize(defaultTile).width, tester.getSize(forestTile).width);
    expect(tester.getTopLeft(defaultTile).dy, tester.getTopLeft(forestTile).dy);
  });

  for (final empty in [true, false]) {
    testClasses(
      'cancel create preserves known classes empty=$empty without skeleton',
      (tester) async {
        await launch(tester, role: AccountRole.instructor, empty: empty);
        expect(
          tester.widget<EntryBackground>(find.byType(EntryBackground)).breeze,
          isTrue,
        );
        await tester.ensureVisible(find.byTooltip('Create class'));
        await tester.tap(find.byTooltip('Create class'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back to classes'));
        await tester.pump();
        expect(find.byType(ClassCardSkeleton), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byType(ClassCardSkeleton), findsNothing);
        expect(
          find.text(empty ? 'No classes yet.' : 'Computing'),
          findsOneWidget,
        );
      },
    );
  }

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final role in [AccountRole.student, AccountRole.instructor]) {
      for (final empty in [false, true]) {
        testClasses(
          'classes ${role.name} ${theme.brightness.name} empty=$empty at 320dp / 130%',
          (tester) async {
            await launch(
              tester,
              role: role,
              theme: theme,
              empty: empty,
              online: false,
              scale: 1.3,
              viewport: const Size(320, 740),
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(NavigationBar), findsOneWidget);
          },
        );
      }
    }
  }

  testClasses('notification bell follows the local unread count', (
    tester,
  ) async {
    final unread = StreamController<int>.broadcast();
    await launch(tester, notificationAccess: false, unread: unread.stream);
    bool visible() => tester
        .widget<RedDotBadge>(
          find.descendant(
            of: find.byTooltip('Notifications'),
            matching: find.byType(RedDotBadge),
          ),
        )
        .visible;
    expect(visible(), isFalse);
    unread.add(2);
    await tester.pumpAndSettle();
    expect(visible(), isTrue);
    unread.add(0);
    await tester.pumpAndSettle();
    expect(visible(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await unread.close();
  });

  for (final role in AccountRole.values) {
    testClasses('${role.name} bell opens the local inbox', (tester) async {
      await launch(tester, role: role, notificationAccess: false);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(
        find.text('Could not load saved notifications. Try again.'),
        findsOneWidget,
      );
      expect(find.text("You're all caught up."), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ClassesScreen), findsOneWidget);
    });
    testClasses('${role.name} settings hub opens notification access page', (
      tester,
    ) async {
      await launch(tester, role: role, notificationAccess: false, scale: 1.3);
      await tester.tap(find.byTooltip('Your account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Notification settings'));
      await tester.tap(find.text('Notification settings'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Notifications are off for Filo. Turn them on in your phone settings.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    testClasses('${role.name} dark settings hub wraps at 130 percent text', (
      tester,
    ) async {
      await launch(
        tester,
        role: role,
        notificationAccess: false,
        scale: 1.3,
        theme: AppTheme.dark,
      );
      await tester.tap(find.byTooltip('Your account'));
      await tester.pumpAndSettle();
      expect(find.text('Profile and settings'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('alex@example.invalid'), findsOneWidget);
      expect(find.text(role.label), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Delete account'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester
            .widget<ListTile>(
              find.ancestor(
                of: find.text('Delete account'),
                matching: find.byType(ListTile),
              ),
            )
            .enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  Future<void> capture(WidgetTester tester, Harness h, String name) async {
    if (!const bool.fromEnvironment('FILO_CAPTURE_UI')) return;
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

  testClasses('student retains class card layout and all three class tabs', (
    tester,
  ) async {
    final h = await launch(tester);
    expect(find.textContaining('Preview'), findsNothing);
    expect(find.text('Your classes'), findsOneWidget);
    expect(find.text('Find a class'), findsWidgets);
    expect(find.byTooltip('Join class'), findsOneWidget);
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
    expect(find.text('No posts yet'), findsOneWidget);
    await capture(tester, h, 'class-stream-tabs');
    await tester.tap(find.byTooltip('Class menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class details'));
    await tester.pumpAndSettle();
    expect(find.text('School year: 2026-2027'), findsOneWidget);
    expect(find.text('Class code: FILO26'), findsNothing);
    expect(find.text('Copy code'), findsNothing);
  });

  for (final result in [
    'requested',
    'not_found',
    'already_member',
    'already_pending',
    'archived',
  ]) {
    testClasses('join handles $result and keeps wrong-code sheet open', (
      tester,
    ) async {
      final h = await launch(tester);
      h.repository.joinResult = result;
      await tester.tap(find.byTooltip('Join class'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'filo26');
      await tester.tap(find.text('Request to join'));
      await tester.pumpAndSettle();
      expect(h.repository.submittedCode, 'FILO26');
      final expected = switch (result) {
        'requested' => "Request sent. Your instructor needs to approve it before you can open the class.",
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
        expect(find.byType(NavigationBar), findsOneWidget);
      }
    });
  }
  testClasses(
    'offline disables Join and keeps saved class visible after refresh',
    (tester) async {
      final h = await launch(tester, online: false);
      h.repository.failPull = true;
      expect(
        tester
            .widget<FiloButton>(
              find.ancestor(
                of: find.byTooltip('Join class'),
                matching: find.byType(FiloButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text("You're offline. Showing saved content."),
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
            .widget<FiloButton>(
              find.ancestor(
                of: find.byTooltip('Join class'),
                matching: find.byType(FiloButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  for (final failCopy in [false, true]) {
    testClasses(
      'class code copy keeps options open while showing ${failCopy ? 'failure' : 'success'}',
      (tester) async {
        var copies = 0;
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copies++;
                if (failCopy) {
                  throw PlatformException(code: 'clipboard-unavailable');
                }
                copied = (call.arguments as Map)['text'] as String;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await launch(tester, role: AccountRole.instructor);
        await tester.tap(find.text('Computing'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Class menu'));
        await tester.pumpAndSettle();
        expect(find.text('Class options'), findsOneWidget);
        await tester.ensureVisible(find.text('Copy code'));
        await tester.tap(find.text('Copy code'));
        await tester.pumpAndSettle();
        expect(copies, 1);
        expect(copied, failCopy ? isNull : 'FILO26');
        expect(find.text('Class options'), findsOneWidget);
        expect(
          find.text(
            failCopy
                ? 'Could not copy the class code. Try again.'
                : 'Class code copied.',
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        expect(find.text('Class options'), findsOneWidget);
        expect(find.text('Copy code'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Class options'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testClasses(
    'instructor creates from existing layout and opens Stream with tabs',
    (tester) async {
      final h = await launch(tester, role: AccountRole.instructor, empty: true);
      expect(find.text('Join class'), findsNothing);
      expect(find.byTooltip('Create class'), findsOneWidget);
      await capture(tester, h, 'instructor-classes');
      await tester.tap(find.byTooltip('Create class'));
      await tester.pumpAndSettle();
      await capture(tester, h, 'create-class');
      await tester.ensureVisible(
        find.widgetWithText(FiloButton, 'Create class'),
      );
      await tester.tap(find.widgetWithText(FiloButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a course.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        ' Computing II ',
      );
      await tester.enterText(find.byType(TextFormField).at(1), ' BSIT-3B ');
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      await tester.tap(find.text('Use school year'));
      await tester.pumpAndSettle();
      final teal = find.widgetWithText(OutlinedButton, 'Teal');
      await tester.ensureVisible(teal);
      await tester.pumpAndSettle();
      await tester.tap(teal);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FiloButton, 'Create class'),
      );
      await tester.tap(find.widgetWithText(FiloButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(h.repository.creates, 1);
      expect(h.repository.createdValues, {
        'course': 'Computing II',
        'section': 'BSIT-3B',
        'school_year': '${DateTime.now().year}-${DateTime.now().year + 1}',
        'banner_color': 'teal',
      });
      expect(find.text('BSIT-3B'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.byType(EntryBackground), findsOneWidget);
      for (final tab in ['Stream', 'Files', 'Classwork']) {
        expect(find.text(tab), findsWidgets);
      }
    },
  );
  testClasses(
    'creation retry after failed pull does not create a second class',
    (tester) async {
      final h = await launch(tester, role: AccountRole.instructor, empty: true);
      await tester.tap(find.byTooltip('Create class'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Computing');
      await tester.enterText(find.byType(TextFormField).at(1), 'BSIT-3B');
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      await tester.tap(find.text('Use school year'));
      await tester.pumpAndSettle();
      h.repository.failPull = true;
      await tester.ensureVisible(
        find.widgetWithText(FiloButton, 'Create class'),
      );
      await tester.tap(find.widgetWithText(FiloButton, 'Create class'));
      await tester.pumpAndSettle();
      expect(find.text('Retry loading class'), findsOneWidget);
      h.repository.failPull = false;
      await tester.tap(find.text('Retry loading class'));
      await tester.pumpAndSettle();
      expect(h.repository.creates, 1);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
  testClasses(
    'lost create response asks to check list instead of repeating insert',
    (tester) async {
      final h = await launch(tester, role: AccountRole.instructor, empty: true);
      h.repository.loseCreateResponse = true;
      await tester.tap(find.byTooltip('Create class'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Computing');
      await tester.enterText(find.byType(TextFormField).at(1), 'BSIT-3B');
      await tester.ensureVisible(find.byType(TextFormField).at(2));
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      await tester.tap(find.text('Use school year'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FiloButton, 'Create class'),
      );
      await tester.tap(find.widgetWithText(FiloButton, 'Create class'));
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
  testClasses('offline instructor keeps saved classes and cannot create', (
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
    expect(find.text("You're offline. Showing saved content."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testClasses(
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
  testClasses(
    'existing classes layout fits a small phone at 130 percent text',
    (tester) async {
      await launch(tester, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Join class'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
