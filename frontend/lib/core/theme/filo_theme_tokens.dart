import 'package:flutter/material.dart';

@immutable
class FiloThemeTokens extends ThemeExtension<FiloThemeTokens> {
  const FiloThemeTokens({
    required this.primaryEdge,
    required this.mint,
    required this.lime,
    required this.limeDeep,
    required this.onLime,
    required this.hint,
    required this.controlBorder,
    required this.disabledFill,
    required this.disabledInk,
    required this.disabledBorder,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.info,
    required this.infoTint,
    required this.destructive,
    required this.destructiveEdge,
    required this.onDestructive,
  });
  final Color primaryEdge;
  final Color mint;
  final Color lime;
  final Color limeDeep;
  final Color onLime;
  final Color hint;
  final Color controlBorder;
  final Color disabledFill;
  final Color disabledInk;
  final Color disabledBorder;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color info;
  final Color infoTint;
  final Color destructive;
  final Color destructiveEdge;
  final Color onDestructive;
  static const light = FiloThemeTokens(
    primaryEdge: Color(0xFF1A5444),
    mint: Color(0xFFDCE9DA),
    lime: Color(0xFFE0F0A6),
    limeDeep: Color(0xFFBCD27A),
    onLime: Color(0xFF14423A),
    hint: Color(0xFF5F716A),
    controlBorder: Color(0xFF6E7E73),
    disabledFill: Color(0xFFE2E8E2),
    disabledInk: Color(0xFF4F625A),
    disabledBorder: Color(0xFFCCD7CE),
    success: Color(0xFF1B6E45),
    successTint: Color(0xFFE2F2E8),
    warning: Color(0xFF8A5200),
    warningTint: Color(0xFFFFF1D6),
    info: Color(0xFF265F8F),
    infoTint: Color(0xFFE1EEF8),
    destructive: Color(0xFFC9372C),
    destructiveEdge: Color(0xFF9E2A21),
    onDestructive: Color(0xFFFFFFFF),
  );
  static const dark = FiloThemeTokens(
    primaryEdge: Color(0xFF3A8F72),
    mint: Color(0xFF1F3A31),
    lime: Color(0xFFD4E69A),
    limeDeep: Color(0xFFBCD27A),
    onLime: Color(0xFF14423A),
    hint: Color(0xFF8FA399),
    controlBorder: Color(0xFF78978A),
    disabledFill: Color(0xFF1B2B26),
    disabledInk: Color(0xFFA9BDB3),
    disabledBorder: Color(0xFF2B3F38),
    success: Color(0xFF7FD4A6),
    successTint: Color(0xFF173528),
    warning: Color(0xFFF2C46B),
    warningTint: Color(0xFF3A2D12),
    info: Color(0xFF8DBBE6),
    infoTint: Color(0xFF162B3D),
    destructive: Color(0xFFF0A096),
    destructiveEdge: Color(0xFFB3382C),
    onDestructive: Color(0xFF3D1E1A),
  );
  static FiloThemeTokens of(BuildContext context) =>
      Theme.of(context).extension<FiloThemeTokens>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  FiloThemeTokens copyWith({
    Color? primaryEdge,
    Color? mint,
    Color? lime,
    Color? limeDeep,
    Color? onLime,
    Color? hint,
    Color? controlBorder,
    Color? disabledFill,
    Color? disabledInk,
    Color? disabledBorder,
    Color? success,
    Color? successTint,
    Color? warning,
    Color? warningTint,
    Color? info,
    Color? infoTint,
    Color? destructive,
    Color? destructiveEdge,
    Color? onDestructive,
  }) => FiloThemeTokens(
    primaryEdge: primaryEdge ?? this.primaryEdge,
    mint: mint ?? this.mint,
    lime: lime ?? this.lime,
    limeDeep: limeDeep ?? this.limeDeep,
    onLime: onLime ?? this.onLime,
    hint: hint ?? this.hint,
    controlBorder: controlBorder ?? this.controlBorder,
    disabledFill: disabledFill ?? this.disabledFill,
    disabledInk: disabledInk ?? this.disabledInk,
    disabledBorder: disabledBorder ?? this.disabledBorder,
    success: success ?? this.success,
    successTint: successTint ?? this.successTint,
    warning: warning ?? this.warning,
    warningTint: warningTint ?? this.warningTint,
    info: info ?? this.info,
    infoTint: infoTint ?? this.infoTint,
    destructive: destructive ?? this.destructive,
    destructiveEdge: destructiveEdge ?? this.destructiveEdge,
    onDestructive: onDestructive ?? this.onDestructive,
  );

  @override
  FiloThemeTokens lerp(covariant FiloThemeTokens? other, double t) {
    if (other == null) return this;
    return FiloThemeTokens(
      primaryEdge: Color.lerp(primaryEdge, other.primaryEdge, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      lime: Color.lerp(lime, other.lime, t)!,
      limeDeep: Color.lerp(limeDeep, other.limeDeep, t)!,
      onLime: Color.lerp(onLime, other.onLime, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      disabledInk: Color.lerp(disabledInk, other.disabledInk, t)!,
      disabledBorder: Color.lerp(disabledBorder, other.disabledBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoTint: Color.lerp(infoTint, other.infoTint, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveEdge: Color.lerp(destructiveEdge, other.destructiveEdge, t)!,
      onDestructive: Color.lerp(onDestructive, other.onDestructive, t)!,
    );
  }
}
