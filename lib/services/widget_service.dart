import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../constants/time_slots.dart';
import '../models/course.dart';

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
    } catch (_) {
      // Ignore widget init failures to avoid blocking app startup.
    }
  }

  static Future<void> refreshWidget() async {
    await _invokeNative('refreshWidgets', errorContext: '刷新小组件');
  }

  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData('schedule_data', null);
      await HomeWidget.saveWidgetData('widget_snapshot_v2', null);
      await _invokeNative('syncWidgets', errorContext: '清除小组件数据');
    } on WidgetSyncException {
      rethrow;
    } catch (e) {
      throw WidgetSyncException('清除小组件数据失败: $e');
    }
  }

  static Future<void> updateWidget({
    required List<Course> courses,
    required DateTime semesterStart,
    required int semesterTotalWeeks,
  }) async {
    final payloadCourses = <Map<String, dynamic>>[];
    for (final course in courses) {
      final startSlot = _findTimeSlot(course.startSession);
      final endSlot = _findTimeSlot(course.endSession);
      if (startSlot == null || endSlot == null) {
        throw WidgetSyncException(
          '课程“${course.title}”的节次无效，小组件和课堂勿扰未同步',
        );
      }

      payloadCourses.add({
        'title': course.title,
        'weekday': course.weekday,
        'startSession': course.startSession,
        'endSession': course.endSession,
        'startTime': startSlot.start,
        'endTime': endSlot.end,
        'weeks': course.weeks,
        'place': course.place,
        'campus': course.campus,
        'color': course.color.toARGB32(),
      });
    }

    try {
      final scheduleJson = jsonEncode({
        'semesterStart':
            '${semesterStart.year}-${semesterStart.month.toString().padLeft(2, '0')}-${semesterStart.day.toString().padLeft(2, '0')}',
        'totalWeeks': semesterTotalWeeks,
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
