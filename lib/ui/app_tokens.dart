import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

enum AppWindowClass { compact, medium, expanded }

abstract final class AppSpacing {
  static const double micro = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
  static const double spacious = 40;
  static const double page = 48;
}

abstract final class AppLayout {
  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 840;
  static const double contentMaxWidth = 960;
  static const double resultMaxWidth = 720;
  static const double formMaxWidth = 560;

  static AppWindowClass windowClass(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactBreakpoint) return AppWindowClass.compact;
    if (width < expandedBreakpoint) return AppWindowClass.medium;
    return AppWindowClass.expanded;
  }

  static double pageGutter(BuildContext context) =>
      switch (windowClass(context)) {
        AppWindowClass.compact => AppSpacing.lg,
        AppWindowClass.medium => AppSpacing.xxl,
        AppWindowClass.expanded => AppSpacing.section,
      };

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = AppSpacing.md,
    double bottom = AppSpacing.xl,
  }) {
    final horizontal = pageGutter(context);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration emphasized = Duration(milliseconds: 240);
}

extension AppTypographyTokens on FTypography {
  TextStyle get pageTitle => body.lg.copyWith(
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  TextStyle get sectionTitle => body.xs.copyWith(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  TextStyle get tileTitle => body.sm.copyWith(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  TextStyle get bodyText => body.sm.copyWith(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  TextStyle get bodySmall => body.xs.copyWith(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  TextStyle get label => body.xs.copyWith(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  TextStyle get caption => body.xs2.copyWith(
    fontSize: 12,
    height: 4 / 3,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  TextStyle get metric => body.xl.copyWith(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
}
