import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/notifications/push_events.dart';
import '../../../core/widgets/filo_icons.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
import '../../../data/local/app_database.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../application/notification_providers.dart';

DateTime inboxDay(DateTime stamp) {
  final local = stamp.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String inboxDayLabel(BuildContext context, DateTime stamp, DateTime now) {
  final day = inboxDay(stamp), today = inboxDay(now);
  if (day == today) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1))
    return 'Yesterday';
  return MaterialLocalizations.of(context).formatFullDate(day);
}

IconData inboxTypeIcon(String type) => switch (type) {
  'announcement' => FiloIcons.announcement,
  'material' => FiloIcons.file,
  'assignment' => FiloIcons.checklist,
  'grade_returned' || 'results_released' => FiloIcons.grades,
  'quiz_published' || 'second_chance' => FiloIcons.assessment,
  'join_request' => FiloIcons.people,
  'join_approved' => FiloIcons.checkCircle,
  'join_declined' => FiloIcons.people,
  'link_report' => FiloIcons.link,
  'class_archived' ||
  'class_unarchived' ||
  'removed_from_class' => FiloIcons.book,
  _ => FiloIcons.notifications,
};

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;
  bool _marking = false, _opening = false;
  String? _writeError;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _updateDay);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      _updateDay,
    );
  }

  void _updateDay() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _scheduleMidnight();
  }

  Future<void> _refresh() async {
    try {
      await ref.refresh(inboxRefreshProvider.future);
    } catch (_) {
      // The provider displays the refresh error without discarding saved rows.
    }
  }

  Future<void> _markAll() async {
    if (_marking) return;
    setState(() {
      _marking = true;
      _writeError = null;
    });
    try {
      final repo = await ref.read(inboxRepositoryProvider.future);
      if (!mounted || repo.userId != widget.userId || !repo.isCurrent()) return;
      await repo.markAllRead();
    } catch (_) {
      if (mounted)
        setState(() => _writeError = 'Could not save read status. Try again.');
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _open(String id) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await ref.read(pushEventsProvider).openInbox(id, widget.userId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open this notification. Try again.'),
            action: SnackBarAction(label: 'Retry', onPressed: () => _open(id)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(inboxRepositoryProvider);
    final inbox = ref.watch(inboxProvider);
    final refresh = ref.watch(inboxRefreshProvider);
    final offline = ref.watch(connectivityProvider).asData?.value == false;
    final repo = repository.asData?.value;
    final current =
        repo != null && repo.userId == widget.userId && repo.isCurrent();
    final rows = current ? inbox.asData?.value : null;
    final unread = rows?.any((n) => n.readAt == null) ?? false;
    final theme = Theme.of(context);
    Widget content;
    if (repository.hasError || (current && inbox.hasError)) {
      content = EmptyState(
        title: 'Could not load saved notifications. Try again.',
        pose: 'confused',
        bob: false,
        action: TextButton(
          child: const Text('Retry'),
          onPressed: () {
            ref.invalidate(inboxRepositoryProvider);
            ref.invalidate(inboxProvider);
          },
        ),
      );
    } else if (repo != null && !current) {
      content = const Padding(
        padding: EdgeInsets.all(FiloSpacing.screen),
        child: EmptyState(
          title: 'Notifications are unavailable for this account.',
          pose: 'confused',
          bob: false,
        ),
      );
    } else if (rows == null) {
      content = const Padding(
        padding: EdgeInsets.all(FiloSpacing.s32),
        child: Center(
          child: FiloCircularProgressIndicator(
            semanticsLabel: 'Loading notifications',
          ),
        ),
      );
    } else if (rows.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s32),
        child: Column(
          children: [
            ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: ColorFiltered(
                    // Remove the generated low-opacity halo; keep the solid illustration.
                    colorFilter: const ColorFilter.matrix([
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                      0,
                      0,
                      0,
                      0,
                      12,
                      -2700,
                    ]),
                    child: Image.asset(
                      'assets/illustrations/notifications-empty.png',
                      fit: BoxFit.contain,
                      cacheWidth: (360 * MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: FiloSpacing.s16),
            Text(
              "You're all caught up.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }
    return FiloFirstListLoad(
      id: 'inbox',
      hasItems: rows?.isNotEmpty ?? false,
      ready: current && inbox.hasValue && !inbox.isLoading && !inbox.hasError,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Notifications'),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: EntryBackground(verification: true, breeze: true),
            ),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        key: const PageStorageKey('notification-inbox'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: FiloSpacing.screen,
                            ),
                            sliver: SliverList.list(
                              children: [
                                if (offline) const OfflineBanner(),
                                if (refresh.isLoading && !offline)
                                  const FiloLinearProgressIndicator(
                                    semanticsLabel: 'Refreshing notifications',
                                  ),
                                if (refresh.hasError && !offline)
                                  _notice(
                                    'Could not refresh notifications. Showing saved content.',
                                    _refresh,
                                  ),
                                if (_writeError != null)
                                  _notice(_writeError!, _markAll),
                                if (rows == null || rows.isEmpty) content,
                              ],
                            ),
                          ),
                          if (rows != null && rows.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                FiloSpacing.screen,
                                FiloSpacing.s8,
                                FiloSpacing.screen,
                                FiloSpacing.screen,
                              ),
                              sliver: SliverList.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  final header =
                                      index == 0 ||
                                      inboxDay(rows[index - 1].createdAt) !=
                                          inboxDay(row.createdAt);
                                  return FiloListItem(
                                    index: index,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (header)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: FiloSpacing.s16,
                                              bottom: FiloSpacing.s12,
                                            ),
                                            child: Semantics(
                                              header: true,
                                              child: Text(
                                                inboxDayLabel(
                                                  context,
                                                  row.createdAt,
                                                  _now,
                                                ),
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: FiloSpacing.s12,
                                          ),
                                          child: _InboxRow(
                                            row: row,
                                            onTap: _opening
                                                ? null
                                                : () => _open(row.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FiloSpacing.screen,
                      FiloSpacing.s12,
                      FiloSpacing.screen,
                      FiloSpacing.s16,
                    ),
                    child: FiloButton(
                      label: _marking ? 'Saving\u2026' : 'Mark all as read',
                      labelVariants: const ['Mark all as read', 'Saving\u2026'],
                      outlined: true,
                      minHeight: 56,
                      busy: _marking,
                      onPressed: current && unread && !_marking
                          ? _markAll
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: FiloSpacing.s12),
    child: FiloPanel(
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            TextButton(
              onPressed: retry,
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  FiloControlSize.compact,
                  FiloControlSize.compact,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.row, required this.onTap});
  final CacheNotification row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final unread = row.readAt == null;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(row.createdAt.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      label:
          '${unread ? 'Unread' : 'Read'}. ${row.title}. ${row.body ?? ''}. $time',
      excludeSemantics: true,
      child: Material(
        color: unread
            ? colors.primaryContainer.withValues(alpha: 0.35)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FiloRadii.large),
          side: BorderSide(
            color: unread
                ? colors.primary.withValues(alpha: .4)
                : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(FiloSpacing.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(FiloRadii.small),
                  ),
                  child: FiloIcon(
                    inboxTypeIcon(row.type),
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: FiloSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: unread
                              ? FiloTypography.emphasis
                              : FiloTypography.medium,
                        ),
                      ),
                      if (row.body?.isNotEmpty == true) ...[
                        const SizedBox(height: FiloSpacing.s4),
                        Text(
                          row.body!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: FiloSpacing.s8),
                      Text(
                        time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
