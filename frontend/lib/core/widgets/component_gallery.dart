import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_widgets.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({
    super.key,
    required this.mode,
    required this.scale,
    required this.onMode,
    required this.onScale,
    required this.reduced,
    required this.onReduced,
  });
  final bool reduced;
  final ValueChanged<bool> onReduced;
  final ThemeMode mode;
  final double? scale;
  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<double?> onScale;
  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  bool _switch = true;
  bool _filter = true;
  bool _error = false;
  int _radio = 0;
  int _page = 0;
  double _progress = .4;
  String _result = 'No action taken.';
  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        for (final child in children) ...[child, const SizedBox(height: 12)],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = FiloThemeTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Component gallery')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section('Preview', [
                SwitchListTile(
                  title: const Text('Reduced motion preview'),
                  value: widget.reduced,
                  onChanged: widget.onReduced,
                ),
                DropdownButtonFormField<ThemeMode>(
                  initialValue: widget.mode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: [
                    for (final mode in ThemeMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(switch (mode) {
                          ThemeMode.system => 'System',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                      ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) widget.onMode(mode);
                  },
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final scale in <double?>[null, 1, 1.3])
                      ChoiceChip(
                        label: Text(
                          scale == null
                              ? 'Device text'
                              : '${(scale * 100).round()}%',
                        ),
                        selected: widget.scale == scale,
                        onSelected: (_) => widget.onScale(scale),
                      ),
                  ],
                ),
                const Text(
                  'Local examples only. No account or network requests.',
                ),
              ]),
              _section('Palette', [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in <String, Color>{
                      'Background': Theme.of(context).scaffoldBackgroundColor,
                      'Surface': c.surface,
                      'Surface tint': c.surfaceContainerHighest,
                      'Primary': c.primary,
                      'Primary edge': t.primaryEdge,
                      'Ink': c.onSurface,
                      'Secondary': c.onSurfaceVariant,
                      'Hint': t.hint,
                      'Mint': t.mint,
                      'Mint strong': c.primaryContainer,
                      'Border': c.outline,
                      'Lime': t.lime,
                      'Lime deep': t.limeDeep,
                      'Success': t.success,
                      'Success tint': t.successTint,
                      'Warning': t.warning,
                      'Warning tint': t.warningTint,
                      'Error': c.error,
                      'Error tint': c.errorContainer,
                      'Info': t.info,
                      'Info tint': t.infoTint,
                      'Destructive': t.destructive,
                      'Destructive edge': t.destructiveEdge,
                      'Disabled': t.disabledFill,
                    }.entries)
                      SizedBox(
                        width: 128,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: entry.value,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.outline),
                              ),
                            ),
                            Text(entry.key, style: text.bodySmall),
                            Text(
                              '#${entry.value.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ]),
              _section('Typography', [
                for (final entry in <String, TextStyle?>{
                  'Hero 36 / 44 ? 900': text.headlineLarge,
                  'Display 32 / 40 ? 800': text.headlineMedium,
                  'Title L 22 / 28 ? 700': text.titleLarge,
                  'Title M 18 / 24 ? 700': text.titleMedium,
                  'Body L 16 / 24 ? 400': text.bodyLarge,
                  'Body M 14 / 20 ? 400': text.bodyMedium,
                  'Label 14 / 20 ? 700': text.labelMedium,
                  'Button 16 / 20 ? 800': text.labelLarge,
                  'Caption 12 / 16 ? 500': text.bodySmall,
                }.entries)
                  Text(entry.key, style: entry.value),
                const Text(
                  'Nunito semibold 600',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ]),
              _section('Buttons', [
                FiloButton(
                  label: 'Primary',
                  onPressed: () => showMessage(context, 'Primary tapped.'),
                ),
                FiloButton(
                  label: 'Secondary',
                  secondary: true,
                  onPressed: () => showMessage(context, 'Secondary tapped.'),
                ),
                FiloButton(
                  label: 'Outlined',
                  outlined: true,
                  icon: FiloIcons.add,
                  onPressed: () {},
                ),
                FiloButton(label: 'Text action', text: true, onPressed: () {}),
                FiloButton(
                  label: 'Destructive',
                  destructive: true,
                  onPressed: () => _confirm(),
                ),
                const FiloButton(label: 'Disabled', onPressed: null),
                const FiloButton(label: 'Loading', busy: true, onPressed: null),
                const FiloButton(
                  label: 'Secondary disabled',
                  secondary: true,
                  onPressed: null,
                ),
                const FiloButton(
                  label: 'Outlined disabled',
                  outlined: true,
                  onPressed: null,
                ),
              ]),
              _section('Fields', [
                TextField(
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: _error ? 'Enter a name.' : null,
                  ),
                ),
                const TextField(
                  enabled: false,
                  decoration: InputDecoration(labelText: 'Disabled field'),
                ),
                const TextField(
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: 'Instructions'),
                ),
                const TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Time limit'),
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: 'Multiple choice',
                  decoration: const InputDecoration(labelText: 'Question type'),
                  items: [
                    for (final label in ['Multiple choice', 'True or false'])
                      DropdownMenuItem(
                        value: label,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (_) {},
                ),
                FiloButton(
                  label: _error
                      ? 'Clear validation error'
                      : 'Show validation error',
                  outlined: true,
                  onPressed: () => setState(() => _error = !_error),
                ),
              ]),
              _section('Selection controls', [
                SwitchListTile(
                  title: const Text('Switch'),
                  value: _switch,
                  onChanged: (v) => setState(() => _switch = v),
                ),
                const SwitchListTile(
                  title: Text('Disabled switch'),
                  value: false,
                  onChanged: null,
                ),
                RadioGroup<int>(
                  groupValue: _radio,
                  onChanged: (v) => setState(() => _radio = v!),
                  child: const Column(
                    children: [
                      RadioListTile(value: 0, title: Text('First answer')),
                      RadioListTile(value: 1, title: Text('Second answer')),
                      RadioListTile(
                        value: 2,
                        enabled: false,
                        title: Text('Disabled answer'),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FiloFilterChip(
                      label: 'Filter',
                      selected: _filter,
                      onSelected: (v) => setState(() => _filter = v),
                    ),
                    const FiloFilterChip(
                      label: 'Disabled filter',
                      selected: false,
                      onSelected: null,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, status, icon) in [
                      ('Assigned', FiloStatus.assigned, FiloIcons.checklist),
                      ('Turned in', FiloStatus.success, FiloIcons.check),
                      ('Graded', FiloStatus.success, FiloIcons.checkCircle),
                      ('Late', FiloStatus.error, FiloIcons.clock),
                      ('Missing', FiloStatus.missing, FiloIcons.error),
                      ('In progress', FiloStatus.warning, FiloIcons.clock),
                      ('Not started', FiloStatus.neutral, FiloIcons.circle),
                      ('Draft', FiloStatus.neutral, FiloIcons.document),
                      (
                        'Waiting for approval',
                        FiloStatus.warning,
                        FiloIcons.pending,
                      ),
                      (
                        'Available offline',
                        FiloStatus.success,
                        FiloIcons.cloudReady,
                      ),
                      ('Cloud only', FiloStatus.neutral, FiloIcons.offline),
                      ('Info', FiloStatus.info, FiloIcons.info),
                      ('AI', FiloStatus.ai, FiloIcons.sparkle),
                    ])
                      FiloStatusChip(label: label, icon: icon, status: status),
                  ],
                ),
              ]),
              _section('Cards and empty states', [
                FiloCard(
                  onTap: () => showMessage(context, 'Card tapped.'),
                  child: const ListTile(
                    leading: FiloIcon(FiloIcons.book),
                    title: Text('Study materials'),
                    subtitle: Text('Tap to preview feedback.'),
                  ),
                ),
                const FiloPanel(child: Text('Surface panel')),
                EmptyState(
                  pose: 'waving',
                  title: 'No classes yet.',
                  message: 'Join one with a code.',
                  action: FiloButton(
                    label: 'Join class',
                    onPressed: () =>
                        showMessage(context, 'Gallery example only.'),
                  ),
                ),
                const EmptyState(
                  title: 'No results yet.',
                  message: 'Results will appear here.',
                  showMascot: false,
                ),
              ]),
              _section('Mascot poses', [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final pose in Mascot.poses)
                      SizedBox(
                        width: 140,
                        child: Column(
                          children: [
                            Mascot(pose: pose, size: 96),
                            Text(pose),
                          ],
                        ),
                      ),
                  ],
                ),
                const EmptyState(
                  title: 'No saved content on this device.',
                  pose: 'sleepy',
                  bob: false,
                ),
                EmptyState(
                  title: 'Could not load this example. Try again.',
                  pose: 'confused',
                  bob: false,
                  action: FiloButton(
                    label: 'Retry mascot example',
                    onPressed: () => setState(
                      () => _result = 'Example retry completed locally.',
                    ),
                  ),
                ),
                const EmptyState(title: 'No results yet.', showMascot: false),
              ]),
              _section('Progress and loading', [
                FiloProgressBar(
                  value: _progress,
                  label: 'Example task progress',
                ),
                Slider(
                  value: _progress,
                  label: '${(_progress * 100).round()}%',
                  onChanged: (v) => setState(() => _progress = v),
                ),
                FiloPageIndicator(count: 3, index: _page),
                FiloButton(
                  label: 'Next page indicator',
                  outlined: true,
                  onPressed: () => setState(() => _page = (_page + 1) % 3),
                ),
                const FiloSkeleton(height: 80),
                const FiloSkeleton(width: 160),
              ]),
              _section('Banners and retry', [
                const FiloBanner(),
                FiloBanner(
                  message: 'Could not load this example. Try again.',
                  icon: FiloIcons.info,
                  action: FiloButton(
                    label: 'Retry example',
                    outlined: true,
                    onPressed: () => setState(
                      () => _result = 'Example retry completed locally.',
                    ),
                  ),
                ),
              ]),
              _section('Toasts and overlays', [
                for (final kind in FiloToastKind.values)
                  FiloButton(
                    label: '${kind.name} toast',
                    outlined: true,
                    onPressed: () => showFiloToast(
                      context,
                      'Example ${kind.name} message.',
                      kind: kind,
                    ),
                  ),
                FiloButton(label: 'Open confirmation', onPressed: _confirm),
                FiloButton(
                  label: 'Open notice',
                  secondary: true,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const FiloNoticeDialog(
                      title: 'Example notice',
                      sections: [
                        FiloNoticeSection(
                          heading: 'Your information',
                          body: 'This gallery uses local example content only.',
                        ),
                      ],
                    ),
                  ),
                ),
                FiloButton(
                  label: 'Open bottom sheet',
                  secondary: true,
                  onPressed: () => showFiloBottomSheet<void>(
                    context: context,
                    title: 'Example sheet',
                    builder: (sheetContext) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FiloSheetAction(
                            label: 'Example action',
                            description: 'No files are changed.',
                            icon: FiloIcons.book,
                            onTap: () {},
                          ),
                          const SizedBox(height: 16),
                          const TextField(
                            decoration: InputDecoration(
                              labelText: 'Sheet field',
                            ),
                          ),
                          const SizedBox(height: 24),
                          FiloButton(
                            label: 'Done',
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Semantics(liveRegion: true, child: Text(_result)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final confirmed = await confirmAction(
      context,
      title: 'Remove this example?',
      message: 'This changes only the gallery feedback.',
      action: 'Remove',
    );
    if (mounted)
      setState(
        () => _result = confirmed ? 'Example confirmed.' : 'Example cancelled.',
      );
  }
}
