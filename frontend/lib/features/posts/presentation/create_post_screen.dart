import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../classes/application/preview_controller.dart';
import '../../classes/domain/prototype_models.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, required this.classId});
  final String classId;
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _points = TextEditingController(text: '20');
  final List<String> _attachments = [];
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
    if (ref.watch(previewProvider).role != PreviewRole.instructor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create post')),
        body: const Center(
          child: Text('Choose the instructor preview to create a post.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Create post')),
      body: Form(
        key: _form,
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
                      const Icon(Icons.attach_file_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(attachment)),
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
                    subtitle: const Text('Turn this post into an assignment'),
                    value: _submission,
                    onChanged: (value) => setState(() => _submission = value),
                  ),
                  if (_submission) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _points,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Points'),
                      validator: (value) {
                        final points = int.tryParse(value ?? '');
                        return points == null || points < 1 || points > 1000
                            ? 'Enter 1 to 1000 points.'
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Posts in this preview are visible only during this session.',
              style: TextStyle(color: FiloColors.secondary, fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: FiloButton(
            label: 'Post',
            icon: Icons.send_rounded,
            onPressed: _post,
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
      initialDate: _due ?? now,
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
    final file = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose a sample attachment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final file in sampleFiles)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(file.name),
                subtitle: Text(file.size),
                onTap: () => Navigator.pop(context, file.name),
              ),
          ],
        ),
      ),
    );
    if (file != null && mounted && !_attachments.contains(file)) {
      setState(() => _attachments.add(file));
    }
  }

  Future<void> _addLink() async {
    final link = await showDialog<String>(
      context: context,
      builder: (context) => const _LinkDialog(),
    );
    if (link != null && mounted && !_attachments.contains(link)) {
      setState(() => _attachments.add(link));
    }
  }

  void _post() {
    if (!_form.currentState!.validate()) return;
    ref
        .read(previewProvider.notifier)
        .addPost(
          ClassPost(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            classId: widget.classId,
            title: _title.text.trim(),
            message: _message.text.trim(),
            assignment: _submission,
            points: _submission ? int.parse(_points.text) : null,
            dueLabel: _submission
                ? '$_dueLabel${_late ? ' · Late work accepted' : ''}'
                : null,
            attachments: List.of(_attachments),
          ),
        );
    context.pop();
    showMessage(context, 'Post added to the preview stream.');
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
