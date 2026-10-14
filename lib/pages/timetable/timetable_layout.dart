import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/school_calendar.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/secondary_schedule_provider.dart';
import '../../widgets/week_header.dart';
import 'timetable_providers.dart';

/// 主课表顶部的周头部。
class TimetableWeekHeader extends ConsumerWidget {
  final VoidCallback? onSync;
  final VoidCallback? onJumpToCurrentWeek;
  final VoidCallback? onToggleSchedule;
  final bool syncing;

  const TimetableWeekHeader({
    super.key,
    this.onSync,
    this.onJumpToCurrentWeek,
    this.onToggleSchedule,
    this.syncing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = ref.watch(secondaryScheduleProvider);
    final courses = secondary.active
        ? secondary.courses
        : (ref.watch(scheduleProvider).value ?? const []);
    final maxWeek = courses.fold(semesterCalendar.totalWeeks, (
      maxWeek,
      course,
    ) {
      for (final week in course.weeks) {
        maxWeek = math.max(maxWeek, week);
      }
      return maxWeek;
    });
    final currentWeek = semesterCalendar
        .weekOf(DateTime.now())
        .clamp(1, maxWeek)
        .toInt();
    return WeekHeader(
      calendar: semesterCalendar,
      selectedWeek: ref.watch(selectedWeekProvider),
      currentWeek: currentWeek,
      onSync: onSync,
      syncing: syncing,
      onJumpToCurrentWeek: onJumpToCurrentWeek,
      onToggleSchedule: secondary.hasSchedule ? onToggleSchedule : null,
      showingSecondarySchedule: secondary.active,
      secondaryScheduleTitle: secondary.title,
      showWeekNumber: ref.watch(configProvider).studentId?.isNotEmpty == true,
    );
  }
}
