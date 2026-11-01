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
          profile?.deletedAt != null)
        throw StateError('Student account unavailable');
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
      if (mounted && repo.isCurrent())
        setState(() => {_status = status, _error = null});
    } catch (_) {
      if (mounted)
        setState(() {
          _status = null;
          _error = 'Could not check study alarm scheduling. Retry.';
        });
    }
  }

  Future<void> _toggle(StudyAlarm alarm, bool on) async {
    setState(() => _busy = true);
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      if (repo.db != _boundDb || !repo.isCurrent()) return;
      await repo.toggleStudy(alarm, on);
    } catch (_) {
      if (mounted)
        setState(() {
          _status = null;
          _error = 'Could not finish updating this alarm. Saved changes may need scheduling. Retry.';
        });
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _edit([StudyAlarm? alarm]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StudyAlarmEditor(alarm: alarm)),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(studyAlarmRepositoryProvider);
    final alarms = ref.watch(studyAlarmsProvider);
    if (!repo.isLoading && !repo.hasError && repo.hasValue) {
      _boundDb ??= repo.requireValue.db;
      if (_boundDb != repo.requireValue.db)
        return Scaffold(
          appBar: AppBar(title: const Text('Study alarms')),
          body: const Center(
            child: Text('Account changed. Reopen study alarms.'),
          ),
        );
    }
    final locale = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
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
          padding: const EdgeInsets.all(24),
          children: [
            const StudyOfflineBanner(),
            FiloButton(
              label: 'New alarm',
              icon: Icons.add,
              onPressed:
                  repo.hasValue && !repo.isLoading && !repo.hasError && !_busy
                  ? () => _edit()
                  : null,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!),
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
                    if (mounted)
                      setState(
                        () => _error = 'Open your phone settings and enable notifications for Filo.',
                      );
                  }
                },
                child: const Text('Open settings'),
              ),
            const SizedBox(height: 16),
            if (alarms.isLoading || repo.isLoading)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading study alarms',
                ),
              )
            else if (alarms.hasError || repo.hasError) ...[
              const Text('Could not load study alarms. Sign in or retry.'),
              TextButton(
                onPressed: () {
                  ref.invalidate(studyAlarmRepositoryProvider);
                  ref.invalidate(studyAlarmsProvider);
                  _refresh();
                },
                child: const Text('Retry'),
              ),
            ] else if (alarms.requireValue.isEmpty)
              const Column(
                children: [
                  Mascot(pose: 'cheerful_note', size: 120),
                  Text('No study alarms yet.'),
                ],
              )
            else
              for (final alarm in alarms.requireValue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FiloPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _busy ? null : () => _edit(alarm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alarm.subject,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    TimeOfDay(
                                      hour: alarm.minuteOfDay ~/ 60,
                                      minute: alarm.minuteOfDay % 60,
                                    ).format(context),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  Text(
                                    studyRepeatLabel(alarm.repeatDays, locale),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          label:
                              '${alarm.subject}, ${alarm.enabled ? 'on' : 'off'}',
                          child: Switch(
                            value: alarm.enabled,
                            onChanged: _busy ? null : (v) => _toggle(alarm, v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class StudyAlarmEditor extends ConsumerStatefulWidget {
  const StudyAlarmEditor({super.key, this.alarm});
  final StudyAlarm? alarm;
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
      if (mounted)
        setState(() => _error = 'Could not load optional links. Retry.');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => {_busy = true, _error = null});
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alarm?'),
        content: const Text('This study alarm will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(studyAlarmRepositoryProvider.future);
      if (repo.db != _boundDb || !repo.isCurrent()) return;
      await repo.deleteStudy(_id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not finish deleting the alarm. Retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(studyAlarmRepositoryProvider);
    if (account.isLoading || account.hasError || !account.hasValue)
      return Scaffold(
        appBar: AppBar(title: const Text('Study alarm')),
        body: Center(
          child: account.hasError
              ? const Text(
                  'Student account unavailable. Return and sign in again.',
                )
              : const CircularProgressIndicator(),
        ),
      );
    _boundDb ??= account.requireValue.db;
    if (_boundDb != account.requireValue.db)
      return Scaffold(
        appBar: AppBar(title: const Text('Study alarm')),
        body: const Center(
          child: Text('Account changed. Reopen study alarms.'),
        ),
      );
    final locale = MaterialLocalizations.of(context);
    final links = [
      const DropdownMenuItem<String>(
        value: '',
        child: Text('None — open AI Study'),
      ),
      ..._links,
    ];
    if (_link != null && !_links.any((l) => l.value == _link))
      links.add(
        DropdownMenuItem(
          value: _link,
          child: const Text('Saved link (unavailable)'),
        ),
      );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.alarm == null ? 'New study alarm' : 'Edit study alarm',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
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
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a subject.' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Time'),
                subtitle: Text(_time.format(context)),
                trailing: const Icon(Icons.schedule),
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
              const SizedBox(height: 16),
              const Text('Repeat days'),
              Wrap(
                spacing: 8,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(locale.narrowWeekdays[day % 7]),
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
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                itemHeight: null,
                initialValue: _link ?? '',
                items: links,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Open when tapped (optional)',
                ),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _link = v == '' ? null : v),
              ),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: _busy ? null : _loadLinks,
                  child: const Text('Retry links'),
                ),
              ],
              const SizedBox(height: 24),
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
        ),
      ),
    );
  }
}
