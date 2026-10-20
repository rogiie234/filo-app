import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared Filo component and entry motion tokens. Smaller opacity/distance/scale deltas mean less motion.
abstract final class FiloAnimation {
  static const sheetDuration = Duration(milliseconds: 300);
  static const sheetReverseDuration = Duration(milliseconds: 300);
  static const iconDuration = Duration(milliseconds: 300);
  static const iconSwapScale = .9;
  static const iconSelectionScale = .75;
  static const uiDuration = Duration(milliseconds: 400);
  static const roleCardStagger = Duration(milliseconds: 80);
  static const roleEntranceOffset = 8.0;
  static const roleCardPressScale = .99;
  static const roleCardEdge = 3.0;
  static const loadingCycle = Duration(milliseconds: 1800);
  static const loadingDotTravel = 4.0;
  static const loadingDotOpacity = .4;
  static const loadingDotColor = FiloColors.primary;
  static const textDuration = Duration(milliseconds: 420);
  static const buttonEntranceDelay = Duration(milliseconds: 200);
  static const labelRise = 2.0;
  static const labelDuration = Duration(milliseconds: 400);
  // Old label leaves during the first half; new label enters in the second.
  static const labelInCurve = Interval(.5, 1, curve: Curves.easeOutCubic);
  static const labelOutCurve = Interval(.5, 1, curve: Curves.easeInOut);
  static const signInTransitionDuration = Duration(milliseconds: 400);
  static const signInTransitionCurve = Curves.easeInOut;
  static const primaryLabel = Colors.white;
  static const secondaryLabel = FiloColors.ink;
  static const pressOverlay = Colors.transparent;
  static const subtitleDelay = Duration(milliseconds: 100);
  static const skipDuration = Duration(milliseconds: 500);
  static const pressDuration = Duration(milliseconds: 300);
  static const indicatorDuration = Duration(milliseconds: 400);
  static const backgroundDuration = Duration(seconds: 16);
  static const idlePulseDuration = Duration(seconds: 8);
  static const uiCurve = Curves.easeOutCubic;
  static const ambientCurve = Curves.easeInOut;

  static const textRise = 10.0;
  static const pressScale = .97;
  static const pressDepth = 3.0;
  static const buttonEdgeDepth = 4.0;
  static const pressedEdgeDepth = 1.0;
  static const arrowNudge = 3.0;
  static const idlePulseScale = 1.006;
  static const shadowColor = Color(0x14236B57);
  static const shadowBlur = 6.0;
  static const pressedShadowBlur = 2.0;
  static const shadowOffset = Offset(0, 3);
  static const pressedShadowOffset = Offset(0, 1);

  static const backgroundMint = Color(0xFFDCE9DA);
  static const backgroundYellow = Color(0xFFF5EAB2);
  static const backgroundOpacity = .20;
  static const backgroundDrift = 16.0;
  static const backgroundBlobRadius = 68.0;
  static const indicatorActive = FiloColors.primary;
  static const indicatorInactive = FiloColors.mint;
}
