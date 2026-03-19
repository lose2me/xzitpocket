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
