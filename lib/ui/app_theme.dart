import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static final light = _build(
    debugLabel: 'XZIT Pocket Light',
    colors: FColors.neutralLight.copyWith(
      background: const Color(0xFFF7F9FA),
      foreground: const Color(0xFF182126),
      primary: const Color(0xFFCE3C57),
      primaryForeground: const Color(0xFFFFFFFF),
      secondary: const Color(0xFFFBE3E9),
      secondaryForeground: const Color(0xFF55202B),
      muted: const Color(0xFFEEF2F3),
      mutedForeground: const Color(0xFF58686F),
      destructive: const Color(0xFFB42318),
      destructiveForeground: const Color(0xFFFFFFFF),
      error: const Color(0xFFB42318),
      errorForeground: const Color(0xFFFFFFFF),
      card: const Color(0xFFFFFFFF),
      border: const Color(0xFFD7E0E3),
      extensions: const [
        AppSemanticColors(
          controlBorder: Color(0xFF7A8B92),
          success: Color(0xFF147A55),
          successContainer: Color(0xFFE5F5EE),
          onSuccessContainer: Color(0xFF0E4A34),
          warning: Color(0xFF8A5B00),
          warningContainer: Color(0xFFFFF3D6),
          onWarningContainer: Color(0xFF4B3100),
          info: Color(0xFF285FA8),
          infoContainer: Color(0xFFE7EFFA),
          onInfoContainer: Color(0xFF153B6B),
          timetableForeground: Color(0xFF182126),
          timetableMutedForeground: Color(0xFF45545A),
        ),
      ],
    ),
  );

  static final dark = _build(
    debugLabel: 'XZIT Pocket Dark',
    colors: FColors.neutralDark.copyWith(
      background: const Color(0xFF0E1417),
      foreground: const Color(0xFFE8EEF0),
      primary: const Color(0xFFFF9BAE),
      primaryForeground: const Color(0xFF2A0E14),
      secondary: const Color(0xFF3A1C22),
      secondaryForeground: const Color(0xFFFFD6DD),
      muted: const Color(0xFF1D292D),
      mutedForeground: const Color(0xFFA5B6BC),
      destructive: const Color(0xFFFF8A80),
      destructiveForeground: const Color(0xFF2B0806),
      error: const Color(0xFFFF8A80),
      errorForeground: const Color(0xFF2B0806),
      card: const Color(0xFF151D21),
      border: const Color(0xFF304047),
      extensions: const [
        AppSemanticColors(
          controlBorder: Color(0xFF71868F),
          success: Color(0xFF6DD6A7),
          successContainer: Color(0xFF143A2B),
          onSuccessContainer: Color(0xFFB9F0D2),
          warning: Color(0xFFF4C060),
          warningContainer: Color(0xFF3A2B0D),
          onWarningContainer: Color(0xFFFFE3A3),
          info: Color(0xFF8FC2FF),
          infoContainer: Color(0xFF15324F),
          onInfoContainer: Color(0xFFC6E1FF),
          timetableForeground: Color(0xFF182126),
          timetableMutedForeground: Color(0xFF45545A),
        ),
      ],
    ),
  );

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
