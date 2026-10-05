import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../models/app_settings.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static final light = lightFor(AppThemeColor.teal);
  static final dark = darkFor(AppThemeColor.teal);

  static FThemeData lightFor(
    AppThemeColor themeColor, {
    Color? customColor,
    AppPageBackgroundColor? pageBackgroundColor,
    Color? customPageBackgroundColor,
  }) {
    final primary = customColor == null
        ? themeColor.lightColor
        : ColorScheme.fromSeed(
            seedColor: customColor,
            brightness: Brightness.light,
          ).primary;
    final background =
        customPageBackgroundColor ??
        pageBackgroundColor?.lightColor ??
        const Color(0xFFF7F9FA);
    final card =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFFFFFFFF)
        : Color.lerp(background, Colors.white, 0.58)!;
    final muted =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFFEEF2F3)
        : Color.lerp(background, primary, 0.06)!;
    final border =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFFD7E0E3)
        : Color.lerp(background, const Color(0xFF182126), 0.14)!;
    final controlBorder =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFF7A8B92)
        : Color.lerp(background, const Color(0xFF182126), 0.32)!;
    return _build(
      debugLabel: 'XZIT Pocket Light',
      colors: FColors.neutralLight.copyWith(
        barrier: const Color(0x520F172A),
        background: background,
        foreground: const Color(0xFF182126),
        primary: primary,
        primaryForeground: const Color(0xFFFFFFFF),
        secondary: Color.lerp(background, primary, 0.10)!,
        secondaryForeground: primary,
        muted: muted,
        mutedForeground: const Color(0xFF58686F),
        destructive: const Color(0xFFB91C1C),
        destructiveForeground: const Color(0xFFFFFFFF),
        error: const Color(0xFFB91C1C),
        errorForeground: const Color(0xFFFFFFFF),
        card: card,
        border: border,
        extensions: [
          AppSemanticColors(
            controlBorder: controlBorder,
            success: const Color(0xFF15803D),
            successContainer: const Color(0xFFDCFCE7),
            onSuccessContainer: const Color(0xFF14532D),
            warning: const Color(0xFFA16207),
            warningContainer: const Color(0xFFFEF3C7),
            onWarningContainer: const Color(0xFF78350F),
            info: const Color(0xFF1D4ED8),
            infoContainer: const Color(0xFFDBEAFE),
            onInfoContainer: const Color(0xFF1E3A8A),
            timetableForeground: const Color(0xFF172033),
            timetableMutedForeground: const Color(0xFF475569),
          ),
        ],
      ),
    );
  }

  static FThemeData darkFor(
    AppThemeColor themeColor, {
    Color? customColor,
    AppPageBackgroundColor? pageBackgroundColor,
    Color? customPageBackgroundColor,
  }) {
    final primary = customColor == null
        ? themeColor.darkColor
        : ColorScheme.fromSeed(
            seedColor: customColor,
            brightness: Brightness.dark,
          ).primary;
    final background = customPageBackgroundColor == null
        ? pageBackgroundColor?.darkColor ?? const Color(0xFF0E1417)
        : ColorScheme.fromSeed(
            seedColor: customPageBackgroundColor,
            brightness: Brightness.dark,
          ).surface;
    final card =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFF151D21)
        : Color.lerp(background, Colors.white, 0.08)!;
    final muted =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFF1D292D)
        : Color.lerp(background, Colors.white, 0.12)!;
    final border =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFF304047)
        : Color.lerp(background, Colors.white, 0.22)!;
    final controlBorder =
        pageBackgroundColor == null && customPageBackgroundColor == null
        ? const Color(0xFF71868F)
        : Color.lerp(background, Colors.white, 0.36)!;
    return _build(
      debugLabel: 'XZIT Pocket Dark',
      colors: FColors.neutralDark.copyWith(
        barrier: const Color(0xB3000000),
        background: background,
        foreground: const Color(0xFFE8EEF0),
        primary: primary,
        primaryForeground: const Color(0xFF0F172A),
        secondary: Color.lerp(card, primary, 0.16)!,
        secondaryForeground: primary,
        muted: muted,
        mutedForeground: const Color(0xFFA5B6BC),
        destructive: const Color(0xFFF87171),
        destructiveForeground: const Color(0xFF450A0A),
        error: const Color(0xFFF87171),
        errorForeground: const Color(0xFF450A0A),
        card: card,
        border: border,
        extensions: [
          AppSemanticColors(
            controlBorder: controlBorder,
            success: const Color(0xFF4ADE80),
            successContainer: const Color(0xFF14532D),
            onSuccessContainer: const Color(0xFFDCFCE7),
            warning: const Color(0xFFFBBF24),
            warningContainer: const Color(0xFF451A03),
            onWarningContainer: const Color(0xFFFEF3C7),
            info: const Color(0xFF60A5FA),
            infoContainer: const Color(0xFF172554),
            onInfoContainer: const Color(0xFFDBEAFE),
            timetableForeground: const Color(0xFFE5E7EB),
            timetableMutedForeground: const Color(0xFF94A3B8),
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
