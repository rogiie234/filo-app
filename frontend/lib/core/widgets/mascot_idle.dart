import 'package:flutter/material.dart';

/// Opt in once per visible screen; functional loading indicators are independent.
class MascotIdle extends StatefulWidget {
  const MascotIdle({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<MascotIdle> createState() => _MascotIdleState();
}

class _MascotIdleState extends State<MascotIdle>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant MascotIdle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (widget.enabled &&
        _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_motion.isAnimating) _motion.repeat(reverse: true);
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: widget.child,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -4 * Curves.easeInOut.transform(_motion.value)),
      child: child,
    ),
  );
}
