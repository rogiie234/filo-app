import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/widgets/filo_widgets.dart';
import '../../../core/widgets/entry_background.dart';
import '../application/class_banner_picker.dart';
import '../application/class_providers.dart';
import '../data/class_remote.dart';
import '../domain/class_banner.dart';
import 'class_banner.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});
  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _form = GlobalKey<FormState>();
  final _course = TextEditingController();
  final _section = TextEditingController();
  final _year = TextEditingController();
  String? _banner, _error;
  bool _busy = false;
  bool _writeUnconfirmed = false;
  ClassRow? _created;
  Uint8List? _bannerImage;
  String? _imageExtension;
  String? _uploadPath;
  bool _picking = false;
  bool _bannerSaved = false;

  Future<void> _pickSchoolYear() async {
    FocusScope.of(context).unfocus();
    final currentYear = DateTime.now().year;
    final parts = _year.text.split('-');
    var start = int.tryParse(parts.first) ?? currentYear;
    if (start < currentYear || start >= currentYear + 100) start = currentYear;
    var end = parts.length == 2
        ? int.tryParse(parts.last) ?? start + 1
        : start + 1;
    if (end <= start || end > start + 100) end = start + 1;
    final range = await showFiloDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateSelection) {
          Widget yearColumn(String label, bool starting) => Expanded(
            child: _SchoolYearWheel(
              key: ValueKey(
                starting ? 'starting-year-wheel' : 'ending-year-wheel-$start',
              ),
              label: label,
              firstYear: starting ? currentYear : start + 1,
              selectedYear: starting ? start : end,
              onChanged: (year) => updateSelection(() {
                if (starting) {
                  start = year;
                  if (end <= start || end > start + 100) end = start + 1;
                } else {
                  end = year;
                }
              }),
            ),
          );
          return AlertDialog(
            title: const Text('School year'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Starting year',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Text(
                          'Ending year',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FiloSpacing.s8),
                  SizedBox(
                    height:
                        (MediaQuery.textScalerOf(context).scale(24) + 24) * 3,
                    child: Row(
                      children: [
                        yearColumn('Starting year', true),
                        SizedBox(
                          width: 32,
                          child: ExcludeSemantics(
                            child: Text(
                              '-',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        yearColumn('Ending year', false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, '$start-$end'),
                child: const Text('Use school year'),
              ),
            ],
          );
        },
      ),
    );
    if (range != null && mounted) setState(() => _year.text = range);
  }

  Future<void> _pickBanner() async {
    setState(() => _picking = true);
    try {
      await pickClassBanner((bytes, extension) {
        if (!mounted) return;
        setState(() {
          _bannerImage = bytes;
          _imageExtension = extension;
          _error = null;
        });
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not open this image. Try choosing another banner.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _course.dispose();
    _section.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy ||
        _picking ||
        ref.read(connectivityProvider).asData?.value != true) {
      return;
    }
    if (_created == null && !validateFiloForm(_form)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = await ref.read(classRepositoryProvider.future);
      if (repository == null) throw StateError('Sign in required');
      _created ??= await repository.createClass(
        course: _course.text,
        section: _section.text,
        schoolYear: _year.text,
        bannerColor: _banner,
      );
      // Storage requires an existing owned class. Retain its ID across retries
      // so an upload or cache failure never creates a second class.
      if (_bannerImage != null && !_bannerSaved) {
        final client = ref.read(supabaseClientProvider);
        final id = _created!['id'] as String;
        _uploadPath ??=
            '$id/banner-${DateTime.now().microsecondsSinceEpoch}.$_imageExtension';
        await client.storage
            .from('banners')
            .uploadBinary(
              _uploadPath!,
              _bannerImage!,
              fileOptions: FileOptions(
                upsert: true,
                contentType:
                    'image/${_imageExtension == 'jpg' ? 'jpeg' : _imageExtension}',
              ),
            );
        await client
            .from('classes')
            .update({'banner_path': _uploadPath, 'banner_color': null})
            .eq('id', id);
        _bannerSaved = true;
      }
      await repository.sync();
      if (mounted) Navigator.pop(context, _created!['id'] as String);
    } catch (error) {
      if (mounted) {
        setState(() {
          _writeUnconfirmed = _created == null && error is! PostgrestException;
          _error = _created != null
              ? _bannerImage != null && !_bannerSaved
                    ? 'Your class was created, but its banner could not be saved. Retry to finish, or go back to your classes.'
                    : 'Your class was created, but we could not load its saved copy. Retry to load it.'
              : _writeUnconfirmed
              ? 'We could not confirm whether your class was created. Go back and refresh your classes before trying again.'
              : 'Could not create your class. Check your details and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).asData?.value == true;
    final editable =
        !_busy && !_picking && _created == null && !_writeUnconfirmed;
    return PopScope(
      canPop: !_busy && !_picking,
      child: EntryBackground(
        verification: true,
        breeze: true,
        variation: 4,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text('Create class'),
            leading: IconButton(
              tooltip: 'Back to classes',
              onPressed: _busy || _picking
                  ? null
                  : () => Navigator.pop(context),
              icon: const FiloIcon(FiloIcons.back),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 8,
                right: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(100, 88),
                      painter: _BreezeLeafPainter(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Form(
                key: _form,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (!online) ...[
                      const Text('Connect to the internet to create a class.'),
                      const SizedBox(height: FiloSpacing.s16),
                    ],
                    Text(
                      'A new place to grow.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: FiloSpacing.s8),
                    Text(
                      'Add your class details, then choose a banner.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: FiloSpacing.screen),
                    Text(
                      'Class details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: FiloSpacing.s16),
                    TextFormField(
                      controller: _course,
                      enabled: editable,
                      textInputAction: TextInputAction.next,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Course'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a course.'
                          : null,
                    ),
                    const SizedBox(height: FiloSpacing.s16),
                    TextFormField(
                      controller: _section,
                      textCapitalization: TextCapitalization.characters,
                      enabled: editable,
                      textInputAction: TextInputAction.next,
                      maxLength: 60,
                      decoration: const InputDecoration(labelText: 'Section'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a section.'
                          : null,
                    ),
                    const SizedBox(height: FiloSpacing.s16),
                    TextFormField(
                      controller: _year,
                      enabled: editable,
                      readOnly: true,
                      onTap: editable ? _pickSchoolYear : null,
                      decoration: const InputDecoration(
                        labelText: 'School year',
                        hintText: 'Select school year',
                        suffixIcon: FiloIcon(FiloIcons.calendar),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Select a school year.'
                          : null,
                    ),
                    const SizedBox(height: FiloSpacing.screen),
                    Text(
                      'Class card preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: FiloSpacing.s12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FiloRadii.large),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_section, _course]),
                        builder: (context, _) => Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              FiloRadii.large,
                            ),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClassBanner(
                                section: _section.text.trim().isEmpty
                                    ? 'Your classroom'
                                    : _section.text.trim().toUpperCase(),
                                instructor: 'Instructor',
                                compact: true,
                                color: classBannerColor(_banner),
                                image: _bannerImage == null
                                    ? null
                                    : MemoryImage(_bannerImage!),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(FiloSpacing.s20),
                                child: Row(
                                  children: [
                                    FiloIcon(
                                      FiloIcons.book,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(width: FiloSpacing.s12),
                                    Expanded(
                                      child: Text(
                                        _course.text.trim().isEmpty
                                            ? 'Course name'
                                            : _course.text.trim(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: FiloSpacing.s12),
                                    const ExcludeSemantics(
                                      child: FiloIcon(FiloIcons.forward),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: FiloSpacing.screen),
                    Text(
                      'Banner',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: FiloSpacing.s12),
                    FiloPanel(
                      padding: const EdgeInsets.all(FiloSpacing.s12),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final key in <String?>[
                              null,
                              ...classBannerColors.keys,
                            ])
                              SizedBox(
                                width: (constraints.maxWidth - 16) / 3,
                                child: Semantics(
                                  selected:
                                      _banner == key && _bannerImage == null,
                                  inMutuallyExclusiveGroup: true,
                                  child: OutlinedButton(
                                    onPressed: editable
                                        ? () => setState(() {
                                            _banner = key;
                                            _bannerImage = null;
                                          })
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 88),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 12,
                                      ),
                                      backgroundColor:
                                          _banner == key && _bannerImage == null
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                          : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                      side: BorderSide(
                                        width:
                                            _banner == key &&
                                                _bannerImage == null
                                            ? 2
                                            : 1,
                                        color:
                                            _banner == key &&
                                                _bannerImage == null
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          FiloRadii.medium,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ExcludeSemantics(
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Color(
                                              classBannerColor(key),
                                            ),
                                            child:
                                                _banner == key &&
                                                    _bannerImage == null
                                                ? Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color:
                                                        ClassBanner.foreground(
                                                          classBannerColor(key),
                                                        ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          key == null
                                              ? 'Default'
                                              : '${key[0].toUpperCase()}${key.substring(1)}',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: FiloSpacing.s12),
                    FiloButton(
                      outlined: true,
                      minHeight: 48,
                      onPressed: editable ? _pickBanner : null,
                      leading: FiloIcon(
                        FiloIcons.addImage,
                        color: editable
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      label: _picking
                          ? 'Opening photos\u2026'
                          : 'Upload banner image',
                      labelVariants: const [
                        'Opening photos\u2026',
                        'Upload banner image',
                      ],
                    ),
                    const SizedBox(height: FiloSpacing.s8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        ExcludeSemantics(
                          child: FiloIcon(
                            FiloIcons.info,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'JPG, PNG or WebP \u00b7 Max 2 MB',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: FiloSpacing.s16),
                    const SizedBox(height: FiloSpacing.s8),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: FiloSpacing.s16),
                        child: Semantics(
                          liveRegion: true,
                          child: FiloPanel(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: FiloSpacing.screen),
                    FiloButton(
                      label: _busy
                          ? 'Creating…'
                          : _writeUnconfirmed
                          ? 'Back to classes'
                          : _created == null
                          ? 'Create class'
                          : _bannerImage != null && !_bannerSaved
                          ? 'Retry saving banner'
                          : 'Retry loading class',
                      minHeight: 64,
                      busy: _busy,
                      icon: _busy ? null : FiloIcons.add,
                      onPressed: _busy || _picking
                          ? null
                          : _writeUnconfirmed
                          ? () => Navigator.pop(context)
                          : !online
                          ? null
                          : _create,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreezeLeafPainter extends CustomPainter {
  const _BreezeLeafPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(8, 70)
        ..cubicTo(55, 74, 70, 48, 47, 46)
        ..cubicTo(29, 44, 39, 61, 61, 43),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(25, 79)
        ..quadraticBezierTo(53, 79, 69, 61),
      paint,
    );
    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: .22);
    canvas.drawPath(
      Path()
        ..moveTo(62, 39)
        ..cubicTo(55, 18, 70, 9, 91, 15)
        ..cubicTo(86, 36, 74, 44, 62, 39)
        ..close(),
      paint,
    );
    paint
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: .26);
    canvas.drawPath(
      Path()
        ..moveTo(58, 45)
        ..quadraticBezierTo(72, 31, 84, 20),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BreezeLeafPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _SchoolYearWheel extends StatefulWidget {
  const _SchoolYearWheel({
    super.key,
    required this.label,
    required this.firstYear,
    required this.selectedYear,
    required this.onChanged,
  });
  final String label;
  final int firstYear, selectedYear;
  final ValueChanged<int> onChanged;

  @override
  State<_SchoolYearWheel> createState() => _SchoolYearWheelState();
}

class _SchoolYearWheelState extends State<_SchoolYearWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.selectedYear - widget.firstYear,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: CupertinoPicker(
      scrollController: _controller,
      squeeze: 1,
      diameterRatio: 100,
      itemExtent: MediaQuery.textScalerOf(context).scale(24) + 24,
      onSelectedItemChanged: (index) =>
          widget.onChanged(widget.firstYear + index),
      children: [
        for (var index = 0; index < 100; index++)
          Center(
            child: Text(
              '${widget.firstYear + index}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
      ],
    ),
  );
}
