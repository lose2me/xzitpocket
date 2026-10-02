import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AutomationPermissionStatus {
  final bool hasDndPermission;
  final bool hasExactAlarmPermission;

  const AutomationPermissionStatus({
    required this.hasDndPermission,
    required this.hasExactAlarmPermission,
  });

  bool get isFullyGranted => hasDndPermission && hasExactAlarmPermission;

  factory AutomationPermissionStatus.fromMap(Map<Object?, Object?> map) {
    return AutomationPermissionStatus(
      hasDndPermission: map['hasDndPermission'] as bool? ?? false,
      hasExactAlarmPermission: map['hasExactAlarmPermission'] as bool? ?? true,
    );
  }

  static const fallback = AutomationPermissionStatus(
    hasDndPermission: true,
    hasExactAlarmPermission: true,
  );
}

class CourseReminderPermissionStatus {
  final bool notificationsGranted;
  final bool exactAlarmGranted;
  final bool dndGranted;
  final bool batteryOptimizationIgnored;

  const CourseReminderPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
    required this.dndGranted,
    required this.batteryOptimizationIgnored,
  });

  bool get isFullyGranted => notificationsGranted && exactAlarmGranted;

  factory CourseReminderPermissionStatus.fromMap(Map<Object?, Object?> map) {
    return CourseReminderPermissionStatus(
      notificationsGranted: map['notificationsGranted'] as bool? ?? true,
      exactAlarmGranted: map['exactAlarmGranted'] as bool? ?? true,
      dndGranted: map['dndGranted'] as bool? ?? true,
      batteryOptimizationIgnored:
          map['batteryOptimizationIgnored'] as bool? ?? true,
    );
  }

  static const fallback = CourseReminderPermissionStatus(
    notificationsGranted: true,
    exactAlarmGranted: true,
    dndGranted: true,
    batteryOptimizationIgnored: true,
  );
}

class NativeAutomationService {
  static const _channel = MethodChannel('live.xuda.xzitpocket/app_bridge');

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static Future<void> refreshClassAutomation() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('refreshClassAutomation');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<void> refreshCourseReminders() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('refreshCourseReminders');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<void> requestNotificationPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestNotificationPermission');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<void> openNotificationSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<void> openBackgroundAndAutostartSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBackgroundAndAutostartSettings');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<void> openBatteryOptimizationSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<CourseReminderPermissionStatus>
  getCourseReminderPermissionStatus() async {
    if (!_isAndroid) return CourseReminderPermissionStatus.fallback;
    try {
      final result =
          await _channel.invokeMapMethod<Object?, Object?>(
            'getCourseReminderPermissions',
          ) ??
          const <Object?, Object?>{};
      return CourseReminderPermissionStatus.fromMap(result);
    } on MissingPluginException {
      return CourseReminderPermissionStatus.fallback;
    }
  }

  static Future<AutomationPermissionStatus> getPermissionStatus() async {
    if (!_isAndroid) return AutomationPermissionStatus.fallback;
    try {
      final result =
          await _channel.invokeMapMethod<Object?, Object?>(
            'getAutomationPermissions',
          ) ??
          const <Object?, Object?>{};
      return AutomationPermissionStatus.fromMap(result);
    } on MissingPluginException {
      return AutomationPermissionStatus.fallback;
    }
  }

  static Future<void> openDndSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openDndSettings');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }

  static Future<void> openExactAlarmSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } on MissingPluginException {
      // Ignore on unsupported platforms.
    }
  }
}
