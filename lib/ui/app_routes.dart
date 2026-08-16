import 'package:flutter/widgets.dart';

import 'app_tokens.dart';

abstract final class AppRouteNames {
  static const debugLogs = '/about/debug-logs';
  static const licenses = '/about/licenses';
  static const teacherEvaluation = '/tools/teacher-evaluation';
  static const campusCard = '/tools/campus-card';
  static const electricity = '/tools/electricity';
  static const exams = '/tools/exams';
  static const academic = '/tools/academic';
  static const networkManagement = '/tools/network-management';
  static const operatorBinding = '/tools/network-management/operator-binding';
  static const repair = '/tools/repair';
  static const newRepair = '/tools/repair/new';
  static const addCourse = '/timetable/course/add';
  static const editCourse = '/timetable/course/edit';
}

Route<T> appRoute<T>({
  required String name,
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) => PageRouteBuilder<T>(
  settings: RouteSettings(name: name),
  fullscreenDialog: fullscreenDialog,
  transitionDuration: AppMotion.standard,
  reverseTransitionDuration: AppMotion.fast,
  pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final offset = Tween<Offset>(
      begin: const Offset(0.025, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: offset, child: child),
    );
  },
);
