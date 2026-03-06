import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../constants/time_slots.dart';
import '../models/course.dart';
import '../utils/week_calculator.dart';

const _appGroupId = 'live.xuda.xzitpocket';
const _androidWidgetName = 'TimetableWidgetProvider';

class WidgetService {
  WidgetService._();

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Re-trigger native widget render (e.g. after dark mode change).
  static Future<void> refreshWidget() async {
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  static Future<void> updateWidget({
    required List<Course> courses,
    required DateTime semesterStart,
  }) async {
    final now = DateTime.now();
    final week = currentWeek(semesterStart);
    final weekday = now.weekday;

    final todayCourses = courses
        .where((c) => c.weekday == weekday && c.isInWeek(week))
        .toList()
      ..sort((a, b) => a.startSession.compareTo(b.startSession));

    final nowMinutes = now.hour * 60 + now.minute;

    Map<String, dynamic>? currentCourse;
    Map<String, dynamic>? nextCourse;
    Map<String, dynamic>? nextNextCourse;

    for (int i = 0; i < todayCourses.length; i++) {
      final c = todayCourses[i];
      final startSlot = kTimeSlots.firstWhere((s) => s.index == c.startSession);
      final endSlot = kTimeSlots.firstWhere((s) => s.index == c.endSession);
      final startMin = _parseTimeToMinutes(startSlot.start);
      final endMin = _parseTimeToMinutes(endSlot.end);

      if (nowMinutes >= startMin && nowMinutes < endMin) {
        currentCourse =
            _courseToMap(c, startSlot, endSlot, endMin - nowMinutes);
        if (i + 1 < todayCourses.length) {
          final nc = todayCourses[i + 1];
          final ns = kTimeSlots.firstWhere((s) => s.index == nc.startSession);
          final ne = kTimeSlots.firstWhere((s) => s.index == nc.endSession);
          nextCourse = _courseToMap(nc, ns, ne, null);
        }
        break;
      } else if (nowMinutes < startMin) {
        nextCourse = _courseToMap(c, startSlot, endSlot, null);
        if (i + 1 < todayCourses.length) {
          final nc = todayCourses[i + 1];
          final ns = kTimeSlots.firstWhere((s) => s.index == nc.startSession);
          final ne = kTimeSlots.firstWhere((s) => s.index == nc.endSession);
          nextNextCourse = _courseToMap(nc, ns, ne, null);
        }
        break;
      }
    }

    Map<String, dynamic>? capsule1;
    Map<String, dynamic>? capsule2;
    bool isInClass = false;

    if (currentCourse != null) {
      isInClass = true;
      capsule1 = currentCourse;
      capsule2 = nextCourse;
    } else {
      capsule1 = nextCourse;
      capsule2 = nextNextCourse;
    }

    await HomeWidget.saveWidgetData(
        'has_timetable', courses.isNotEmpty ? 'true' : 'false');
    await HomeWidget.saveWidgetData(
        'week', week > 0 ? '第$week周' : '未开学');
    await HomeWidget.saveWidgetData('date', '${now.month}.${now.day}');
    await HomeWidget.saveWidgetData('weekday', _weekdayName(now.weekday));
    await HomeWidget.saveWidgetData(
        'is_in_class', isInClass ? 'true' : 'false');
    await HomeWidget.saveWidgetData(
        'capsule1', capsule1 != null ? jsonEncode(capsule1) : '');
    await HomeWidget.saveWidgetData(
        'capsule2', capsule2 != null ? jsonEncode(capsule2) : '');

    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }
  static Map<String, dynamic> _courseToMap(
    Course course,
    TimeSlot startSlot,
    TimeSlot endSlot,
    int? remainingMinutes,
  ) {
    return {
      'title': course.title,
      'campus': course.campus,
      'place': course.place,
      'timeRange': '${startSlot.start}-${endSlot.end}',
      'remainingMinutes': remainingMinutes,
      'color': course.color.toARGB32(),
    };
  }

  static int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String _weekdayName(int weekday) {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[weekday];
  }
}
