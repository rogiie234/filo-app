import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One ordered writer; stale requests cannot restore a previous screen's policy.
abstract final class FiloOrientationPolicy {
  static final _viewers = <Object>{};
  static Future<void> _pending = Future<void>.value();
  static bool examProtected = false;
  static int _revision = 0;

  static Future<void> refresh() {
    final revision = ++_revision;
    _pending = _pending.then((_) async {
      if (revision != _revision) return;
      try {
        await SystemChrome.setPreferredOrientations(
          !examProtected && _viewers.isNotEmpty
              ? <DeviceOrientation>[]
              : [DeviceOrientation.portraitUp],
        );
      } on PlatformException {
        // The OS may refuse orientation requests; content remains usable.
      } on MissingPluginException {
        // Non-Android hosts can still render Filo.
      }
    });
    return _pending;
  }

  static void viewer(Object owner, bool visible) {
    if (visible) {
      _viewers.add(owner);
    } else {
      _viewers.remove(owner);
    }
    unawaited(refresh());
  }
}

/// PageRoute observers ignore popup dialogs, which retain viewer orientation.
class FiloFileViewerOrientation extends StatefulWidget {
  const FiloFileViewerOrientation({super.key, required this.child});
  final Widget child;
  @override
  State<FiloFileViewerOrientation> createState() =>
      _FileViewerOrientationState();
}

class _FileViewerOrientationState extends State<FiloFileViewerOrientation>
    with RouteAware {
  RouteObserver<PageRoute<dynamic>>? _observer;
  PageRoute<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _observer?.unsubscribe(this);
    _route = route is PageRoute<dynamic> ? route : null;
    _observer = Navigator.of(context).widget.observers
        .whereType<RouteObserver<PageRoute<dynamic>>>()
        .firstOrNull;
    if (_route != null && _observer != null) {
      _observer!.subscribe(this, _route!);
    } else {
      FiloOrientationPolicy.viewer(this, true);
    }
  }

  @override
  void didPush() =>
      FiloOrientationPolicy.viewer(this, _route?.isCurrent ?? true);
  @override
  void didPopNext() => FiloOrientationPolicy.viewer(this, true);
  @override
  void didPushNext() => FiloOrientationPolicy.viewer(this, false);
  @override
  void didPop() => FiloOrientationPolicy.viewer(this, false);
  @override
  void dispose() {
    _observer?.unsubscribe(this);
    FiloOrientationPolicy.viewer(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
