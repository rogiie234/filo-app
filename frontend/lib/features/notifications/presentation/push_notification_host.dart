import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/notifications/push_events.dart';
import '../../../core/supabase/session_gate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database_providers.dart';
import '../../classes/presentation/class_screen.dart';
import '../../classes/presentation/class_students_screen.dart';
import '../../exams/application/exam_providers.dart';
import '../../exams/presentation/student_exam_screen.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../posts/presentation/post_detail_screen.dart';
import '../../results/presentation/student_results_screen.dart';
import '../../study/presentation/study_home_screen.dart';
import '../../study/presentation/study_flashcard_study_screen.dart';
import '../../submissions/presentation/assignment_detail_screen.dart';
import '../application/notification_providers.dart';
import '../data/inbox_repository.dart';
import '../data/notification_destination_repository.dart';

class PushNotificationHost extends ConsumerStatefulWidget {
  const PushNotificationHost({
    super.key,
    required this.userId,
    required this.child,
  });
  final String userId;
  final Widget child;
  @override
  ConsumerState<PushNotificationHost> createState() =>
      _PushNotificationHostState();
}

class _PushNotificationHostState extends ConsumerState<PushNotificationHost> {
  final _navigator = GlobalKey<NavigatorState>();
  final _banners = <({PushEvent event, String title, String? body})>[];
  late final PushEvents _events;
  late final AppLifecycleListener _lifecycle;
  late final _PushObserver _observer;
  AccountProfile? _profile;
  Timer? _timer;
  PushEvent? _timedEvent;
  PushEvent? _activeOpen;
  bool _scheduled = false, _working = false, _needsRefresh = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _events = ref.read(pushEventsProvider)..addListener(_schedule);
    _observer = _PushObserver(_schedule);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _schedule();
      },
      onInactive: () {
        _foreground = false;
        _timer?.cancel();
        _timer = null;
        _schedule();
      },
    );
  }

  bool get _ready =>
      mounted &&
      _profile?.id == widget.userId &&
      ref.read(verifiedUserIdProvider).asData?.value == widget.userId &&
      ref.read(accountDatabaseProvider).asData?.value != null &&
      _navigator.currentState?.overlay != null;

  bool get _protected =>
      _profile?.role == AccountRole.student &&
      (ref.read(examNavigationProvider).open ||
          ref.read(studentExamRepositoryProvider).asData?.value?.engaged ==
              true);

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      setState(() {});
      unawaited(_pump());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _message(String text, {VoidCallback? retry}) {
    if (!_ready || !_foreground) return;
    ScaffoldMessenger.of(_navigator.currentState!.overlay!.context)
        .showSnackBar(
          SnackBar(
            content: Text(text),
            action: retry == null
                ? null
                : SnackBarAction(label: 'Retry', onPressed: retry),
          ),
        );
  }

  void _retainForCurrentAccount(PushEvent event) {
    if (mounted &&
        ref.read(loginSessionProvider).asData?.value?.user.id ==
            widget.userId) {
      _events.retry(event);
    } else {
      _events.finishOpen(event);
    }
  }

  Future<void> _pump() async {
    if (_working || !_ready || !_foreground) return;
    _working = true;
    try {
      final repository = await ref.read(
        notificationDestinationRepositoryProvider.future,
      );
      if (!_ready || !_foreground || !repository.isCurrent()) return;
      if (_needsRefresh &&
          ref.read(connectivityProvider).asData?.value == true) {
        try {
          await repository.sync.refreshNotifications();
          if (!repository.isCurrent()) return;
          _needsRefresh = false;
        } catch (_) {
          /* Keep the durable server inbox for the next reconnect. */
        }
      }
      while (_ready && _foreground && repository.isCurrent()) {
        final event = _events.take(widget.userId, allowOpen: !_protected);
        if (event == null) break;
        if (event.open) {
          _activeOpen = event;
          try {
            final destination = event.alarmId != null
                ? await repository.resolveStudyAlarm(event.alarmId!)
                : event.assignmentId != null
                ? await repository.resolveAssignment(event.assignmentId!)
                : await repository.resolve(
                    event.id,
                    instructor: _profile!.role == AccountRole.instructor,
                  );
            if (!_ready || !repository.isCurrent()) {
              _retainForCurrentAccount(event);
              return;
            }
            if (!_foreground || _protected) {
              _events.retry(event);
              return;
            }
            _open(destination);
            try {
              if (event.assignmentId == null && event.alarmId == null)
                await InboxRepository(
                  repository.db,
                  widget.userId,
                  repository.isCurrent,
                ).markRead(event.id!);
            } catch (_) {
              if (_ready && repository.isCurrent()) {
                _message(
                  'Could not save read status. Try again.',
                  retry: () => unawaited(_retryRead(repository, event.id!)),
                );
              }
            }
          } on NotificationUnavailable {
            if (!repository.isCurrent()) {
              _retainForCurrentAccount(event);
              return;
            }
            _message('This item is no longer available.');
          } catch (error) {
            if (!repository.isCurrent()) {
              _retainForCurrentAccount(event);
              return;
            }
            if (_ready && repository.isCurrent()) {
              _needsRefresh = true;
              _message(
                error is NotificationNeedsConnection
                    ? 'Connect to the internet to open this notification.'
                    : 'Could not open this notification. Try again.',
                retry: () => _events.retry(event),
              );
            }
          }
          _events.finishOpen(event);
          _activeOpen = null;
        } else {
          try {
            final n = await repository.notice(event.id);
            if (!_ready || !repository.isCurrent()) {
              _retainForCurrentAccount(event);
              return;
            }
            setState(
              () => _banners.add((event: event, title: n.title, body: n.body)),
            );
          } on NotificationUnavailable {
            // A notification for a different account must not expose its payload.
          } catch (_) {
            if (!_ready || !repository.isCurrent()) {
              _retainForCurrentAccount(event);
              return;
            }
            _needsRefresh = true;
            setState(
              () => _banners.add((
                event: event,
                title: 'New notification. Connect to view it.',
                body: null,
              )),
            );
          }
        }
      }
    } catch (_) {
      // Readiness can change while the account database/provider is opening.
      _needsRefresh = true;
      _events.failInboxOpen();
    } finally {
      _working = false;
    }
  }

  Future<void> _retryRead(
    NotificationDestinationRepository repository,
    String id,
  ) async {
    try {
      if (!repository.isCurrent()) return;
      await InboxRepository(
        repository.db,
        widget.userId,
        repository.isCurrent,
      ).markRead(id);
    } catch (_) {
      if (repository.isCurrent())
        _message(
          'Could not save read status. Try again.',
          retry: () => unawaited(_retryRead(repository, id)),
        );
    }
  }

  void _open(NotificationDestination destination) {
    final Widget page;
    switch (destination.screen) {
      case NotificationScreen.study:
        page = Scaffold(
          appBar: AppBar(title: const Text('AI Study')),
          body: const SafeArea(child: StudyHomeScreen()),
        );
      case NotificationScreen.deck:
        page = StudyFlashcardStudyScreen(
          notebookId: destination.notebookId!,
          deckId: destination.targetId,
        );
      case NotificationScreen.post:
        page = PostDetailScreen(
          classId: destination.classId,
          postId: destination.targetId,
        );
      case NotificationScreen.assignment:
        page = AssignmentDetailScreen(
          classId: destination.classId,
          postId: destination.targetId,
        );
      case NotificationScreen.quiz:
        unawaited(
          openStudentExam(
            _navigator.currentState!.overlay!.context,
            ref,
            StudentExamHandoff(quizId: destination.targetId),
          ),
        );
        return;
      case NotificationScreen.result:
        page = StudentResultsScreen(quizId: destination.targetId);
      case NotificationScreen.classroom:
        page = ClassScreen(classId: destination.classId, profile: _profile);
      case NotificationScreen.requests:
        page = ClassStudentsScreen(
          classId: destination.classId,
          focusRequests: true,
        );
    }
    // Push above the current page; never pop away an unsaved form.
    unawaited(
      _navigator.currentState!.push(
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name:
                'notification:${destination.screen.name}:${destination.targetId}',
          ),
          builder: (_) => page,
        ),
      ),
    );
  }

  void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _timedEvent = null;
    if (mounted && _banners.isNotEmpty) setState(() => _banners.removeAt(0));
  }

  @override
  void dispose() {
    if (_activeOpen != null) _events.finishOpen(_activeOpen!);
    _events.removeListener(_schedule);
    _lifecycle.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(verifiedUserIdProvider, (_, _) => _schedule());
    ref.listen(accountDatabaseProvider, (_, _) => _schedule());
    ref.listen(connectivityProvider, (_, next) {
      if (next.asData?.value == true) _schedule();
    });
    if (_profile != null) {
      ref.listen(
        notificationDestinationRepositoryProvider,
        (_, _) => _schedule(),
      );
      if (_profile!.role == AccountRole.student)
        ref.listen(examUpdatesProvider, (_, _) => _schedule());
    }
    final showBanner =
        _ready && _foreground && !_protected && _banners.isNotEmpty;
    if (!showBanner || MediaQuery.accessibleNavigationOf(context)) {
      _timer?.cancel();
      _timer = null;
      _timedEvent = null;
    } else if (_timer == null || _timedEvent != _banners.first.event) {
      _timer?.cancel();
      _timedEvent = _banners.first.event;
      _timer = Timer(const Duration(seconds: 5), _dismiss);
    }
    return NotificationListener<NotificationHomeReady>(
      onNotification: (notification) {
        if (notification.profile.id == widget.userId) {
          _profile = notification.profile;
          _schedule();
        }
        return true;
      },
      child: Stack(
        children: [
          Navigator(
            key: _navigator,
            observers: [_observer],
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => widget.child),
          ),
          if (showBanner)
            Positioned(
              top: 8,
              left: 24,
              right: 24,
              child: SafeArea(
                bottom: false,
                child: PushForegroundBanner(
                  title: _banners.first.title,
                  body: _banners.first.body,
                  onDismiss: _dismiss,
                  onOpen: () {
                    final event = _banners.first.event;
                    _dismiss();
                    _events.retry(
                      PushEvent(event.id, open: true, accountId: widget.userId),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PushForegroundBanner extends StatelessWidget {
  const PushForegroundBanner({
    super.key,
    required this.title,
    this.body,
    required this.onOpen,
    required this.onDismiss,
  });
  final String title;
  final String? body;
  final VoidCallback onOpen, onDismiss;
  @override
  Widget build(BuildContext context) => Material(
    color: FiloColors.mint,
    elevation: 4,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FiloColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (body != null && body!.isNotEmpty)
              Text(
                body!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FiloColors.ink),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: TextButton(
                    onPressed: onOpen,
                    child: const Text('Open'),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: TextButton(
                    onPressed: onDismiss,
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PushObserver extends NavigatorObserver {
  _PushObserver(this.changed);
  final VoidCallback changed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => changed();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      changed();
}
