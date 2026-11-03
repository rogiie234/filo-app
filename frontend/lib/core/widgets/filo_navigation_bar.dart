import 'package:flutter/material.dart';

import '../theme/animation_constants.dart';
import 'filo_motion_widgets.dart';

/// Native destinations retain their semantics, labels, badges and focus behavior.
class FiloNavigationBar extends StatelessWidget {
  const FiloNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  @override
  Widget build(BuildContext context) => Material(
    color:
        Theme.of(context).navigationBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainer,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final cell = constraints.maxWidth / destinations.length;
        final target =
            (rtl ? destinations.length - 1 - selectedIndex : selectedIndex) *
                cell +
            cell / 2 -
            32;
        return Stack(
          children: [
            Positioned(
              top: 12,
              left: 0,
              child: ExcludeSemantics(
                child: FiloMotionTween(
                  value: target,
                  duration: FiloAnimation.navigationDuration,
                  builder: (_, value, child) => Transform.translate(
                    offset: Offset(value, 0),
                    child: child,
                  ),
                  child: Container(
                    width: 64,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ),
            ),
            NavigationBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: Colors.transparent,
              animationDuration: Duration.zero,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (var i = 0; i < destinations.length; i++)
                  NavigationDestination(
                    label: destinations[i].label,
                    tooltip: destinations[i].tooltip,
                    enabled: destinations[i].enabled,
                    icon: FiloMotionTween(
                      value: selectedIndex == i ? 1 : 0,
                      duration: FiloAnimation.navigationDuration,
                      builder: (_, value, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          ExcludeSemantics(
                            excluding: selectedIndex == i,
                            child: Opacity(
                              opacity: 1 - value,
                              child: destinations[i].icon,
                            ),
                          ),
                          ExcludeSemantics(
                            excluding: selectedIndex != i,
                            child: Opacity(
                              opacity: value,
                              child:
                                  destinations[i].selectedIcon ??
                                  destinations[i].icon,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
