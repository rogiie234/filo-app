import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../features/classes/domain/class_banner.dart';
import '../../features/classes/presentation/class_banner.dart';
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
  final _pendingBannerImage = _GalleryPendingBannerImage();
  final _failedBannerImage = MemoryImage(Uint8List(0));
  int _cardTaps = 0;
  bool _switch = true;
  bool _filter = true;
  bool _error = false;
  int _radio = 0;
  int _page = 0;
  int _navigation = 0, _success = 0, _entrance = 0;
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
                FiloSwitchListTile(
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
                      FiloAnimatedChip(
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
                FiloSwitchListTile(
                  title: const Text('Switch'),
                  value: _switch,
                  onChanged: (v) => setState(() => _switch = v),
                ),
                const FiloSwitchListTile(
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
                    for (final preset in FiloStatusPreset.values)
                      FiloStatusChip.preset(preset),
                    const FiloStatusChip(
                      label: 'Info',
                      icon: FiloIcons.info,
                      status: FiloStatus.info,
                    ),
                  ],
                ),
              ]),
              _section('File types and AI badge', [
                const FiloAiBadge(),
                for (final (name, mime, kind) in [
                  ('Handout.pdf', 'application/pdf', 'file'),
                  ('Photo.png', 'image/png', 'file'),
                  ('Photo.JPEG', 'image/jpeg', 'file'),
                  ('Notes.doc', 'application/msword', 'file'),
                  ('Notes.docx', null, 'file'),
                  ('Slides.ppt', null, 'file'),
                  ('Slides.pptx', null, 'file'),
                  ('Workbook.xls', null, 'file'),
                  ('Workbook.xlsx', null, 'file'),
                  ('Data.csv', null, 'file'),
                  ('Notes.txt', 'text/plain', 'file'),
                  ('Course website', null, 'link'),
                  ('Pasted text', null, 'text'),
                  ('Archive.zip', null, 'file'),
                  ('Readme', null, 'file'),
                  (
                    'An extensionless PDF with a long descriptive filename',
                    'application/pdf',
                    'file',
                  ),
                ])
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FiloFileTypeTile(
                        details: FiloFileDetails.fromName(
                          name,
                          mimeType: mime,
                          kind: kind,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FiloFileTypeLabel(
                              details: FiloFileDetails.fromName(
                                name,
                                mimeType: mime,
                                kind: kind,
                              ),
                            ),
                          ],
                        ),
                      ),
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
              _section('Motion and confirmed feedback', [
                FiloCard(
                  onTap: () => setState(() => _result = 'Card tapped.'),
                  child: const Text('Tap this card - 0.98 scale / 100 ms'),
                ),
                FiloNavigationBar(
                  selectedIndex: _navigation,
                  onDestinationSelected: (value) =>
                      setState(() => _navigation = value),
                  destinations: const [
                    NavigationDestination(
                      icon: FiloIcon(FiloIcons.book),
                      selectedIcon: FiloIcon(FiloIcons.book),
                      label: 'First',
                    ),
                    NavigationDestination(
                      icon: FiloIcon(FiloIcons.folder),
                      selectedIcon: FiloIcon(FiloIcons.folderSelected),
                      label: 'Second',
                    ),
                    NavigationDestination(
                      icon: FiloIcon(FiloIcons.sparkle),
                      selectedIcon: FiloIcon(FiloIcons.sparkleSelected),
                      label: 'Third',
                    ),
                  ],
                ),
                FiloButton(
                  label: 'Preview page slide',
                  outlined: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Page motion preview'),
                        ),
                        body: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FiloButton(
                            label: 'Go back',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                FiloButton(
                  label: 'Replay confirmed success example',
                  outlined: true,
                  onPressed: () {
                    setState(() => _success++);
                    FiloHaptics.confirmed(context);
                  },
                ),
                if (_success > 0)
                  Center(child: FiloSuccessMoment(key: ValueKey(_success))),
                const Text(
                  'Local demonstration only; no work is submitted or graded.',
                ),
                FiloButton(
                  label: 'Replay first six list items',
                  outlined: true,
                  onPressed: () => setState(() => _entrance++),
                ),
                FiloFirstListLoad(
                  key: ValueKey(_entrance),
                  id: 'gallery-entrance-$_entrance',
                  ready: true,
                  child: Column(
                    children: [
                      for (var i = 0; i < 8; i++)
                        FiloListItem(
                          index: i,
                          child: ListTile(
                            title: Text('Entrance item ${i + 1}'),
                          ),
                        ),
                    ],
                  ),
                ),
                FiloCard(
                  onTap: () => setState(() => _cardTaps++),
                  child: Text('Card press feedback: $_cardTaps taps'),
                ),
                const FiloCard(child: Text('Read-only card: no press motion')),
                FiloMotionScope(
                  enabled: false,
                  child: FiloCard(
                    onTap: () {},
                    child: const Text(
                      'Neutral scope - no decorative card motion',
                    ),
                  ),
                ),
                FiloButton(
                  label: 'Preview neutral route',
                  outlined: true,
                  onPressed: () => Navigator.of(context).push(
                    FiloInstantRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Neutral route preview'),
                        ),
                        body: Padding(
                          padding: const EdgeInsets.all(24),
                          child: FiloButton(
                            label: 'Go back',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
              _section('Class banner presets', [
                for (final entry in classBannerColors.entries) ...[
                  Text(
                    '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: ClassBanner(
                      color: entry.value,
                      section: 'BSIT-3A',
                      instructor: 'Alex Rivera',
                    ),
                  ),
                ],
                const Text('Default - nothing chosen'),
                const ClassBanner(
                  section: 'Your classroom',
                  instructor: 'Instructor',
                ),
                const Text('Bright uploaded image preview'),
                const ClassBanner(
                  section: 'A long Section name that wraps on a narrow phone',
                  instructor:
                      'Instructor with a long display name for readability',
                  image: AssetImage('assets/gallery/bright_banner.png'),
                ),
                const Text('Image loading - Forest fallback'),
                ClassBanner(
                  section: 'BSIT-3A',
                  instructor: 'Alex Rivera',
                  image: _pendingBannerImage,
                ),
                const Text('Image error - Forest fallback'),
                ClassBanner(
                  section: 'BSIT-3A',
                  instructor: 'Alex Rivera',
                  image: _failedBannerImage,
                ),
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
                  onPressed: () => showFiloDialog<void>(
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
    if (mounted) {
      setState(
        () => _result = confirmed ? 'Example confirmed.' : 'Example cancelled.',
      );
    }
  }
}

// Keep the gallery offline while exercising the real image loading fallback.
class _GalleryPendingBannerImage
    extends ImageProvider<_GalleryPendingBannerImage> {
  @override
  Future<_GalleryPendingBannerImage> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _GalleryPendingBannerImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
