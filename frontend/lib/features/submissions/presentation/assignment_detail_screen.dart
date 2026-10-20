import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../data/local/app_database.dart';
import '../../classes/application/class_providers.dart';
import '../../classes/presentation/classes_widgets.dart' show OfflineBanner;
import '../../classes/presentation/classwork_list.dart'
    show AssignmentStatusChip;
import '../../posts/application/post_providers.dart';
import '../../posts/presentation/post_attachment_tile.dart';
import '../application/submission_providers.dart';
import '../domain/assignment_status.dart';
import '../domain/assignment_file_rules.dart';

final _assignmentReadyProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, id) async* {
      final repository = await ref.watch(submissionRepositoryProvider.future);
      if (repository == null) {
        yield false;
        return;
      }
      final db = repository.database;
      yield* (db.select(db.syncState)
            ..where((s) => s.syncedTableName.equals('submissions:$id')))
          .watch()
          .map((rows) => rows.isNotEmpty);
    });

class _PendingFile {
  _PendingFile(this.path, this.name) : id = const Uuid().v4();
  final String id, path, name;
  bool uploading = false, attempted = false;
  String? error;
  double? progress;
}

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.classId,
    required this.postId,
  });
  final String classId, postId;
  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  final _comment = TextEditingController();
  final _pending = <_PendingFile>[];
  final _opening = <String>{};
  Timer? _ticker;
  bool _busy = false,
      _unavailable = false,
      _reconcile = false,
      _commentDirty = false;
  bool _seenPost = false;
  String? _lastServerComment;
  String? _draftLink, _draftText, _draftTextItemId;
  String? _error;
  CachePost? _post;
  CacheSubmission? _submission;
  CacheGrade? _grade;
  List<CacheSubmissionItem> _items = [];

  bool get _online => ref.read(connectivityProvider).asData?.value == true;
  bool get _overdue =>
      _post?.dueAt != null && DateTime.now().isAfter(_post!.dueAt!);
  bool get _closed => _overdue && !_post!.acceptLate;
  bool get _turnedIn => _submission?.status == 'turned_in';

  @override
  void initState() {
    super.initState();
    // The server deadline continues to expire while offline or backgrounded.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _online) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _comment.dispose();
    super.dispose();
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    final l = MaterialLocalizations.of(context);
    return '${l.formatFullDate(local)}, ${l.formatTimeOfDay(TimeOfDay.fromDateTime(local))} (${local.timeZoneName})';
  }

  Future<bool> _refresh({bool duringMutation = false}) async {
    if (!_online || (_busy && !duringMutation)) {
      return false;
    }
    try {
      ref.invalidate(postsProvider(widget.classId));
      ref.invalidate(classSubmissionsProvider(widget.classId));
      ref.invalidate(returnedGradesProvider(widget.classId));
      ref.invalidate(_assignmentReadyProvider(widget.classId));
      if (_submission != null) {
        ref.invalidate(submissionItemsProvider(_submission!.id));
      }
      final row = await ref
          .read(supabaseClientProvider)
          .from('posts')
          .select('id')
          .eq('id', widget.postId)
          .eq('class_id', widget.classId)
          .eq('kind', 'assignment')
          .isFilter('deleted_at', null)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _unavailable = row == null);
      ref.invalidate(submissionSyncProvider(widget.classId));
      await ref.read(submissionSyncProvider(widget.classId).future);
      if (mounted) {
        setState(() {
          _unavailable = row == null;
          _reconcile = false;
          _error = null;
        });
      }
      return row != null;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not refresh your work. Connect and refresh before trying again.',
        );
      }
      return false;
    }
  }

  void _message(String value) {
    if (mounted) {
      showMessage(context, value);
    }
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy || !_online) {
      return;
    }
    if (_reconcile) {
      await _refresh();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (error is PostgrestException &&
          error.code == '22023' &&
          (error.message.startsWith('File uploads are turned off') ||
              error.message.startsWith('The file limit changed.'))) {
        await _refresh(duringMutation: true);
        if (mounted) {
          setState(() => _error = error.message);
        }
        return;
      }
      if (error is PostgrestException &&
          (error.message.contains('unsubmit window') ||
              error.message.contains('grade was already returned'))) {
        await _refresh(duringMutation: true);
        _message(
          error.message.contains('grade')
              ? 'Your grade has been returned. You can no longer unsubmit this work.'
              : 'The unsubmit window has passed. Your work is turned in and can no longer be changed.',
        );
        return;
      }
      if (mounted) {
        setState(() {
          final unavailable =
              error is StateError &&
              error.message == 'This item is no longer available.';
          if (unavailable) {
            _unavailable = true;
          }
          final knownFileRestriction =
              error is StateError &&
              (error.message.toString().contains(
                    'Remove the saved files before turning in.',
                  ) ||
                  error.message.toString().contains(
                    'Remove extra files before turning in.',
                  ));
          _reconcile = !knownFileRestriction && !unavailable;
          _error = error is StateError ? error.message.toString() : 'Could not confirm the change. Refresh your work before trying again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _editor({
    required String title,
    required String label,
    String initial = '',
    int limit = 10000,
    bool multiline = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: limit,
            minLines: multiline ? 4 : 1,
            maxLines: multiline ? 10 : 1,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialog, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog may still animate after its result resolves.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return result;
  }

  Future<void> _addLink() async {
    final value = await _editor(
      title: 'Add link',
      label: 'https://',
      limit: 2048,
      initial: _draftLink ?? '',
    );
    if (value == null || !mounted) {
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      _message('Enter a valid http or https link.');
      return;
    }
    setState(() => _draftLink = value);
    await _retryLink();
  }

  Future<void> _text([CacheSubmissionItem? item]) async {
    final value = await _editor(
      title: item == null ? 'Add text' : 'Edit text',
      label: 'Your answer',
      initial: _draftText ?? item?.textContent ?? '',
      multiline: true,
    );
    if (value == null || !mounted) {
      return;
    }
    setState(() {
      _draftText = value;
      _draftTextItemId = item?.id;
    });
    await _retryText();
  }

  Future<void> _retryLink() => _perform(() async {
    final repository = await ref.read(submissionWorkRepositoryProvider.future);
    await repository!.addLink(widget.postId, url: _draftLink!);
    if (mounted) {
      setState(() => _draftLink = null);
    }
  });

  Future<void> _retryText() => _perform(() async {
    final repository = await ref.read(submissionWorkRepositoryProvider.future);
    await repository!.saveText(
      widget.postId,
      _draftText!,
      itemId: _draftTextItemId,
    );
    if (mounted) {
      setState(() {
        _draftText = null;
        _draftTextItemId = null;
      });
    }
  });

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null || !mounted) {
        return;
      }
      if (file.path == null) {
        _message('Could not read this file. Choose it again.');
        return;
      }
      await _selectFile(file.path!, file.name);
    } catch (_) {
      _message('Could not choose a file. Try again.');
    }
  }

  Future<void> _photo(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) {
        await _selectFile(photo.path, photo.name);
      }
    } catch (_) {
      _message(
        'Could not open photos or camera. Check access in your phone settings and try again.',
      );
    }
  }

  Future<void> _selectFile(String path, String name) async {
    final post = _post;
    if (post == null ||
        _turnedIn ||
        _grade != null ||
        _closed ||
        _unavailable) {
      return;
    }
    if (!post.allowFiles) {
      _message(
        'File uploads are turned off for this assignment. Add a link or text instead.',
      );
      return;
    }
    if (_items.where((i) => i.kind == 'file').length + _pending.length >=
        post.maxFiles) {
      _message(
        post.maxFiles == 1
            ? 'You can add only 1 file to this assignment. Remove it before adding another.'
            : 'You can add up to ${post.maxFiles} files to this assignment. Remove a file before adding another.',
      );
      return;
    }
    if (RegExp(
      r'\.(mp4|mov|avi|mkv|webm|m4v|3gp|wmv)$',
      caseSensitive: false,
    ).hasMatch(name)) {
      _message("Videos can't be uploaded. Add a link instead.");
      return;
    }
    if (await File(path).length() > 26214400) {
      _message('This file is too large. The limit is 25 MB.');
      return;
    }
    if (!mounted) {
      return;
    }
    final file = _PendingFile(path, name);
    setState(() => _pending.add(file));
    if (_online) {
      await _upload(file);
    }
  }

  Future<void> _upload(_PendingFile file) async {
    if (_busy || !_online || _reconcile) {
      return;
    }
    setState(() {
      _busy = true;
      file.uploading = true;
      file.attempted = true;
      file.error = null;
    });
    try {
      final repository = await ref.read(
        submissionWorkRepositoryProvider.future,
      );
      await repository!.uploadFile(
        widget.postId,
        localPath: file.path,
        name: file.name,
        uploadId: file.id,
        onProgress: (progress) {
          if (mounted) {
            setState(() => file.progress = progress);
          }
        },
      );
      if (mounted) {
        setState(() => _pending.remove(file));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => file.error = error is StateError
              ? error.message.toString()
              : 'Upload not confirmed. Reconnect and tap Retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          file.uploading = false;
        });
      }
    }
  }

  Future<void> _discard(_PendingFile file) async {
    if (!file.attempted) {
      setState(() => _pending.remove(file));
      return;
    }
    if (!_online) {
      _message('Connect to delete this upload from the server.');
      return;
    }
    await _perform(() async {
      final repository = await ref.read(
        submissionWorkRepositoryProvider.future,
      );
      await repository!.discardUpload(widget.postId, file.id, file.name);
      if (mounted) {
        setState(() => _pending.remove(file));
      }
    });
  }

  Future<void> _deleteItem(CacheSubmissionItem item) => _perform(() async {
    final repository = await ref.read(submissionWorkRepositoryProvider.future);
    await repository!.removeItem(item.id);
  });

  Future<void> _openItem(CacheSubmissionItem item) async {
    if (item.kind == 'text') {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Your text'),
          content: SingleChildScrollView(
            child: SelectableText(item.textContent ?? ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (!_online || !_opening.add(item.id)) {
      if (!_online) {
        _message('Connect to the internet to open this item.');
      }
      return;
    }
    setState(() {});
    try {
      final repository = await ref.read(
        submissionWorkRepositoryProvider.future,
      );
      final address = item.kind == 'file'
          ? await repository!.signedFileLink(item.id)
          : item.url;
      final uri = Uri.tryParse(address ?? '');
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          !await launchUrl(
            uri,
            mode: item.kind == 'link'
                ? LaunchMode.inAppBrowserView
                : LaunchMode.externalApplication,
          )) {
        throw StateError('open failed');
      }
    } catch (_) {
      _message('Could not open this item. Tap it again to retry.');
    } finally {
      _opening.remove(item.id);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String? get _fileRestriction => _post == null
      ? null
      : submissionFileRestriction(
          _post!,
          _items.where((item) => item.kind == 'file').length,
        );

  Future<void> _turnIn() async {
    if (_fileRestriction != null) {
      _message(_fileRestriction!);
      return;
    }
    if (_items.isEmpty) {
      _message(
        'Add at least one file, link, or text entry before turning in your work.',
      );
      return;
    }
    final late = _overdue;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Turn in your work?'),
        content: Text(
          late
              ? "Your instructor will receive your work. You won't be able to unsubmit after turning it in."
              : 'Your instructor will receive your work. You can unsubmit only while the countdown is running and before a grade is returned.\n\nYou have up to 10 minutes to unsubmit, or until the deadline, whichever comes first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Turn in'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _perform(() async {
      if (_closed ||
          _turnedIn ||
          _grade != null ||
          _items.isEmpty ||
          _pending.isNotEmpty) {
        throw StateError(
          'Your assignment changed. Refresh and review your work before turning it in.',
        );
      }
      if (_fileRestriction != null) {
        throw StateError(_fileRestriction!);
      }
      final repository = await ref.read(submissionRepositoryProvider.future);
      await repository!.turnIn(_submission!.id, comment: _comment.text.trim());
      _commentDirty = false;
    });
  }

  Future<void> _unsubmit() => _perform(() async {
    if (_grade != null ||
        _submission?.unsubmitUntil == null ||
        !DateTime.now().isBefore(_submission!.unsubmitUntil!)) {
      _message(
        _grade != null
            ? 'Your grade has been returned. You can no longer unsubmit this work.'
            : 'The unsubmit window has passed. Your work is turned in and can no longer be changed.',
      );
      await _refresh(duringMutation: true);
      return;
    }
    final repository = await ref.read(submissionRepositoryProvider.future);
    await repository!.unsubmit(_submission!.id);
  });

  @override
  Widget build(BuildContext _) {
    final id = widget.classId;
    ref.watch(submissionSyncLifecycleProvider(id));
    final posts = ref.watch(postsProvider(id));
    final submissions = ref.watch(classSubmissionsProvider(id));
    final grades = ref.watch(returnedGradesProvider(id));
    final ready = ref.watch(_assignmentReadyProvider(id));
    final sync = ref.watch(submissionSyncProvider(id));
    final attachments = ref.watch(postAttachmentsProvider(widget.postId));
    _post = posts.asData?.value
        .where((p) => p.id == widget.postId && p.kind == 'assignment')
        .firstOrNull;
    if (_post != null) _seenPost = true;
    _submission = submissions.asData?.value
        .where((s) => s.postId == widget.postId)
        .firstOrNull;
    _grade = grades.asData?.value
        .where((g) => g.submissionId == _submission?.id)
        .firstOrNull;
    final itemState = _submission == null
        ? null
        : ref.watch(submissionItemsProvider(_submission!.id));
    _items = itemState?.asData?.value ?? [];
    if (_submission != null &&
        _lastServerComment != _submission!.privateComment) {
      _lastServerComment = _submission!.privateComment;
      if (!_commentDirty) _comment.text = _submission!.privateComment ?? '';
    }
    final room = ref
        .watch(classCardsProvider)
        .asData
        ?.value
        .where((r) => r.id == id)
        .firstOrNull;
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final loading =
        (posts.isLoading && !posts.hasValue) ||
        (submissions.isLoading && !submissions.hasValue) ||
        (grades.isLoading && !grades.hasValue) ||
        (itemState?.isLoading == true && !itemState!.hasValue);
    final failed =
        posts.hasError ||
        submissions.hasError ||
        grades.hasError ||
        (itemState?.hasError ?? false) ||
        ready.hasError;
    final confirmed = ready.asData?.value == true;
    final editable =
        !_unavailable &&
        _post != null &&
        room != null &&
        !room.archived &&
        !_turnedIn &&
        _grade == null &&
        !_closed &&
        confirmed &&
        !loading &&
        !failed;
    final canWrite = editable && online && !_busy && !_reconcile;
    AssignmentStatus? status = confirmed || _submission != null
        ? assignmentStatus(
            dueAt: _post?.dueAt,
            submission: _submission,
            grade: _grade,
          )
        : null;
    if (status == AssignmentStatus.missing && _post?.acceptLate == true) {
      status = AssignmentStatus.late;
    }
    final remaining = _submission?.unsubmitUntil?.difference(DateTime.now());
    final seconds = remaining == null
        ? 0
        : (remaining.inMilliseconds / 1000).ceil();
    final unsubmitAllowed =
        _turnedIn &&
        seconds > 0 &&
        _grade == null &&
        !(_submission?.isLate ?? false);
    final textItem = _items.where((i) => i.kind == 'text').firstOrNull;
    return PopScope(
      canPop:
          !_commentDirty &&
          _pending.isEmpty &&
          _draftText == null &&
          _draftLink == null &&
          !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Leave this assignment?'),
            content: const Text(
              'Unsaved comments, links, text, and selected files will be lost. Saved work stays with this assignment.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          final attempted = _pending.where((f) => f.attempted).toList();
          var cleanupFailed = attempted.isNotEmpty && !_online;
          if (attempted.isNotEmpty && _online) {
            setState(() => _busy = true);
            try {
              final repository = await ref.read(
                submissionWorkRepositoryProvider.future,
              );
              for (final file in attempted) {
                await repository!.discardUpload(
                  widget.postId,
                  file.id,
                  file.name,
                );
              }
            } catch (_) {
              cleanupFailed = true;
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }
          if (cleanupFailed && mounted) {
            final leaveAnyway = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('Leave with unfinished uploads?'),
                content: const Text(
                  'Some uploads could not be removed from the server. Their state is unconfirmed. Leaving will discard the local Retry and Delete controls.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Stay'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Leave anyway'),
                  ),
                ],
              ),
            );
            if (leaveAnyway != true) return;
          }
          if (!mounted) return;
          setState(() {
            _commentDirty = false;
            _pending.clear();
            _draftLink = null;
            _draftText = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assignment'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: online && !_busy
                  ? () async {
                      ref.invalidate(postsProvider(id));
                      ref.invalidate(classSubmissionsProvider(id));
                      ref.invalidate(returnedGradesProvider(id));
                      ref.invalidate(_assignmentReadyProvider(id));
                      ref.invalidate(postAttachmentsProvider(widget.postId));
                      if (_submission != null) {
                        ref.invalidate(
                          submissionItemsProvider(_submission!.id),
                        );
                      }
                      await _refresh();
                    }
                  : null,
              icon: const FiloIcon(FiloIcons.refresh),
            ),
          ],
        ),
        body:
            (_unavailable ||
                (_seenPost &&
                    _post == null &&
                    posts.hasValue &&
                    !posts.isLoading &&
                    !posts.hasError))
            ? const Center(child: Text('This item is no longer available.'))
            : RefreshIndicator(
                onRefresh: () async {
                  await _refresh();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (!online) const OfflineBanner(),
                    if (_error != null || failed || sync.hasError) ...[
                      Text(
                        _error ?? 'Could not refresh your work. Saved content is shown when available.',
                      ),
                      TextButton(
                        onPressed: online && !_busy
                            ? () async {
                                await _refresh();
                              }
                            : null,
                        child: const Text('Refresh and retry'),
                      ),
                    ],
                    if (_post == null)
                      if (loading || sync.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        const Text(
                          'No saved assignment on this device. Connect and refresh to load it.',
                        )
                    else ...[
                      Text(
                        _post!.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text('${_post!.points ?? 0} points'),
                      Text(
                        _post!.dueAt == null
                            ? 'No due date'
                            : 'Due ${_date(_post!.dueAt!)}',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AssignmentStatusChip(status: status),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(_post!.body ?? ''),
                      const SizedBox(height: 16),
                      if (attachments.isLoading)
                        const LinearProgressIndicator(),
                      if (attachments.hasError)
                        TextButton(
                          onPressed: () => ref.invalidate(
                            postAttachmentsProvider(widget.postId),
                          ),
                          child: const Text(
                            'Could not load attachments. Retry',
                          ),
                        ),
                      for (final a
                          in attachments.asData?.value ??
                              <CachePostAttachment>[])
                        PostAttachmentTile(
                          classId: id,
                          postId: widget.postId,
                          attachment: a,
                          onUnavailable: () =>
                              setState(() => _unavailable = true),
                        ),
                      const SizedBox(height: 24),
                      if (_grade != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your grade',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  _grade!.score == null
                                      ? 'Score unavailable'
                                      : '${_grade!.score}/${_post!.points ?? 0}',
                                ),
                                if (_grade!.feedback?.isNotEmpty == true)
                                  SelectableText(_grade!.feedback!),
                              ],
                            ),
                          ),
                        ),
                      Card(
                        color: FiloColors.tint,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your work',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (loading) const LinearProgressIndicator(),
                              if (_turnedIn && _submission?.submittedAt != null)
                                Text(
                                  'Turned in ${_date(_submission!.submittedAt!)}',
                                ),
                              for (final item in _items)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: FiloIcon(
                                    item.kind == 'text'
                                        ? FiloIcons.notes
                                        : item.kind == 'link'
                                        ? FiloIcons.link
                                        : FiloIcons.file,
                                  ),
                                  title: Text(
                                    item.name ??
                                        (item.kind == 'text'
                                            ? 'Text entry'
                                            : item.url ?? 'File'),
                                  ),
                                  subtitle: item.kind == 'text'
                                      ? Text(
                                          item.textContent ?? '',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  onTap: () => _openItem(item),
                                  trailing: _opening.contains(item.id)
                                      ? const CircularProgressIndicator()
                                      : editable
                                      ? PopupMenuButton<String>(
                                          enabled: canWrite,
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _text(item);
                                            } else {
                                              _deleteItem(item);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            if (item.kind == 'text')
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              for (final file in _pending)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(file.name),
                                    if (file.uploading)
                                      LinearProgressIndicator(
                                        value: file.progress,
                                      ),
                                    if (file.error != null) Text(file.error!),
                                    if (!file.uploading)
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          TextButton(
                                            onPressed: canWrite
                                                ? () => _upload(file)
                                                : null,
                                            child: const Text('Retry'),
                                          ),
                                          TextButton(
                                            onPressed: !_busy
                                                ? () => _discard(file)
                                                : null,
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              if (_draftLink != null) ...[
                                Text('Unsaved link: $_draftLink'),
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: canWrite ? _retryLink : null,
                                      child: const Text('Retry'),
                                    ),
                                    TextButton(
                                      onPressed: !_busy ? _addLink : null,
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: !_busy
                                          ? () => setState(
                                              () => _draftLink = null,
                                            )
                                          : null,
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                              if (_draftText != null) ...[
                                const Text('Unsaved text'),
                                Text(
                                  _draftText!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: canWrite ? _retryText : null,
                                      child: const Text('Retry'),
                                    ),
                                    TextButton(
                                      onPressed: !_busy
                                          ? () => _text(textItem)
                                          : null,
                                      child: const Text('Edit'),
                                    ),
                                    TextButton(
                                      onPressed: !_busy
                                          ? () => setState(() {
                                              _draftText = null;
                                              _draftTextItemId = null;
                                            })
                                          : null,
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                              if (confirmed &&
                                  !loading &&
                                  _items.isEmpty &&
                                  _pending.isEmpty &&
                                  _draftLink == null &&
                                  _draftText == null)
                                const Text(
                                  'Add a file, link, or text to get started.',
                                ),
                              if (!_turnedIn && _fileRestriction != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(_fileRestriction!),
                                ),
                              if (editable) ...[
                                if (!online)
                                  const Text(
                                    'Connect to the internet to add work.',
                                  ),
                                if (_items
                                        .where((i) => i.kind == 'link')
                                        .length >=
                                    5)
                                  const Text(
                                    'You can add up to 5 links. Remove a link before adding another.',
                                  ),
                                if (_post!.allowFiles &&
                                    _items
                                                .where((i) => i.kind == 'file')
                                                .length +
                                            _pending.length >=
                                        _post!.maxFiles)
                                  Text(
                                    _post!.maxFiles == 1
                                        ? 'You can add only 1 file to this assignment. Remove it before adding another.'
                                        : 'You can add up to ${_post!.maxFiles} files to this assignment. Remove a file before adding another.',
                                  ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (_post!.allowFiles)
                                      TextButton.icon(
                                        onPressed: canWrite ? _pickFile : null,
                                        icon: const FiloIcon(
                                          FiloIcons.attachment,
                                        ),
                                        label: const Text('Add file'),
                                      ),
                                    TextButton.icon(
                                      onPressed:
                                          canWrite &&
                                              _items
                                                      .where(
                                                        (i) => i.kind == 'link',
                                                      )
                                                      .length <
                                                  5
                                          ? _addLink
                                          : null,
                                      icon: const FiloIcon(FiloIcons.link),
                                      label: const Text('Add link'),
                                    ),
                                    TextButton.icon(
                                      onPressed: canWrite
                                          ? () => _text(textItem)
                                          : null,
                                      icon: const FiloIcon(FiloIcons.notes),
                                      label: Text(
                                        textItem == null
                                            ? 'Add text'
                                            : 'Edit text',
                                      ),
                                    ),
                                    if (_post!.allowFiles)
                                      TextButton.icon(
                                        onPressed: canWrite
                                            ? () => _photo(ImageSource.camera)
                                            : null,
                                        icon: const FiloIcon(FiloIcons.camera),
                                        label: const Text('Take photo'),
                                      ),
                                    if (_post!.allowFiles)
                                      TextButton.icon(
                                        onPressed: canWrite
                                            ? () => _photo(ImageSource.gallery)
                                            : null,
                                        icon: const FiloIcon(FiloIcons.images),
                                        label: const Text('Choose photo'),
                                      ),
                                  ],
                                ),
                                if (!_post!.allowFiles)
                                  const Text(
                                    'File uploads are turned off for this assignment. Add a link or text instead.',
                                  ),
                                TextField(
                                  controller: _comment,
                                  enabled: !_busy,
                                  minLines: 2,
                                  maxLines: 5,
                                  maxLength: 1000,
                                  decoration: const InputDecoration(
                                    labelText: 'Private comment',
                                    hintText:
                                        'Optional note to your instructor',
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _commentDirty = true),
                                ),
                                TextButton(
                                  onPressed: canWrite && _commentDirty
                                      ? () => _perform(() async {
                                          final repository = await ref.read(
                                            submissionWorkRepositoryProvider
                                                .future,
                                          );
                                          await repository!.saveComment(
                                            widget.postId,
                                            _comment.text.trim(),
                                          );
                                          _commentDirty = false;
                                        })
                                      : null,
                                  child: const Text('Save comment'),
                                ),
                              ] else if (_submission
                                      ?.privateComment
                                      ?.isNotEmpty ==
                                  true)
                                Text(
                                  'Private comment: ${_submission!.privateComment}',
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (room?.archived == true)
                        const Text('This class is archived.'),
                      if (_closed && !_turnedIn)
                        Text('Submissions closed on ${_date(_post!.dueAt!)}.'),
                      if (!online)
                        Text(
                          _turnedIn
                              ? 'Connect to the internet to unsubmit your work.'
                              : 'Connect to the internet to turn in your work.',
                        ),
                      if (_turnedIn && !unsubmitAllowed)
                        Text(
                          _grade != null
                              ? 'Your grade has been returned. You can no longer unsubmit this work.'
                              : 'The unsubmit window has passed. Your work is turned in and can no longer be changed.',
                        ),
                    ],
                  ],
                ),
              ),
        bottomNavigationBar: _post == null || _unavailable
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: _turnedIn
                      ? unsubmitAllowed
                            ? Semantics(
                                liveRegion: false,
                                label:
                                    'Unsubmit. ${seconds ~/ 60} minutes and ${seconds % 60} seconds remaining.',
                                child: FiloButton(
                                  label:
                                      'Unsubmit (${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')})',
                                  secondary: true,
                                  onPressed:
                                      online &&
                                          confirmed &&
                                          !loading &&
                                          !failed &&
                                          !_busy &&
                                          !_reconcile &&
                                          room != null &&
                                          !room.archived
                                      ? _unsubmit
                                      : null,
                                ),
                              )
                            : const SizedBox.shrink()
                      : FiloButton(
                          label: _busy ? 'Saving…' : 'Turn in',
                          icon: FiloIcons.check,
                          onPressed:
                              canWrite &&
                                  _fileRestriction == null &&
                                  _items.isNotEmpty &&
                                  _pending.isEmpty &&
                                  _draftText == null &&
                                  _draftLink == null
                              ? _turnIn
                              : null,
                        ),
                ),
              ),
      ),
    );
  }
}
