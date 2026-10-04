import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../constants/time_slots.dart';
import '../models/course.dart';
import '../models/school_calendar.dart';
import 'talker.dart';

const _appGroupId = 'live.xuda.xzitpocket';
const _channel = MethodChannel('live.xuda.xzitpocket/widget_bridge');

class WidgetSyncException implements Exception {
  final String message;

  const WidgetSyncException(this.message);

  @override
  String toString() => message;
}

class WidgetService {
  WidgetService._();

  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e, stackTrace) {
      talker.warning('小组件初始化失败', e, stackTrace);
    }
  }

  static Future<void> refreshWidget() async {
    await _invokeNative('refreshWidgets', errorContext: '刷新小组件');
  }

  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData('schedule_data', null);
      await _invokeNative('syncWidgets', errorContext: '清除小组件数据');
    } on WidgetSyncException {
      rethrow;
    } catch (e) {
      throw WidgetSyncException('清除小组件数据失败: $e');
    }
  }

  static Future<void> updateWidget({
    required List<Course> courses,
    required List<Course> originalCourses,
    required DateTime semesterStart,
  }) async {
    final payloadCourses = <Map<String, dynamic>>[];
    int maxWeek = 16;
    for (final course in courses) {
      final startSlot = _findTimeSlot(course.startSession);
      final endSlot = _findTimeSlot(course.endSession);
      if (startSlot == null || endSlot == null) {
        throw WidgetSyncException('课程”${course.title}”的节次无效，小组件和课堂勿扰未同步');
      }

      for (final w in course.weeks) {
        if (w > maxWeek) maxWeek = w;
      }

      payloadCourses.add({
        'title': course.title,
        'weekday': course.weekday,
        'startSession': course.startSession,
        'endSession': course.endSession,
        'startTime': startSlot.start,
        'endTime': endSlot.end,
        'weeks': course.weeks,
        'teacher': course.teacher,
        'place': course.place,
        'campus': course.campus,
        'color': course.color.toARGB32(),
      });
    }

    try {
      final calendarDays = semesterCalendar.days;
      final scheduleJson = jsonEncode({
        'semesterStart':
            '${semesterStart.year}-${semesterStart.month.toString().padLeft(2, '0')}-${semesterStart.day.toString().padLeft(2, '0')}',
        'totalWeeks': maxWeek,
        'holidayDates': schoolCalendarDates(
          calendarDays,
          (day) => day.isHoliday,
        ).toList()..sort(),
        'adjustedDates': schoolCalendarDates(
          calendarDays,
          (day) => day.isMakeupClass,
        ).toList()..sort(),
        'courses': payloadCourses,
      });

      await HomeWidget.saveWidgetData('schedule_data', scheduleJson);
      await _invokeNative('syncWidgets', errorContext: '同步小组件和课堂勿扰');
    } on WidgetSyncException {
      rethrow;
    } catch (e) {
      throw WidgetSyncException('同步小组件和课堂勿扰失败: $e');
    }
  }

  static Future<void> _invokeNative(
    String method, {
    required String errorContext,
  }) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (e) {
      throw WidgetSyncException('$errorContext失败: ${e.message ?? e.code}');
    } catch (e) {
      throw WidgetSyncException('$errorContext失败: $e');
    }
  }

  static TimeSlot? _findTimeSlot(int session) {
    for (final slot in kTimeSlots) {
      if (slot.index == session) return slot;
    }
    return null;
  }
}

Set<String> adjustedCourseDates({
  required List<Course> courses,
  required List<Course> originalCourses,
  required DateTime semesterStart,
}) {
  if (originalCourses.isEmpty) return const {};
  final occurrences = <(int, int)>{};
  for (final course in [...courses, ...originalCourses]) {
    for (final week in course.weeks) {
      occurrences.add((week, course.weekday));
    }
  }

  final monday = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ).subtract(Duration(days: semesterStart.weekday - 1));
  final result = <String>{};
  for (final (week, weekday) in occurrences) {
    final current = _courseDaySignatures(courses, week, weekday);
    final baseline = _courseDaySignatures(originalCourses, week, weekday);
    if (listEquals(current, baseline)) continue;
    final date = monday.add(
      Duration(days: (week - 1) * DateTime.daysPerWeek + weekday - 1),
    );
    result.add(
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
  }
  return result;
}

Set<String> schoolCalendarDates(
  Iterable<SchoolDay> days,
  bool Function(SchoolDay day) predicate,
) => {
  for (final day in days)
    if (predicate(day)) _calendarDateKey(day.date),
};

String _calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<String> _courseDaySignatures(
  List<Course> courses,
  int week,
  int weekday,
) => [
  for (final course in courses)
    if (course.weekday == weekday && course.weeks.contains(week))
      [
        course.title,
        course.teacher,
        ([...course.sessions]..sort()).join(','),
        course.campus,
        course.place,
        course.colorIndex,
        course.courseId,
      ].join('\u001f'),
]..sort();
