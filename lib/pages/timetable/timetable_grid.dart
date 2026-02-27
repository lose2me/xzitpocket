import 'package:flutter/material.dart';

import '../../models/course.dart';
import 'course_card.dart';
import 'time_column.dart';

class TimetableGrid extends StatelessWidget {
  final List<Course> courses;
  final int week;
  final int slotCount;
  final int visibleSlots;
  final void Function(Course course, int index)? onCourseTap;
  final void Function(int weekday, int session)? onEmptyTap;

  const TimetableGrid({
    super.key,
    required this.courses,
    required this.week,
    this.slotCount = 14,
    this.visibleSlots = 9,
    this.onCourseTap,
    this.onEmptyTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekCourses = courses.where((c) => c.isInWeek(week)).toList();

    return LayoutBuilder(
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
    );
  }
}
