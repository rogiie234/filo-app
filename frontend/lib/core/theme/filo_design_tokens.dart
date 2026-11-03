import 'package:flutter/material.dart';

abstract final class FiloSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const screen = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
}

abstract final class FiloRadii {
  static const small = 12.0;
  static const medium = 20.0;
  static const large = 28.0;
  static const pill = 999.0;
}

abstract final class FiloControlSize {
  static const primary = 56.0;
  static const compact = 48.0;
  static const fileTile = 44.0;
}

/// Fixed paint values are independent of the selected application palette.
abstract final class FiloPaint {
  static const transparent = Color(0x00000000);
  static const mask = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x1014423A);
  static const cardShadowBlur = 12.0;
  static const cardShadowOffset = Offset(0, 4);
  static const bannerPatternOpacity = .06;
  static const bannerScrim = Color(0xB3000000);
  static const bannerScrimEnd = Color(0xD9000000);
  static const bannerInk = Color(0xFF14423A);
}

abstract final class FiloTypography {
  static const emphasis = FontWeight.w800;
  static const strong = FontWeight.w700;
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w600;

  static TextStyle verificationCode(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(letterSpacing: 4);

  static TextStyle wordmark(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!
          .copyWith(fontWeight: FontWeight.w900);

  static TextStyle strongLabel(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: emphasis);
}
