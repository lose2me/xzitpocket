import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../utils/week_calculator.dart';
import 'course_card.dart';
import 'time_column.dart';

class TimetableGrid extends StatelessWidget {
  final List<Course> courses;
  final int week;
  final DateTime semesterStart;
  final int slotCount;
  final int visibleSlots;
  final void Function(Course course, int index)? onCourseTap;
  final void Function(int weekday, int session)? onEmptyTap;
  final Color borderColor;
  final double borderWidth;
  final double courseOpacity;
  final double courseBorderOpacity;

  const TimetableGrid({
    super.key,
    required this.courses,
    required this.week,
    required this.semesterStart,
    this.slotCount = 14,
    this.visibleSlots = 9,
    this.onCourseTap,
    this.onEmptyTap,
    this.borderColor = Colors.grey,
    this.borderWidth = 0.5,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekCourses = courses.where((c) => c.isInWeek(week)).toList();
    final dates = weekDates(semesterStart, week);
    final today = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      children: [
        // Weekday headers row
        Row(
          children: [
            SizedBox(
              width: 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: '${dates[0].month}月'.split('').map((c) => Text(
                  c,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )).toList(),
              ),
            ),
            ...List.generate(7, (i) {
              final date = dates[i];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: isToday
                      ? BoxDecoration(
                          color:
                              theme.colorScheme.primaryContainer.withAlpha(128),
                        )
                      : null,
                  child: Column(
                    children: [
                      Text(
                        weekdays[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const Divider(height: 1),
        // Timetable grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = constraints.maxHeight / visibleSlots;
              final totalHeight = cellHeight * slotCount;

              return SingleChildScrollView(
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    children: [
                      TimeColumn(cellHeight: cellHeight, slotCount: slotCount),
                      ...List.generate(7, (dayIndex) {
                        final weekday = dayIndex + 1;
                        final dayCourses =
                            weekCourses.where((c) => c.weekday == weekday).toList();
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              final session =
                                  (details.localPosition.dy / cellHeight).floor() + 1;
                              final hit = dayCourses
                                  .where((c) =>
                                      session >= c.startSession &&
                                      session <= c.endSession)
                                  .toList();
                              if (hit.isEmpty && onEmptyTap != null) {
                                onEmptyTap!(weekday, session);
                              }
                            },
                            child: Stack(
                              children: [
                                // Grid lines
                                Column(
                                  children: List.generate(slotCount, (i) {
                                    return Container(
                                      height: cellHeight,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.colorScheme.outlineVariant
                                                .withAlpha(76),
                                            width: 0.5,
                                          ),
                                          right: BorderSide(
                                            color: theme.colorScheme.outlineVariant
                                                .withAlpha(76),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                // Course cards
                                ...dayCourses.asMap().entries.map((entry) {
                                  final course = entry.value;
                                  final globalIdx = courses.indexOf(course);
                                  final top =
                                      (course.startSession - 1) * cellHeight;
                                  final height = course.sessionSpan * cellHeight;
                                  return Positioned(
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    child: CourseCard(
                                      course: course,
                                      courseOpacity: courseOpacity,
                                      courseBorderOpacity: courseBorderOpacity,
                                      borderColor: borderColor,
                                      borderWidth: borderWidth,
                                      onTap: onCourseTap != null
                                          ? () => onCourseTap!(course, globalIdx)
                                          : null,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
