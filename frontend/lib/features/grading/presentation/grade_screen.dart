import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/filo_icon.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../application/grading_providers.dart';
import '../domain/grading_models.dart';
import 'submissions_screen.dart'
    show gradingName, gradingDate, GradeStatusChip, GradingSkeleton;

class GradeScreen extends ConsumerStatefulWidget {
  const GradeScreen({
    super.key,
    required this.classId,
    required this.postId,
    required this.studentId,
  });
  final String classId, postId, studentId;
  @override
  ConsumerState<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends ConsumerState<GradeScreen> {
  final _score = TextEditingController(), _feedback = TextEditingController();
  final _form = GlobalKey<FormState>();
  late String _student;
  String? _loaded, _error;
  String _originalScore = '', _originalFeedback = '';
  bool _busy = false, _allowPop = false, _reconcile = false;
  bool get _dirty =>
      _score.text != _originalScore || _feedback.text != _originalFeedback;
  bool get _online => ref.read(connectivityProvider).asData?.value == true;
  bool get _archived =>
      !(ref
              .read(classesProvider)
              .asData
              ?.value
              .any((c) => c.id == widget.classId && c.archivedAt == null) ??
          false);
  @override
  void initState() {
    super.initState();
    _student = widget.studentId;
  }

  @override
  void dispose() {
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title.startsWith('Return') ? 'Return' : 'Save'),
            ),
          ],
        ),
      ) ==
      true;
  Future<void> _refresh() async {
    if (!_online) {
      return;
    }
    try {
      ref.invalidate(gradingSyncProvider(widget.classId));
      await ref.read(gradingSyncProvider(widget.classId).future);
      final repo = await ref.read(gradingRepositoryProvider.future);
      final fresh = await repo?.read(widget.classId);
      if (!mounted) {
        return;
      }
      final work = fresh?.submission(widget.postId, _student);
      final saved = fresh?.grade(work?['id'] as String?);
      if (!_dirty ||
          (saved != null &&
              saved['score'].toString() == _score.text &&
              (saved['feedback'] ?? '') == _feedback.text)) {
        _score.text = saved?['score']?.toString() ?? '';
        _feedback.text = saved?['feedback']?.toString() ?? '';
        _originalScore = _score.text;
        _originalFeedback = _feedback.text;
      }
      if (mounted) {
        setState(() {
          _reconcile = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't load grades. Try again.");
      }
    }
  }

  Future<bool> _save() async {
    if (!_online ||
        _archived ||
        _busy ||
        _reconcile ||
        !(_form.currentState?.validate() ?? false)) {
      return false;
    }
    final data = ref.read(gradingDataProvider(widget.classId)).asData?.value;
    if (data == null) {
      return false;
    }
    final submission = data.submission(widget.postId, _student);
    if (submission == null &&
        !await _confirm(
          'Score missing work?',
          'No work turned in. Saving a score locks any unfinished draft and discards its attachment metadata. This score stays hidden until returned.',
        )) {
      return false;
    }
    if (!_online || _archived || !mounted) {
      return false;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wasReturned =
          submission != null &&
          data.grade(submission['id'].toString())?['returned_at'] != null;
      final repo = await ref.read(gradingRepositoryProvider.future);
      if (repo == null) {
        throw StateError('No account');
      }
      await repo.save(
        widget.classId,
        widget.postId,
        _student,
        int.parse(_score.text),
        _feedback.text,
      );
      _originalScore = _score.text;
      _originalFeedback = _feedback.text;
      await _refresh();
      _message(
        wasReturned
            ? 'Grade updated. The student can see your changes.'
            : 'Grade saved.',
      );
      return true;
    } on PostgrestException {
      if (mounted) {
        setState(() => _error = "Couldn't save the grade. Try again.");
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() {
          _reconcile = true;
          _error = "We couldn't confirm the update. Refresh to check the grade before trying again.";
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _leave() async {
    if (_busy) {
      return false;
    }
    if (!_dirty) {
      return true;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save changes before leaving?'),
        content: const Text(
          'Save your changes or discard them before opening another student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard changes'),
          ),
          FilledButton(
            onPressed: _online && !_archived && !_reconcile
                ? () => Navigator.pop(context, 'save')
                : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return choice == 'discard' || (choice == 'save' && await _save());
  }

  Future<void> _move(String student) async {
    if (!await _leave() || !mounted) {
      return;
    }
    setState(() {
      _student = student;
      _loaded = null;
      _error = null;
      _reconcile = false;
    });
  }

  Future<void> _returnGrade() async {
    if (_busy || !_online || _archived || _dirty || _reconcile) {
      return;
    }
    if (!await _confirm(
          'Return this grade?',
          'The student will be able to see their score and feedback.',
        ) ||
        !mounted ||
        !_online) {
      return;
    }
    final data = ref.read(gradingDataProvider(widget.classId)).asData?.value;
    final submission = data?.submission(widget.postId, _student);
    if (submission == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = await ref.read(gradingRepositoryProvider.future);
      if (repo == null) {
        throw StateError('No account');
      }
      final count = await repo.returnOne(
        widget.classId,
        submission['id'].toString(),
      );
      await _refresh();
      _message(count == 0 ? 'No grades to return.' : 'Grade returned.');
    } on PostgrestException {
      if (mounted) {
        setState(() => _error = "Couldn't return the grades. Try again.");
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reconcile = true;
          _error = "We couldn't confirm the update. Refresh to check the grade before trying again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(Json item) async {
    if (!_online) {
      _message('Connect to the internet to open this file or link.');
      return;
    }
    try {
      final String url;
      if (item['kind'] == 'file') {
        url = await ref
            .read(supabaseClientProvider)
            .storage
            .from('submissions')
            .createSignedUrl(item['storage_path'].toString(), 300)
            .timeout(const Duration(seconds: 20));
      } else {
        url = item['url'].toString();
      }
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      _message("Couldn't open this item. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    ref.watch(classesProvider);
    final sync = ref.watch(gradingSyncProvider(widget.classId));
    final state = ref.watch(gradingDataProvider(widget.classId));
    return PopScope(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _leave() && mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Grade work')),
        body: state.when(
          loading: () => const GradingSkeleton(),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text("Couldn't load grades. Try again."),
            ),
          ),
          data: (data) {
            if (!data.loaded) {
              return sync.isLoading
                  ? const GradingSkeleton()
                  : Center(
                      child: TextButton(
                        onPressed: _refresh,
                        child: Text(
                          online
                              ? "Couldn't load grades. Try again."
                              : 'Connect to the internet to load grades',
                        ),
                      ),
                    );
            }
            final assignment = data.assignment(widget.postId);
            if (assignment == null) {
              return Center(
                child: Text(
                  online
                      ? 'This item is no longer available.'
                      : 'Connect to the internet to load grades',
                ),
              );
            }
            final matches = data.members.where(
              (m) => m['student_id'] == _student,
            );
            final member = matches.isEmpty
                ? <String, dynamic>{}
                : matches.first;
            final submission = data.submission(widget.postId, _student);
            final grade = submission == null
                ? null
                : data.grade(submission['id'].toString());
            if (_loaded != _student) {
              _loaded = _student;
              _score.text = grade?['score']?.toString() ?? '';
              _feedback.text = grade?['feedback']?.toString() ?? '';
              _originalScore = _score.text;
              _originalFeedback = _feedback.text;
            }
            final status = data.status(widget.postId, _student);
            final missing = submission == null && status == 'Missing';
            final writable =
                online &&
                !_archived &&
                !_busy &&
                !_reconcile &&
                (submission != null || missing);
            final students =
                data.members.where((m) {
                  final s = data.submission(
                    widget.postId,
                    m['student_id'].toString(),
                  );
                  return m['status'] == 'active' && s?['submitted_at'] != null;
                }).toList()..sort(
                  (a, b) => gradingName(a).compareTo(gradingName(b)),
                );
            final index = students.indexWhere(
              (m) => m['student_id'] == _student,
            );
            final items = submission?['items'] as List? ?? [];
            final max = (assignment['points'] as num?)?.toInt() ?? 0;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: Form(
                key: _form,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (!online) const OfflineBanner(),
                    if (sync.hasError)
                      TextButton(
                        onPressed: _refresh,
                        child: const Text("Couldn't load grades. Try again."),
                      ),
                    if (_archived) const Text('This class is archived.'),
                    Text(
                      gradingName(member),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('${assignment['title']}'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GradeStatusChip(status),
                    ),
                    if (submission?['submitted_at'] != null)
                      Text(
                        'Turned in ${gradingDate(submission!['submitted_at'])}',
                      ),
                    if (submission?['is_late'] == true)
                      const Text(
                        'Late',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (submission == null ||
                        submission['submitted_at'] == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No work turned in.'),
                      ),
                    ...items.map((raw) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      if (item['kind'] == 'text') {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            '${item['text_content'] ?? ''}',
                          ),
                        );
                      }
                      final file = item['kind'] == 'file';
                      return ListTile(
                        leading: FiloIcon(
                          file
                              ? ('${item['mime_type']}'.startsWith('image/')
                                    ? FiloIcons.image
                                    : '${item['mime_type']}' ==
                                          'application/pdf'
                                    ? FiloIcons.pdf
                                    : FiloIcons.file)
                              : FiloIcons.link,
                        ),
                        title: Text('${item['name'] ?? item['url'] ?? 'File'}'),
                        subtitle: Text(
                          file
                              ? '${item['size_bytes'] ?? 0} bytes · ${item['mime_type'] ?? 'File'}'
                              : '${item['url']}',
                        ),
                        onTap: () => _open(item),
                      );
                    }),
                    if ((submission?['comment'] ?? '').toString().isNotEmpty)
                      ListTile(
                        title: const Text('Private comment'),
                        subtitle: Text('${submission!['comment']}'),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _score,
                      enabled: writable,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Score',
                        suffixText: '/ $max',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final score = int.tryParse(v ?? '');
                        if (score == null ||
                            !RegExp(r'^-?[0-9]+$').hasMatch(v ?? '')) {
                          return 'Enter a whole-number score.';
                        }
                        if (score < 0 || score > max) {
                          return 'Score must be between 0 and $max';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _feedback,
                      enabled: writable,
                      maxLength: 2000,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Feedback'),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (!online)
                      const Text('Connect to the internet to save grades'),
                    if (_error != null)
                      ListTile(
                        title: Text(_error!),
                        trailing: TextButton(
                          onPressed: _busy ? null : _refresh,
                          child: const Text('Refresh'),
                        ),
                      ),
                    FilledButton(
                      onPressed: writable ? _save : null,
                      child: Text(_busy ? 'Saving…' : 'Save'),
                    ),
                    OutlinedButton(
                      onPressed:
                          writable &&
                              grade != null &&
                              grade['returned_at'] == null &&
                              !_dirty
                          ? _returnGrade
                          : null,
                      child: const Text('Return'),
                    ),
                    if (!online)
                      const Text('Connect to the internet to return grades'),
                    if (_dirty) const Text('Unsaved changes'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: !_busy && index > 0
                              ? () => _move(
                                  students[index - 1]['student_id'].toString(),
                                )
                              : null,
                          child: const Text('Previous'),
                        ),
                        Text(
                          index < 0
                              ? '${students.length} turned in'
                              : '${index + 1} of ${students.length}',
                        ),
                        TextButton(
                          onPressed:
                              !_busy &&
                                  index >= 0 &&
                                  index < students.length - 1
                              ? () => _move(
                                  students[index + 1]['student_id'].toString(),
                                )
                              : null,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
