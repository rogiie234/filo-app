import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/filo_motion.dart';
import '../../core/widgets/filo_widgets.dart';
import 'tutorial_repository.dart';

class TutorialStep {
  const TutorialStep(
    this.title,
    this.message,
    this.pose, {
    this.target,
    this.destination,
  });
  final String title, message, pose;
  final String? target;
  final int? destination;
}

/// Screen-local coach marks never activate the highlighted control.
class TutorialHost extends ConsumerStatefulWidget {
  const TutorialHost({
    super.key,
    required this.id,
    required this.steps,
    required this.targets,
    required this.child,
    this.enabled = true,
    this.ready = true,
    this.replay = 0,
    required this.onDestination,
  });
  final String id;
  final List<TutorialStep> steps;
  final Map<String, GlobalKey> targets;
  final Widget child;
  final bool enabled, ready;
  final int replay;
  final ValueChanged<int> onDestination;

  @override
  ConsumerState<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends ConsumerState<TutorialHost> {
  final _stack = GlobalKey();
  List<TutorialStep>? _steps;
  int _index = 0;
  bool _eligible = false, _saving = false, _measuring = false;
  String? _saveError;
  Rect? _target;
  bool _located = false;
  TutorialRepository? _repository;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _load();
  }

  Future<void> _load() async {
    try {
      final repository = await ref.read(tutorialRepositoryProvider.future);
      final dismissed =
          repository == null || await repository.dismissed(widget.id);
      if (!mounted) return;
      _repository = repository;
      _eligible = !dismissed;
      if (_eligible && widget.ready) _start();
    } catch (_) {
      // A failed local read must not interrupt access to the app; replay remains available.
    }
  }

  @override
  void didUpdateWidget(covariant TutorialHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replay != oldWidget.replay ||
        (_eligible && widget.ready && _steps == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled && widget.ready) _start();
      });
    }
  }

  void _start() {
    if (!mounted || _steps != null || widget.steps.isEmpty) return;
    _eligible = false;
    FocusScope.of(context).unfocus();
    setState(() {
      _steps = List.of(widget.steps);
      _index = 0;
      _saveError = null;
      _located = false;
    });
    _enter();
  }

  void _enter() {
    final destination = _steps![_index].destination;
    if (destination != null) widget.onDestination(destination);
    final index = _index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _steps == null || _index != index) return;
      final target = widget.targets[_steps![index].target]?.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.5);
      _measure();
    });
    _measure();
  }

  void _measure() {
    if (_measuring) return;
    _measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted || _steps == null) return;
      final id = _steps![_index].target;
      final box = widget.targets[id]?.currentContext?.findRenderObject();
      final stack = _stack.currentContext?.findRenderObject();
      Rect? rect;
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          stack is RenderBox &&
          stack.hasSize) {
        final offset = box.localToGlobal(Offset.zero, ancestor: stack);
        final candidate = (offset & box.size).inflate(6);
        final bounds = Offset.zero & stack.size;
        if (bounds.overlaps(candidate)) rect = candidate.intersect(bounds);
      }
      if (!_located || rect != _target) {
        setState(() {
          _target = rect;
          _located = true;
        });
      }
    });
  }

  void _move(int delta) {
    if (_saving) return;
    setState(() {
      _index += delta;
      _located = false;
      _target = null;
      _saveError = null;
    });
    _enter();
  }

  Future<void> _dismiss(bool completed) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final repository =
          _repository ?? await ref.read(tutorialRepositoryProvider.future);
      if (repository == null) throw StateError('Account storage unavailable');
      await repository.dismiss(widget.id, completed: completed);
      if (mounted)
        setState(() {
          _steps = null;
          _saving = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _saveError = 'Could not save your tutorial preference. Try again, or close without saving.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final active = steps != null;
    if (active) _measure();
    final step = active ? steps[_index] : null;
    final missing = step?.target != null && _located && _target == null;
    final duration = FiloMotion.enabled(context)
        ? const Duration(milliseconds: 220)
        : Duration.zero;
    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && active) _dismiss(false);
      },
      child: Stack(
        key: _stack,
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: active,
            child: ExcludeSemantics(
              excluding: active,
              child: AbsorbPointer(absorbing: active, child: widget.child),
            ),
          ),
          if (active) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: TweenAnimationBuilder<Rect?>(
                  duration: duration,
                  tween: RectTween(end: _target ?? Rect.zero),
                  builder: (context, rect, _) => CustomPaint(
                    painter: _Spotlight(
                      _located && _target != null ? rect : null,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final below =
                    _target != null &&
                    _target!.center.dy < constraints.maxHeight / 2;
                final top = below
                    ? _target!.bottom + 16
                    : MediaQuery.paddingOf(context).top + 16;
                final bottom = !below && _target != null
                    ? constraints.maxHeight - _target!.top + 16
                    : MediaQuery.paddingOf(context).bottom + 16;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: duration,
                      left: 24,
                      right: 24,
                      top: top.clamp(
                        MediaQuery.paddingOf(context).top + 16,
                        constraints.maxHeight / 2,
                      ),
                      bottom: bottom.clamp(16, constraints.maxHeight / 2),
                      child: Align(
                        alignment: below
                            ? Alignment.topCenter
                            : Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 8,
                            borderRadius: BorderRadius.circular(28),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: FocusScope(
                                autofocus: true,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      key: const ValueKey('tutorial_content'),
                                      duration: duration,
                                      child: Semantics(
                                        key: ValueKey(_index),
                                        liveRegion: true,
                                        scopesRoute: true,
                                        explicitChildNodes: true,
                                        namesRoute: true,
                                        label: step!.title,
                                        child: Column(
                                          children: [
                                            Mascot(pose: step.pose, size: 80),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Step ${_index + 1} of ${steps.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              step.title,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              step.message,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (missing) ...[
                                      const SizedBox(height: 12),
                                      const Text(
                                        'This control is not available right now. Retry the highlight or skip this step.',
                                      ),
                                      TextButton(
                                        onPressed: _measure,
                                        child: const Text('Retry highlight'),
                                      ),
                                    ],
                                    if (_saveError != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        _saveError!,
                                        semanticsLabel: _saveError,
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _steps = null),
                                        child: const Text(
                                          'Close without saving',
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    FiloButton(
                                      label: _index == steps.length - 1
                                          ? 'Got it'
                                          : _index == 0
                                          ? 'Show me'
                                          : missing
                                          ? 'Skip step'
                                          : 'Next',
                                      busy: _saving,
                                      onPressed: _saving
                                          ? null
                                          : () => _index == steps.length - 1
                                                ? _dismiss(true)
                                                : _move(1),
                                    ),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 16,
                                      children: [
                                        if (_index > 0)
                                          TextButton(
                                            onPressed: _saving
                                                ? null
                                                : () => _move(-1),
                                            child: const Text('Back'),
                                          ),
                                        TextButton(
                                          onPressed: _saving
                                              ? null
                                              : () => _dismiss(false),
                                          child: const Text('Skip tutorial'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Spotlight extends CustomPainter {
  _Spotlight(this.target, this.color);
  final Rect? target;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = target == null
        ? null
        : RRect.fromRectAndRadius(target!, const Radius.circular(16));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (hole != null) path.addRRect(hole);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    if (hole != null)
      canvas.drawRRect(
        hole,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) =>
      target != oldDelegate.target || color != oldDelegate.color;
}
