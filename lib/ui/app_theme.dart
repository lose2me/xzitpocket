import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../models/app_settings.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static final light = lightFor(AppThemeColor.rose);
  static final dark = darkFor(AppThemeColor.rose);

  static FThemeData lightFor(AppThemeColor themeColor) {
    final primary = themeColor.lightColor;
    return _build(
      debugLabel: 'XZIT Pocket Light',
      colors: FColors.neutralLight.copyWith(
        barrier: const Color(0x520F172A),
        background: const Color(0xFFF8FAFC),
        foreground: const Color(0xFF0F172A),
        primary: primary,
        primaryForeground: const Color(0xFFFFFFFF),
        secondary: Color.lerp(Colors.white, primary, 0.08)!,
        secondaryForeground: primary,
        muted: const Color(0xFFF1F5F9),
        mutedForeground: const Color(0xFF526176),
        destructive: const Color(0xFFB91C1C),
        destructiveForeground: const Color(0xFFFFFFFF),
        error: const Color(0xFFB91C1C),
        errorForeground: const Color(0xFFFFFFFF),
        card: const Color(0xFFFFFFFF),
        border: const Color(0xFFE2E8F0),
        extensions: const [
          AppSemanticColors(
            controlBorder: Color(0xFF94A3B8),
            success: Color(0xFF15803D),
            successContainer: Color(0xFFDCFCE7),
            onSuccessContainer: Color(0xFF14532D),
            warning: Color(0xFFA16207),
            warningContainer: Color(0xFFFEF3C7),
            onWarningContainer: Color(0xFF78350F),
            info: Color(0xFF1D4ED8),
            infoContainer: Color(0xFFDBEAFE),
            onInfoContainer: Color(0xFF1E3A8A),
            timetableForeground: Color(0xFF172033),
            timetableMutedForeground: Color(0xFF475569),
          ),
        ],
      ),
    );
  }

  static FThemeData darkFor(AppThemeColor themeColor) {
    final primary = themeColor.darkColor;
    const card = Color(0xFF111827);
    return _build(
      debugLabel: 'XZIT Pocket Dark',
      colors: FColors.neutralDark.copyWith(
        barrier: const Color(0xB3000000),
        background: const Color(0xFF0B1120),
        foreground: const Color(0xFFF8FAFC),
        primary: primary,
        primaryForeground: const Color(0xFF0F172A),
        secondary: Color.lerp(card, primary, 0.16)!,
        secondaryForeground: primary,
        muted: const Color(0xFF1E293B),
        mutedForeground: const Color(0xFFA8B3C5),
        destructive: const Color(0xFFF87171),
        destructiveForeground: const Color(0xFF450A0A),
        error: const Color(0xFFF87171),
        errorForeground: const Color(0xFF450A0A),
        card: card,
        border: const Color(0xFF334155),
        extensions: const [
          AppSemanticColors(
            controlBorder: Color(0xFF64748B),
            success: Color(0xFF4ADE80),
            successContainer: Color(0xFF14532D),
            onSuccessContainer: Color(0xFFDCFCE7),
            warning: Color(0xFFFBBF24),
            warningContainer: Color(0xFF451A03),
            onWarningContainer: Color(0xFFFEF3C7),
            info: Color(0xFF60A5FA),
            infoContainer: Color(0xFF172554),
            onInfoContainer: Color(0xFFDBEAFE),
            timetableForeground: Color(0xFFE5E7EB),
            timetableMutedForeground: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  /*
   * The palette follows the same role split used by mainstream design
   * systems: neutral surfaces carry hierarchy, one brand color carries
   * interaction, and status colors keep stable meanings across themes.
   */

  static FThemeData _build({
    required String debugLabel,
    required FColors colors,
  }) {
    final inheritedTypography = FTypography.inherit(
      colors: colors,
      touch: true,
    );
    final typeface = inheritedTypography.body.copyWith(
      xs2: inheritedTypography.body.xs2.copyWith(
        fontSize: 12,
        height: 4 / 3,
        letterSpacing: 0,
      ),
      xs: inheritedTypography.body.xs.copyWith(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0,
      ),
      sm: inheritedTypography.body.sm.copyWith(
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0,
      ),
      md: inheritedTypography.body.md.copyWith(
        fontSize: 18,
        height: 26 / 18,
        letterSpacing: 0,
      ),
      lg: inheritedTypography.body.lg.copyWith(
        fontSize: 20,
        height: 1.4,
        letterSpacing: 0,
      ),
      xl: inheritedTypography.body.xl.copyWith(
        fontSize: 22,
        height: 28 / 22,
        letterSpacing: 0,
      ),
    );
    final typography = inheritedTypography.copyWith(
      display: typeface,
      body: typeface,
    );
    final inheritedStyle = FStyle.inherit(
      colors: colors,
      typography: typography,
      touch: true,
    );
    final style = FStyle(
      formFieldStyle: inheritedStyle.formFieldStyle,
      focusedOutlineStyle: inheritedStyle.focusedOutlineStyle,
      iconStyle: inheritedStyle.iconStyle,
      sizes: inheritedStyle.sizes,
      tappableStyle: inheritedStyle.tappableStyle,
      borderRadius: const FBorderRadius(
        xs2: BorderRadius.all(Radius.circular(4)),
        xs: BorderRadius.all(Radius.circular(6)),
        sm: BorderRadius.all(Radius.circular(8)),
        md: BorderRadius.all(Radius.circular(8)),
        lg: BorderRadius.all(Radius.circular(12)),
        xl: BorderRadius.all(Radius.circular(16)),
        xl2: BorderRadius.all(Radius.circular(18)),
        xl3: BorderRadius.all(Radius.circular(20)),
      ),
      pagePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );
    final textFieldStyles = FTextFieldSizeStyles.inherit(
      colors: colors.copyWith(border: colors.semantic.controlBorder),
      typography: typography,
      style: style,
      touch: true,
    );
    return FThemeData(
      touch: true,
      icons: const FIcons.lucide(),
      debugLabel: debugLabel,
      colors: colors,
      typography: typography,
      style: style,
      textFieldStyles: textFieldStyles,
    );
  }
}
