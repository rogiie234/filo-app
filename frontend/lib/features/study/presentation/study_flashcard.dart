import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/filo_motion.dart';
import '../../../core/widgets/filo_motion_widgets.dart';

class StudyFlashcard extends StatefulWidget {
  const StudyFlashcard({
    super.key,
    required this.front,
    required this.back,
    required this.number,
    required this.total,
    required this.enabled,
    required this.onMark,
  });
  final String front, back;
  final int number, total;
  final bool enabled;
  final ValueChanged<String> onMark;
  @override
  State<StudyFlashcard> createState() => _StudyFlashcardState();
}

class _StudyFlashcardState extends State<StudyFlashcard> {
  bool _back = false, _dragging = false;
  double _drag = 0;
  void _turn() {
    if (widget.enabled) setState(() => _back = !_back);
  }

  @override
  void didUpdateWidget(StudyFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _drag = 0;
      _dragging = false;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final width = constraints.maxWidth;
      final motion = FiloMotion.enabled(context);
      return Semantics(
        container: true,
        button: true,
        enabled: widget.enabled,
        label:
            'Card ${widget.number} of ${widget.total}. ${_back ? 'Answer' : 'Question'}. ${_back ? widget.back : widget.front}',
        hint: _back ? 'Tap to show question' : 'Tap to show answer',
        onTap: widget.enabled ? _turn : null,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.enabled ? _turn : null,
          onHorizontalDragStart: widget.enabled
              ? (_) => setState(() => _dragging = true)
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (event) => setState(() => _drag += event.delta.dx)
              : null,
          onHorizontalDragCancel: () => setState(() {
            _drag = 0;
            _dragging = false;
          }),
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  final marked = _drag.abs() >= (width * .25).clamp(60, 140);
                  final status = _drag > 0 ? 'known' : 'learning';
                  setState(() {
                    _drag = 0;
                    _dragging = false;
                  });
                  if (marked) widget.onMark(status);
                }
              : null,
          child: RepaintBoundary(
            child: FiloMotionTween(
              value: motion
                  ? _drag.clamp(-width * .4, width * .4).toDouble()
                  : 0,
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              builder: (_, value, child) =>
                  Transform.translate(offset: Offset(value, 0), child: child),
              child: Container(
                constraints: const BoxConstraints(minHeight: 280),
                height: 360,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: _drag == 0
                      ? Theme.of(context).colorScheme.surface
                      : _drag > 0
                      ? Theme.of(context).colorScheme.primaryContainer
                      : FiloThemeTokens.of(context).warningTint,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  key: ValueKey(!motion),
                  duration: motion
                      ? const Duration(milliseconds: 300)
                      : Duration.zero,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final child in previous)
                        ExcludeSemantics(child: child),
                      if (current != null) current,
                    ],
                  ),
                  child: Column(
                    key: ValueKey(_back),
                    children: [
                      Text(
                        _back ? 'Answer' : 'Question',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (_drag != 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _drag > 0 ? Icons.check : Icons.school_outlined,
                            ),
                            const SizedBox(width: 8),
                            Text(_drag > 0 ? 'Got it' : 'Still learning'),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Text(
                              _back ? widget.back : widget.front,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _back
                            ? 'Tap to see the question'
                            : 'Tap to see the answer',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
