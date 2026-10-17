import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../classes/application/class_providers.dart';
import '../application/post_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, required this.classId, this.postId});
  final String classId;
  final String? postId;
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _points = TextEditingController(text: '100');
  final List<_Attachment> _attachments = [];
  bool _busy = false;
  bool _loaded = false;
  String? _kind;
  DateTime? _originalDue;
  final List<_Attachment> _originalAttachments = [];

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) {
      _busy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEdit());
    }
  }

  Future<void> _loadEdit() async {
    try {
      final row = await _client
          .from('posts')
          .select()
          .eq('id', widget.postId!)
          .eq('class_id', widget.classId)
          .isFilter('deleted_at', null)
          .single();
      final files = await _client
          .from('post_attachments')
          .select()
          .eq('post_id', widget.postId!)
          .isFilter('deleted_at', null)
          .order('sort_order');
      if (!mounted) return;
      _title.text = row['title'] as String;
      _message.text = row['body'] as String? ?? '';
      _kind = row['kind'] as String;
      _submission = _kind == 'assignment';
      _points.text = '${row['points'] ?? 100}';
      _due = row['due_at'] == null
          ? null
          : DateTime.parse(row['due_at'] as String).toLocal();
      _originalDue = _due;
      _late = row['accept_late'] as bool;
      _allowFiles = row['allow_files'] as bool;
      _maxFiles = row['max_files'] as int;
      for (final row in files) {
        final a = _Attachment(
          row['name'] as String,
          id: row['id'] as String,
          url: row['url'] as String?,
          size: row['size_bytes'] as int?,
        );
        a.storagePath = row['storage_path'] as String?;
        a.ready = true;
        _attachments.add(a);
        _originalAttachments.add(a);
      }
      _loaded = true;
      _error = null;
    } catch (_) {
      _error = 'Could not load this post. Reopen Edit to retry.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _allowFiles = true;
  int _maxFiles = 5;
  String? _postId;
  String? _error;
  final String _publicationId = const Uuid().v4();
  bool _uncertain = false;
  bool get _online => ref.read(connectivityProvider).asData?.value == true;
  SupabaseClient get _client => ref.read(supabaseClientProvider);
  bool _submission = false;
  bool _late = true;
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final rooms = ref.watch(classCardsProvider).asData?.value;
    final room = rooms?.where((r) => r.id == widget.classId).firstOrNull;
    final repository = ref.watch(classRepositoryProvider).asData?.value;
    final writable = room != null && !room.archived && repository != null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.postId == null ? 'Create post' : 'Edit post'),
        ),
        body: Form(
          key: _form,
          child: AbsorbPointer(
            absorbing:
                !writable ||
                (widget.postId != null && !_loaded) ||
                _busy ||
                _postId != null ||
                _uncertain,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Share something worth learning.',
                  style: TextStyle(color: FiloColors.secondary),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give your post a title.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _message,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _attachments.length < 10 ? _attach : null,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('Attach file'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _attachments.length < 10 ? _addLink : null,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Add link'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Up to 10 attachments · 25 MB per file',
                  style: TextStyle(color: FiloColors.secondary, fontSize: 12),
                ),
                for (final attachment in _attachments)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FiloPanel(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Icon(
                            attachment.drive
                                ? Icons.add_to_drive
                                : Icons.attach_file_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(attachment.name),
                                if (attachment.drive) ...[
                                  const Text('Google Drive ? File or document'),
                                  const Text(
                                    'Set sharing to Anyone with the link so students can download it.',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove attachment',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                setState(() => _attachments.remove(attachment)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FiloPanel(
                  color: FiloColors.tint,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Require submission',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          widget.postId != null
                              ? 'Post type cannot change.'
                              : 'Turn this post into an assignment',
                        ),
                        value: _submission,
                        onChanged: widget.postId != null
                            ? null
                            : (value) => setState(() => _submission = value),
                      ),
                      if (_submission) ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _points,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Points',
                          ),
                          validator: (value) {
                            final points = int.tryParse(value ?? '');
                            return points == null ||
                                    points < 0 ||
                                    points > 2147483647
                                ? 'Enter a nonnegative whole number (up to 2147483647).'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _pickDue,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            _due == null ? 'Set due date and time' : _dueLabel,
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Accept late submissions'),
                          value: _late,
                          onChanged: (value) => setState(() => _late = value),
                        ),
                        SwitchListTile.adaptive(
                          title: const Text('Allow file uploads'),
                          value: _allowFiles,
                          onChanged: (value) =>
                              setState(() => _allowFiles = value),
                        ),
                        DropdownButtonFormField<int>(
                          initialValue: _maxFiles,
                          decoration: const InputDecoration(
                            labelText: 'Max files',
                          ),
                          items: [
                            for (var i = 1; i <= 5; i++)
                              DropdownMenuItem(value: i, child: Text('$i')),
                          ],
                          onChanged: _allowFiles
                              ? (value) => setState(() => _maxFiles = value!)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "To share a video, add a link. Video links open in the browser and aren't downloaded.",
                  style: TextStyle(color: FiloColors.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!online)
                      const Text(
                        'Connect to the internet to post or upload files.',
                      ),
                    if (!writable)
                      const Text(
                        'An open class owned by you is required to post.',
                      ),
                    if (_error != null) Text(_error!),
                    if (_busy) const LinearProgressIndicator(),
                    if (_postId != null)
                      for (final a in _attachments)
                        ListTile(
                          title: Text(a.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.ready
                                    ? 'Ready'
                                    : a.failed
                                    ? 'Upload failed'
                                    : a.uploading
                                    ? 'Uploading...'
                                    : 'Waiting',
                              ),
                              if (a.uploading) const LinearProgressIndicator(),
                            ],
                          ),
                          trailing: a.failed
                              ? TextButton(
                                  onPressed: online && writable && !_busy
                                      ? () => _retry(a)
                                      : null,
                                  child: const Text('Retry'),
                                )
                              : null,
                        ),
                    if (_postId != null)
                      TextButton(
                        onPressed: online && writable && !_busy
                            ? _deletePost
                            : null,
                        child: const Text('Delete post'),
                      ),
                    FiloButton(
                      label: _postId != null
                          ? 'Done'
                          : _uncertain
                          ? 'Refresh'
                          : widget.postId != null
                          ? 'Save changes'
                          : 'Post',
                      icon: Icons.send_rounded,
                      onPressed:
                          !online ||
                              !writable ||
                              _busy ||
                              (widget.postId != null && !_loaded)
                          ? null
                          : _postId != null
                          ? () => Navigator.of(context).pop()
                          : _uncertain
                          ? _resolve
                          : _post,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _dueLabel => _due == null
      ? 'No due date'
      : '${MaterialLocalizations.of(context).formatMediumDate(_due!)} · ${TimeOfDay.fromDateTime(_due!).format(context)}';

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _due != null && _due!.isAfter(now) ? _due! : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (time != null && mounted) {
      setState(
        () => _due = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _attach() async {
    try {
      final result = await FilePicker.pickFiles();
      if (!mounted) return;
      for (final file in result) {
        if (_attachments.length >= 10) {
          showMessage(
            context,
            'Add up to 10 attachments, including files and links.',
          );
          break;
        }
        final ext = file.name.split('.').last.toLowerCase();
        if ([
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
          'm4v',
          '3gp',
          'wmv',
        ].contains(ext)) {
          showMessage(context, "Videos can't be uploaded. Add a link instead.");
          continue;
        }
        final size = await file.length();
        if (!mounted) return;
        if (size == null) {
          showMessage(context, 'Could not read this file. Select it again.');
          continue;
        }
        if (size > 26214400) {
          showMessage(context, 'This file is too large. The limit is 25 MB.');
          continue;
        }
        if (file.name.length > 255) {
          showMessage(
            context,
            'Choose a file with a shorter name (255 characters maximum).',
          );
          continue;
        }
        setState(
          () =>
              _attachments.add(_Attachment(file.name, file: file, size: size)),
        );
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not choose files. Try again.');
    }
  }

  Future<void> _addLink() async {
    final link = await showDialog<String>(
      context: context,
      builder: (context) => const _LinkDialog(),
    );
    if (link != null && mounted && _attachments.length < 10) {
      setState(
        () => _attachments.add(
          _Attachment(
            link.length > 255 ? link.substring(0, 255) : link,
            url: link,
          ),
        ),
      );
    }
  }

  Future<void> _post() async {
    if (!_online || _busy || !_form.currentState!.validate()) return;
    if (_submission &&
        (_due == null ||
            (!_due!.isAfter(DateTime.now()) &&
                (widget.postId == null || _due != _originalDue)))) {
      showMessage(context, 'Choose a due date and time in the future.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('unavailable');
      final room = await _client
          .from('classes')
          .select('owner_id,archived_at,deleted_at')
          .eq('id', widget.classId)
          .single();
      if (room['owner_id'] != repository.userId ||
          room['archived_at'] != null ||
          room['deleted_at'] != null) {
        throw StateError('read only');
      }
      final values = <String, dynamic>{
        'title': _title.text.trim(),
        'body': _message.text.trim().isEmpty ? null : _message.text.trim(),
        'points': _submission ? int.parse(_points.text) : null,
        'due_at': _submission ? _due!.toUtc().toIso8601String() : null,
        'accept_late': _late,
        'allow_files': _allowFiles,
        'max_files': _maxFiles,
      };
      if (widget.postId != null) {
        await _client
            .from('posts')
            .update(values)
            .eq('id', widget.postId!)
            .eq('class_id', widget.classId)
            .isFilter('deleted_at', null)
            .select('id')
            .single();
        // Tombstone removals before additions so the shared ten-slot cap is respected.
        for (final a in _originalAttachments.where(
          (a) => !_attachments.contains(a),
        )) {
          await _client
              .from('post_attachments')
              .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', a.id)
              .select('id')
              .single();
        }
        _postId = widget.postId;
      } else {
        await _client
            .from('posts')
            .insert({
              ...values,
              'id': _publicationId,
              'class_id': widget.classId,
              'author_id': repository.userId,
              'kind': _submission
                  ? 'assignment'
                  : _attachments.isNotEmpty
                  ? 'material'
                  : 'announcement',
            })
            .timeout(const Duration(seconds: 30));
        _postId = _publicationId;
      }
      if (mounted) setState(() {});
      for (final a in _attachments) {
        await _upload(a);
      }
      await _refresh();
      if (widget.postId != null &&
          mounted &&
          _attachments.every((a) => a.ready)) {
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (error) {
      if (_postId != null) {
        _error = 'Post saved. Could not refresh the Stream. Refresh to retry.';
      } else if (widget.postId != null) {
        _error = 'Could not save all changes. Retry Save changes; some changes may already be saved.';
      } else if (error.code == '23505') {
        _uncertain = true;
        _error = 'This post may already be published. Use Refresh to continue.';
      } else {
        _error = error.code == '42501'
            ? "Couldn't publish your post. Posting permission was denied. Ask your administrator to check the post permissions and migrations."
            : "Couldn't publish your post. Try again.";
      }
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        debugPrint(
          'Create post database error: code=${error.code}; message=${error.message}',
        );
      }
    } catch (_) {
      if (widget.postId != null && _postId == null) {
        _error = 'Could not confirm all changes. Retry Save changes; some changes may already be saved.';
      } else if (_postId == null) {
        _uncertain = true;
        _error = "We couldn't confirm whether your post was published. Refresh the Stream before trying again.";
      } else {
        _error =
            'Post saved. Refresh the Stream to see the latest attachments.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    setState(() => _busy = true);
    try {
      final row = await _client
          .from('posts')
          .select('id')
          .eq('id', _publicationId)
          .maybeSingle();
      _uncertain = false;
      _error = null;
      if (row != null) {
        _postId = _publicationId;
        for (final a in _attachments) {
          await _upload(a);
        }
        await _refresh();
      }
    } catch (_) {
      _error = 'Could not refresh. Connect and try Refresh again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(postSyncProvider(widget.classId));
    final repository = await ref.read(postRepositoryProvider.future);
    await repository?.sync(widget.classId);
  }

  Future<void> _upload(_Attachment a) async {
    if (a.ready) return;
    a.failed = false;
    a.uploading = true;
    if (mounted) setState(() {});
    try {
      if (!_online) throw StateError('offline');
      String? path;
      if (a.file != null) {
        // Retain the extension for the storage video policy. Unique stable paths make retry safe.
        final extension = a.name.contains('.')
            ? '.${a.name.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}'
            : '';
        path = '${widget.classId}/$_postId/${a.id}$extension';
        a.storagePath = path;
        final bytes = await a.file!.readAsBytes();
        if (bytes.length > 26214400 || bytes.length != a.size) {
          throw StateError(
            'The selected file changed. Delete this post and select it again.',
          );
        }
        await _client.storage
            .from('materials')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
      }
      // Metadata is saved only after the object upload completes. Retry uses the same row ID.
      await _client.from('post_attachments').upsert({
        'id': a.id,
        'post_id': _postId,
        'kind': a.file == null ? 'link' : 'file',
        'name': a.name,
        'url': a.url,
        'storage_path': path,
        'size_bytes': a.size,
        'sort_order': _attachments.indexOf(a),
      }, ignoreDuplicates: true);
      a.ready = true;
    } catch (_) {
      a.failed = true;
    }
    a.uploading = false;
    if (mounted) setState(() {});
  }

  Future<void> _retry(_Attachment a) async {
    if (!_online || _busy) return;
    setState(() => _busy = true);
    try {
      await _upload(a);
      await _refresh();
    } catch (_) {
      _error = 'Could not refresh. Your post is saved; refresh the Stream.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
          'This post will no longer be available in the class. Its attached files will be removed from the server. Files already downloaded to phones will stay on those devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete post'),
          ),
        ],
      ),
    );
    if (confirm != true || !_online || !mounted) return;
    setState(() => _busy = true);
    try {
      final paths = _attachments
          .map((a) => a.storagePath)
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        await _client.storage.from('materials').remove(paths);
      }
      await _client
          .from('posts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _postId!)
          .select('id')
          .single();
      await _refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not confirm deletion. Refresh and try again.';
        });
      }
    }
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a link'),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(labelText: 'https://', errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          final uri = Uri.tryParse(value);
          if (uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              uri.host.isEmpty) {
            setState(() => _error = 'Enter a valid http or https link.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Add link'),
      ),
    ],
  );
}

class _Attachment {
  _Attachment(this.name, {String? id, this.file, this.url, this.size})
    : id = id ?? const Uuid().v4();
  final String id;
  final String name;
  final PlatformFile? file;
  final int? size;
  final String? url;
  String? storagePath;
  bool uploading = false;
  bool failed = false;
  bool ready = false;
  bool get drive => [
    'drive.google.com',
    'docs.google.com',
  ].contains(Uri.tryParse(url ?? '')?.host.toLowerCase());
}
