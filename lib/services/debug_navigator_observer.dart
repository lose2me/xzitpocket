import 'package:flutter/material.dart';

import 'debug_log_service.dart';

class DebugNavigatorObserver extends NavigatorObserver {
  String _routeLabel(Route<dynamic>? route) {
    if (route == null) return '?';
    final name = route.settings.name;
    if (name != null && name != '/') return name;
    final str = route.toString();
    final match = RegExp(r'_?(\w+Page|\w+Screen)\b').firstMatch(str);
    return match?.group(0) ?? str.split('(').first;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    DebugLogService.instance.log(
      DebugLogCategory.navigation,
      '→ ${_routeLabel(route)}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    DebugLogService.instance.log(
      DebugLogCategory.navigation,
      '← ${_routeLabel(route)}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    DebugLogService.instance.log(
      DebugLogCategory.navigation,
      '${_routeLabel(oldRoute)} → ${_routeLabel(newRoute)}',
    );
  }
}
