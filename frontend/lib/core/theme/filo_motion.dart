import 'package:flutter/material.dart';

import 'animation_constants.dart';

abstract final class FiloMotion {
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
}

Future<T?> showFiloDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  AnimationStyle? animationStyle,
}) {
  final motion = FiloMotion.enabled(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    animationStyle: motion ? animationStyle : AnimationStyle.noAnimation,
    builder: (dialog) =>
        FiloMotionScope(enabled: motion, child: builder(dialog)),
  );
}

/// Also covers overlays, native controls and changes to the platform preference.
class FiloMotionScope extends StatefulWidget {
  const FiloMotionScope({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<FiloMotionScope> createState() => _FiloMotionScopeState();
}

class _FiloMotionScopeState extends State<FiloMotionScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => setState(() {});
  @override
  Widget build(BuildContext context) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final reduced =
        !widget.enabled ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.of(context) ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed);
    final theme = Theme.of(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: reduced ? Colors.transparent : theme.highlightColor,
          filledButtonTheme: FilledButtonThemeData(
            style: (theme.filledButtonTheme.style ?? const ButtonStyle())
                .copyWith(animationDuration: Duration.zero),
          ),
          textButtonTheme: TextButtonThemeData(
            style: (theme.textButtonTheme.style ?? const ButtonStyle())
                .copyWith(animationDuration: Duration.zero),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
                .copyWith(animationDuration: Duration.zero),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: (theme.elevatedButtonTheme.style ?? const ButtonStyle())
                .copyWith(animationDuration: Duration.zero),
          ),
          pageTransitionsTheme: reduced
              ? const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: FiloPageTransitions(animate: false),
                    TargetPlatform.iOS: FiloPageTransitions(animate: false),
                    TargetPlatform.linux: FiloPageTransitions(animate: false),
                    TargetPlatform.macOS: FiloPageTransitions(animate: false),
                    TargetPlatform.windows: FiloPageTransitions(animate: false),
                    TargetPlatform.fuchsia: FiloPageTransitions(animate: false),
                  },
                )
              : theme.pageTransitionsTheme,
        ),
        child: widget.child,
      ),
    );
  }
}

class FiloPageTransitions extends PageTransitionsBuilder {
  const FiloPageTransitions({this.animate = true});
  final bool animate;
  @override
  Duration get transitionDuration =>
      animate ? FiloAnimation.pageDuration : Duration.zero;
  @override
  Duration get reverseTransitionDuration => transitionDuration;
  static Widget transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    if (!FiloMotion.enabled(context)) return child;
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final value = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(24 * direction * (1 - value), 0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FiloMotionScope(child: transition(context, animation, child));
}

/// Exam/result destinations have no entrance, exit or inherited decoration.
class FiloInstantRoute<T> extends MaterialPageRoute<T> {
  FiloInstantRoute({required WidgetBuilder builder, super.settings})
    : super(
        builder: (context) =>
            FiloMotionScope(enabled: false, child: builder(context)),
      );
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class FiloInstantDialogRoute<T> extends DialogRoute<T> {
  FiloInstantDialogRoute({
    required super.context,
    required WidgetBuilder builder,
  }) : super(
         builder: (context) =>
             FiloMotionScope(enabled: false, child: builder(context)),
       );
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
