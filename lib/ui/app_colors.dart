import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color controlBorder;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color holidayBackground;
  final Color holidayForeground;
  final Color makeupBackground;
  final Color makeupForeground;
  final Color timetableForeground;
  final Color timetableMutedForeground;

  const AppSemanticColors({
    required this.controlBorder,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.holidayBackground,
    required this.holidayForeground,
    required this.makeupBackground,
    required this.makeupForeground,
    required this.timetableForeground,
    required this.timetableMutedForeground,
  });

  @override
  AppSemanticColors copyWith({
    Color? controlBorder,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? holidayBackground,
    Color? holidayForeground,
    Color? makeupBackground,
    Color? makeupForeground,
    Color? timetableForeground,
    Color? timetableMutedForeground,
  }) => AppSemanticColors(
    controlBorder: controlBorder ?? this.controlBorder,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
    onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    holidayBackground: holidayBackground ?? this.holidayBackground,
    holidayForeground: holidayForeground ?? this.holidayForeground,
    makeupBackground: makeupBackground ?? this.makeupBackground,
    makeupForeground: makeupForeground ?? this.makeupForeground,
    timetableForeground: timetableForeground ?? this.timetableForeground,
    timetableMutedForeground:
        timetableMutedForeground ?? this.timetableMutedForeground,
  );

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      holidayBackground: Color.lerp(
        holidayBackground,
        other.holidayBackground,
        t,
      )!,
      holidayForeground: Color.lerp(
        holidayForeground,
        other.holidayForeground,
        t,
      )!,
      makeupBackground: Color.lerp(
        makeupBackground,
        other.makeupBackground,
        t,
      )!,
      makeupForeground: Color.lerp(
        makeupForeground,
        other.makeupForeground,
        t,
      )!,
      timetableForeground: Color.lerp(
        timetableForeground,
        other.timetableForeground,
        t,
      )!,
      timetableMutedForeground: Color.lerp(
        timetableMutedForeground,
        other.timetableMutedForeground,
        t,
      )!,
    );
  }
}

extension AppColorsExtension on FColors {
  AppSemanticColors get semantic => extension<AppSemanticColors>();
}
