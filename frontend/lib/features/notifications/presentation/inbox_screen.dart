import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/notifications/push_events.dart';
import '../../../core/widgets/filo_icons.dart';
import '../../../core/widgets/filo_widgets.dart';
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
        padding: EdgeInsets.all(24),
        child: EmptyState(
          title: 'Notifications are unavailable for this account.',
          pose: 'confused',
          bob: false,
        ),
      );
    } else if (rows == null) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: FiloCircularProgressIndicator(
            semanticsLabel: 'Loading notifications',
          ),
        ),
      );
    } else if (rows.isEmpty) {
      content = EmptyState(title: "You're all caught up.", pose: 'waving');
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
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: current && unread && !_marking ? _markAll : null,
                    child: Text(
                      _marking ? 'Saving…' : 'Mark all as read',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    key: const PageStorageKey('notification-inbox'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                                          top: 16,
                                          bottom: 12,
                                        ),
                                        child: Semantics(
                                          header: true,
                                          child: Text(
                                            inboxDayLabel(
                                              context,
                                              row.createdAt,
                                              _now,
                                            ),
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        TextButton(
          onPressed: retry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Retry'),
        ),
      ],
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
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FiloIcon(
                    inboxTypeIcon(row.type),
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      if (row.body?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(row.body!, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 8),
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
