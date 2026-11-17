import '../../../core/widgets/entry_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Variable;

import '../../../core/notifications/deadline_providers.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../study/presentation/study_widgets.dart';
import '../../onboarding/application/notification_permission.dart';
import '../application/notification_providers.dart';
import '../data/alarm_repository.dart';
import 'phone_limits_guide_screen.dart';

final studyAlarmRepositoryProvider =
    FutureProvider.autoDispose<AlarmRepository>((ref) async {
      final base = await ref.watch(alarmRepositoryProvider.future);
      final profile = await base.db.readProfile(base.userId);
      if (!ref.mounted ||
          !base.isCurrent() ||
          profile?.role != 'student' ||
          profile?.deletedAt != null) {
        throw StateError('Student account unavailable');
      }
      return AlarmRepository(
        base.db,
        () => ref.mounted && base.isCurrent(),
        userId: base.userId,
        bridge: ref.watch(deadlineBridgeProvider),
      );
    });
final studyAlarmsProvider = StreamProvider.autoDispose<List<StudyAlarm>>((
  ref,
) async* {
  final repo = await ref.watch(studyAlarmRepositoryProvider.future);
  yield* repo.watchAlarms();
});

String studyRepeatLabel(int days, MaterialLocalizations locale) => days == 0
    ? 'Once'
    : [
        for (var day = 1; day <= 7; day++)
          if ((days & (1 << (day - 1))) != 0) locale.narrowWeekdays[day % 7],
      ].join(' · ');

class StudyAlarmsScreen extends ConsumerStatefulWidget {
  const StudyAlarmsScreen({super.key});
  @override
  ConsumerState<StudyAlarmsScreen> createState() => _StudyAlarmsState();
}

class _StudyAlarmsState extends ConsumerState<StudyAlarmsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  Map<String, dynamic>? _status;
  String? _error;
  AppDatabase? _boundDb;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      await ref.read(deadlineSessionProvider.future);
      await repo.reconcileStudy();
      final status = await repo.bridge.status();
      if (mounted && repo.isCurrent()) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = 'Could not check study alarm scheduling. Retry.';
        });
      }
    }
  }

  Future<void> _toggle(StudyAlarm alarm, bool on) async {
    setState(() => _busy = true);
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      if (repo.db != _boundDb || !repo.isCurrent()) return;
      await repo.toggleStudy(alarm, on);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = null;
          _error = 'Could not finish updating this alarm. Saved changes may need scheduling. Retry.';
        });
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _edit([StudyAlarm? alarm]) async {
    if (alarm == null) {
      await showFiloBottomSheet<void>(
        context: context,
        title: 'New study alarm',
        builder: (_) => const StudyAlarmEditor(asDrawer: true),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => StudyAlarmEditor(alarm: alarm)),
      );
    }
    if (mounted) await _refresh();
  }

  Future<void> _delete(StudyAlarm alarm) async {
    if (_busy) return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Delete alarm?',
      message: 'This study alarm will stop.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      confirmDestructive: true,
      icon: FiloIcons.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      if (repo.db != _boundDb || !repo.isCurrent()) return;
      await repo.deleteStudy(alarm.id);
      await _refresh();
    } on StudySchedulingFailure {
      if (mounted) {
        setState(() {
          _status = null;
          _error = 'Alarm deleted, but scheduling cleanup failed. Tap Retry.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not finish deleting the alarm. Retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(studyAlarmRepositoryProvider);
    final alarms = ref.watch(studyAlarmsProvider);
    if (!repo.isLoading && !repo.hasError && repo.hasValue) {
      _boundDb ??= repo.requireValue.db;
      if (_boundDb != repo.requireValue.db) {
        return EntryBackground(
          verification: true,
          breeze: true,
          variation: 1,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Study alarms'),
            ),
            body: const Center(
              child: Text('Account changed. Reopen study alarms.'),
            ),
          ),
        );
      }
    }
    final locale = MaterialLocalizations.of(context);
    final showAdd =
        !repo.isLoading &&
        !repo.hasError &&
        repo.hasValue &&
        !alarms.isLoading &&
        !alarms.hasError &&
        alarms.hasValue &&
        alarms.requireValue.isNotEmpty;
    return EntryBackground(
      verification: true,
      breeze: true,
      variation: 1,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: showAdd
            ? Padding(
                padding: const EdgeInsets.only(
                  right: 8,
                  bottom: FiloSpacing.s16,
                ),
                child: SizedBox(
                  width: 72,
                  child: FiloButton(
                    label: 'New alarm',
                    icon: FiloIcons.add,
                    iconOnly: true,
                    minHeight: 72,
                    onPressed: _busy ? null : () => _edit(),
                  ),
                ),
              )
            : null,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Study alarms'),
          actions: [
            IconButton(
              tooltip: 'Alarm setup',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PhoneLimitsGuideScreen(),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              FiloSpacing.screen,
              FiloSpacing.screen,
              FiloSpacing.screen,
              showAdd ? 136 : FiloSpacing.screen,
            ),
            children: [
              const StudyOfflineBanner(),
              StudyCollectionHeader(
                title: 'A little time to study.',
                body: 'Choose a time that works for you. Your reminders stay on this device.',
                icon: Icons.alarm_outlined,
                summary:
                    !alarms.isLoading && !alarms.hasError && alarms.hasValue
                    ? '${alarms.requireValue.where((a) => a.enabled).length} on / ${alarms.requireValue.length} saved'
                    : null,
              ),
              if (_error != null) ...[
                Semantics(liveRegion: true, child: Text(_error!)),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
              if (_status != null)
                Text(
                  _status!['studyError'] == true
                      ? 'Saved, but alarm scheduling failed. Retry.'
                      : _status!['studyEnabled'] == false
                      ? 'Notifications are off for Filo. Turn them on in your phone settings.'
                      : _status!['exact'] == false
                      ? 'Approximate alarms. Delivery may be delayed.'
                      : 'Study alarms ready.',
                ),
              if (_status?['studyError'] == true)
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry scheduling'),
                ),
              if (_status?['studyEnabled'] == false)
                TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(notificationPermissionProvider)
                          .openSettings();
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error = 'Open your phone settings and enable notifications for Filo.',
                        );
                      }
                    }
                  },
                  child: const Text('Open settings'),
                ),
              const SizedBox(height: FiloSpacing.s16),
              if (alarms.isLoading || repo.isLoading)
                const Center(
                  child: FiloCircularProgressIndicator(
                    semanticsLabel: 'Loading study alarms',
                  ),
                )
              else if (alarms.hasError || repo.hasError) ...[
                const EmptyState(
                  title: 'Study alarms unavailable',
                  body:
                      'Check your account and retry to load your saved alarms.',
                  pose: 'confused',
                ),
                TextButton(
                  onPressed: () {
                    ref.invalidate(studyAlarmRepositoryProvider);
                    ref.invalidate(studyAlarmsProvider);
                    _refresh();
                  },
                  child: const Text('Retry'),
                ),
              ] else if (alarms.requireValue.isEmpty)
                EmptyState(
                  title: 'No study alarms yet',
                  body:
                      'Add an alarm to choose when you want a study reminder.',
                  pose: 'clock',
                  primaryAction: EmptyStateAction(
                    label: 'New alarm',
                    onPressed:
                        repo.hasValue &&
                            !repo.hasError &&
                            repo.value != null &&
                            !_busy
                        ? () => _edit()
                        : null,
                  ),
                )
              else
                for (final alarm in alarms.requireValue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FiloSpacing.s12),
                    child: FiloPanel(
                      color: alarm.enabled
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _busy ? null : () => _edit(alarm),
                                  borderRadius: BorderRadius.circular(
                                    FiloRadii.small,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: FiloSpacing.s12,
                                    ),
                                    child: Text(
                                      TimeOfDay(
                                        hour: alarm.minuteOfDay ~/ 60,
                                        minute: alarm.minuteOfDay % 60,
                                      ).format(context),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                    ),
                                  ),
                                ),
                              ),
                              Semantics(
                                label:
                                    '${alarm.subject}, ${alarm.enabled ? 'on' : 'off'}',
                                child: FiloSwitch(
                                  value: alarm.enabled,
                                  onChanged: _busy
                                      ? null
                                      : (v) => _toggle(alarm, v),
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Options for ${alarm.subject}',
                                enabled: !_busy,
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete alarm'),
                                  ),
                                ],
                                onSelected: (_) => _delete(alarm),
                              ),
                            ],
                          ),
                          const Divider(),
                          InkWell(
                            onTap: _busy ? null : () => _edit(alarm),
                            borderRadius: BorderRadius.circular(
                              FiloRadii.small,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: FiloSpacing.s12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alarm.subject,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: FiloSpacing.s8),
                                  Wrap(
                                    spacing: FiloSpacing.s12,
                                    runSpacing: FiloSpacing.s8,
                                    children: [
                                      Text(
                                        studyRepeatLabel(
                                          alarm.repeatDays,
                                          locale,
                                        ),
                                      ),
                                      Text(
                                        alarm.enabled ? 'On' : 'Off',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge,
                                      ),
                                      const Icon(Icons.edit_outlined, size: 20),
                                    ],
                                  ),
                                ],
                              ),
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
}

class StudyAlarmEditor extends ConsumerStatefulWidget {
  const StudyAlarmEditor({super.key, this.alarm, this.asDrawer = false});
  final StudyAlarm? alarm;
  final bool asDrawer;
  @override
  ConsumerState<StudyAlarmEditor> createState() => _StudyAlarmEditorState();
}

class _StudyAlarmEditorState extends ConsumerState<StudyAlarmEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _subject;
  late final String _id;
  late TimeOfDay _time;
  late int _days;
  String? _link;
  bool _busy = false;
  String? _error;
  List<DropdownMenuItem<String>> _links = [];
  AppDatabase? _boundDb;
  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _id = a?.id ?? const Uuid().v4();
    _subject = TextEditingController(text: a?.subject ?? '');
    _time = a == null
        ? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)))
        : TimeOfDay(hour: a.minuteOfDay ~/ 60, minute: a.minuteOfDay % 60);
    _days = a?.repeatDays ?? 0;
    _link = a?.linkedClassId != null
        ? 'class:${a!.linkedClassId}'
        : a?.linkedDeckId != null
        ? 'deck:${a!.linkedDeckId}'
        : null;
    _loadLinks();
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _loadLinks() async {
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      final classes = await repo.db
          .customSelect(
            "SELECT c.id,c.course,c.section FROM cache_classes c JOIN cache_class_members m ON m.class_id=c.id WHERE m.student_id=? AND m.status='active' AND c.deleted_at IS NULL",
            variables: [Variable(repo.userId)],
          )
          .get();
      final decks = await repo.db.select(repo.db.flashcardDecks).get();
      if (!mounted || !repo.isCurrent()) return;
      setState(
        () => _links = [
          for (final c in classes)
            DropdownMenuItem(
              value: 'class:${c.read<String>('id')}',
              child: Text(
                'Class: ${c.read<String>('course')} · ${c.read<String>('section')}',
                softWrap: true,
              ),
            ),
          for (final d in decks)
            DropdownMenuItem(
              value: 'deck:${d.id}',
              child: Text('Deck: ${d.title}', softWrap: true),
            ),
        ],
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load optional links. Retry.');
      }
    }
  }

  Future<void> _save() async {
    if (!validateFiloForm(_form)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      // Activation is separate from the local write, so a native failure cannot lose the alarm.
      if (repo.db != _boundDb || !repo.isCurrent()) return;
      try {
        await ref.read(deadlineSessionProvider.future);
      } catch (_) {}
      var schedulingFailed = false;
      try {
        await repo.saveStudy(
          id: _id,
          subject: _subject.text,
          minute: _time.hour * 60 + _time.minute,
          days: _days,
          enabled: widget.alarm?.enabled ?? true,
          classId: _link?.startsWith('class:') == true
              ? _link!.substring(6)
              : null,
          deckId: _link?.startsWith('deck:') == true
              ? _link!.substring(5)
              : null,
        );
      } on StudySchedulingFailure {
        schedulingFailed = true;
      }
      if (!mounted || !repo.isCurrent()) return;
      var showGuide = true;
      try {
        showGuide = await repo.needsPhoneGuide();
      } catch (_) {
        /* A guide-marker failure must not misreport a saved alarm. */
      }
      if (showGuide) {
        if (!mounted || !repo.isCurrent()) return;
        FocusScope.of(context).unfocus();
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PhoneLimitsGuideScreen(expectedUserId: repo.userId),
          ),
        );
      }
      if (!mounted || !repo.isCurrent()) return;
      if (schedulingFailed) {
        setState(
          () =>
              _error = 'Alarm saved, but scheduling failed. Tap Save to retry.',
        );
        return;
      }
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this alarm. Retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showFiloConfirmation(
      context,
      title: 'Delete alarm?',
      message: 'This study alarm will stop.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      confirmDestructive: true,
      icon: FiloIcons.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      if (repo.db != _boundDb || !repo.isCurrent()) return;
      await repo.deleteStudy(_id);
      if (mounted && repo.isCurrent()) Navigator.pop(context);
    } on StudySchedulingFailure {
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not finish deleting the alarm. Retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(studyAlarmRepositoryProvider);
    if (account.isLoading || account.hasError || !account.hasValue) {
      if (widget.asDrawer) {
        return Padding(
          padding: const EdgeInsets.all(FiloSpacing.screen),
          child: account.hasError
              ? const Text(
                  'Student account unavailable. Return and sign in again.',
                )
              : const Center(child: FiloCircularProgressIndicator()),
        );
      }
      return EntryBackground(
        verification: true,
        breeze: true,
        variation: 1,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Study alarm'),
          ),
          body: Center(
            child: account.hasError
                ? const Text(
                    'Student account unavailable. Return and sign in again.',
                  )
                : const FiloCircularProgressIndicator(),
          ),
        ),
      );
    }
    _boundDb ??= account.requireValue.db;
    if (_boundDb != account.requireValue.db) {
      if (widget.asDrawer) {
        return const Padding(
          padding: EdgeInsets.all(FiloSpacing.screen),
          child: Text('Account changed. Reopen study alarms.'),
        );
      }
      return EntryBackground(
        verification: true,
        breeze: true,
        variation: 1,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Study alarm'),
          ),
          body: const Center(
            child: Text('Account changed. Reopen study alarms.'),
          ),
        ),
      );
    }
    final locale = MaterialLocalizations.of(context);
    final links = [
      const DropdownMenuItem<String>(
        value: '',
        child: Text('None — open AI Study'),
      ),
      ..._links,
    ];
    if (_link != null && !_links.any((l) => l.value == _link)) {
      links.add(
        DropdownMenuItem(
          value: _link,
          child: const Text('Saved link (unavailable)'),
        ),
      );
    }
    final form = Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StudyOfflineBanner(),
          if (account.hasError)
            const Text(
              'Student account unavailable. Return and sign in again.',
            ),
          TextFormField(
            controller: _subject,
            maxLength: 120,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a subject.' : null,
          ),
          const SizedBox(height: FiloSpacing.s16),
          FiloPanel(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.schedule_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  title: const Text('Time'),
                  subtitle: Text(
                    _time.format(context),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  onTap: _busy
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _time,
                          );
                          if (t != null && mounted) setState(() => _time = t);
                        },
                ),
                const SizedBox(height: FiloSpacing.s16),
                Divider(
                  color: Theme.of(context).colorScheme.onPrimaryContainer
                      .withValues(alpha: .2),
                ),
                const SizedBox(height: FiloSpacing.s8),
                Semantics(
                  header: true,
                  child: Text(
                    'Repeat days',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: FiloSpacing.s8),
                Wrap(
                  spacing: FiloSpacing.s8,
                  runSpacing: FiloSpacing.s4,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FiloAnimatedChip.filter(
                        label: Text(
                          const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ][day - 1],
                        ),
                        tooltip: const [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday',
                        ][day - 1],
                        selected: (_days & (1 << (day - 1))) != 0,
                        onSelected: _busy
                            ? null
                            : (v) => setState(
                                () => _days = v
                                    ? _days | (1 << (day - 1))
                                    : _days & ~(1 << (day - 1)),
                              ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                  ],
                ),
                if (_days == 0)
                  Text(
                    'Once: ${locale.formatFullDate(nextStudyOnce(DateTime.now(), _time.hour * 60 + _time.minute))}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FiloSpacing.s16),
          DropdownButtonFormField<String>(
            itemHeight: null,
            initialValue: _link ?? '',
            items: links,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Open when tapped (optional)',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            onChanged: _busy
                ? null
                : (v) => setState(() => _link = v == '' ? null : v),
          ),
          if (_error != null) ...[
            const SizedBox(height: FiloSpacing.s12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _loadLinks,
              child: const Text('Retry links'),
            ),
          ],
          const SizedBox(height: FiloSpacing.screen),
          FiloButton(
            label: _busy ? 'Saving…' : 'Save',
            onPressed: _busy || !account.hasValue || account.hasError
                ? null
                : _save,
          ),
          if (widget.alarm != null)
            TextButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Delete alarm'),
            ),
        ],
      ),
    );
    if (widget.asDrawer) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          FiloSpacing.screen,
          FiloSpacing.s8,
          FiloSpacing.screen,
          0,
        ),
        child: form,
      );
    }
    return EntryBackground(
      verification: true,
      breeze: true,
      variation: 1,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            widget.alarm == null ? 'New study alarm' : 'Edit study alarm',
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FiloSpacing.screen),
            children: [form],
          ),
        ),
      ),
    );
  }
}
