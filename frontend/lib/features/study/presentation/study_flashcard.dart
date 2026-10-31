import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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

class _StudyFlashcardState extends State<StudyFlashcard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  bool _back = false, _dragging = false;
  double _drag = 0;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) _flip.value = _back ? 1 : 0;
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _turn() {
    if (!widget.enabled || _flip.isAnimating) return;
    setState(() => _back = !_back);
    if (_reduced)
      _flip.value = _back ? 1 : 0;
    else if (_back)
      _flip.forward();
    else
      _flip.reverse();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final width = constraints.maxWidth;
      final amount = (_drag / width).clamp(-1.0, 1.0);
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
              ? (details) => setState(() => _drag += details.delta.dx)
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
            child: AnimatedContainer(
              duration: _reduced || _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              transformAlignment: Alignment.center,
              transform: _reduced
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                      ..translateByDouble(
                        _drag.clamp(-width * .4, width * .4).toDouble(),
                        0,
                        0,
                        1,
                      )
                      ..rotateZ(amount * 8 * math.pi / 180)),
              child: AnimatedBuilder(
                animation: _flip,
                builder: (_, __) {
                  final angle = _flip.value * math.pi;
                  final showBack = _flip.value >= .5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .001)
                      ..rotateY(angle),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 280),
                      height: 360,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: _drag == 0
                            ? FiloColors.surface
                            : _drag > 0
                            ? FiloColors.selected
                            : FiloColors.warning,
                        border: Border.all(
                          color: FiloColors.border,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(showBack ? math.pi : 0),
                        child: Column(
                          children: [
                            Text(
                              showBack ? 'Answer' : 'Question',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            if (_drag != 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _drag > 0
                                        ? Icons.check
                                        : Icons.school_outlined,
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
                                    showBack ? widget.back : widget.front,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              showBack
                                  ? 'Tap to see the question'
                                  : 'Tap to see the answer',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
