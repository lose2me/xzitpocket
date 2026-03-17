import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../constants/time_slots.dart';
import '../models/course.dart';

const _appGroupId = 'live.xuda.xzitpocket';
const _channel = MethodChannel('live.xuda.xzitpocket/widget_bridge');

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
    await _invokeNative('refreshWidgets');
  }

  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData('schedule_data', null);
      await HomeWidget.saveWidgetData('widget_snapshot_v2', null);
      await _invokeNative('syncWidgets');
    } catch (_) {
      // Ignore widget persistence failures to avoid blocking app flows.
    }
  }

  static Future<void> updateWidget({
    required List<Course> courses,
    required DateTime semesterStart,
    required int semesterTotalWeeks,
  }) async {
    try {
      final scheduleJson = jsonEncode({
        'semesterStart':
            '${semesterStart.year}-${semesterStart.month.toString().padLeft(2, '0')}-${semesterStart.day.toString().padLeft(2, '0')}',
        'totalWeeks': semesterTotalWeeks,
        'courses': courses.map((c) {
          final startSlot = kTimeSlots.firstWhere(
            (s) => s.index == c.startSession,
          );
          final endSlot = kTimeSlots.firstWhere((s) => s.index == c.endSession);
          return {
            'title': c.title,
            'weekday': c.weekday,
            'startSession': c.startSession,
            'endSession': c.endSession,
            'startTime': startSlot.start,
            'endTime': endSlot.end,
            'weeks': c.weeks,
            'place': c.place,
            'campus': c.campus,
            'color': c.color.toARGB32(),
          };
        }).toList(),
      });

      await HomeWidget.saveWidgetData('schedule_data', scheduleJson);
      await _invokeNative('syncWidgets');
    } catch (_) {
      // Ignore widget persistence failures to avoid blocking app flows.
    }
  }

  static Future<void> _invokeNative(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Ignore bridge errors to avoid blocking app flows.
    }
  }
}
