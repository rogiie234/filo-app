import 'package:flutter/material.dart';

import '../theme/filo_theme_tokens.dart';

/// Use viewport width rather than the space left by each page's footer.
/// Navigation never changes the artwork scale; idle motion is an opt-in wrapper.
double entryMascotSize(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 240.0).toDouble();

/// Shared viewport spacing keeps the hero aligned independently of each footer.
EdgeInsets entryContentPadding(BuildContext context) => EdgeInsets.fromLTRB(
  24,
  24.0 +
      ((MediaQuery.sizeOf(context).height - 600) * .12)
          .clamp(0.0, 56.0)
          .toDouble(),
  24,
  24,
);

class EntryMascot extends StatelessWidget {
  const EntryMascot({super.key, this.pose = 'waving'});
  final String pose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mint = FiloThemeTokens.of(context).mint;
    final size = entryMascotSize(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color.lerp(mint, colors.surface, .25)!, mint],
          ),
          border: Border.all(
            color: colors.primary.withValues(alpha: .2),
            width: 6,
          ),
        ),
        child: Image.asset(
          'assets/mascots/entry/$pose.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
