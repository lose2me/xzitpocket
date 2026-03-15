import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../utils/week_calculator.dart';
import 'course_card.dart';
import 'time_column.dart';

class TimetableGrid extends StatelessWidget {
  final List<Course> courses;
  final int week;
  final int rotationTick;
  final Animation<double>? countdownAnimation;
  final bool showNonCurrentWeekCourses;
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
    this.rotationTick = 0,
    this.countdownAnimation,
    this.showNonCurrentWeekCourses = false,
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
    final indexedCourses = courses
        .asMap()
        .entries
        .map(
          (entry) =>
              _IndexedCourse(sourceIndex: entry.key, course: entry.value),
        )
        .toList();
    final currentWeekCourses = indexedCourses
        .where((entry) => entry.course.isInWeek(week))
        .toList();
    final otherWeekCourses = showNonCurrentWeekCourses
        ? indexedCourses.where((entry) => !entry.course.isInWeek(week)).toList()
        : const <_IndexedCourse>[];
    final dates = weekDates(semesterStart, week);
    final today = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final nonCurrentCourseOpacity = (courseOpacity * 0.38)
        .clamp(0.18, 0.4)
        .toDouble();
    final nonCurrentCourseBorderOpacity = (courseBorderOpacity * 0.32)
        .clamp(0.14, 0.34)
        .toDouble();

    return Column(
      children: [
        // Weekday headers row
        Row(
          children: [
            SizedBox(
              width: 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: '${dates[0].month}月'
                    .split('')
                    .map(
                      (c) => Text(
                        c,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            ...List.generate(7, (i) {
              final date = dates[i];
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: isToday
                      ? BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(
                            128,
                          ),
                        )
                      : null,
                  child: Column(
                    children: [
                      Text(
                        weekdays[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.normal,
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
                        final dayCourses = currentWeekCourses
                            .where((entry) => entry.course.weekday == weekday)
                            .toList();
                        final otherDayCourses = otherWeekCourses
                            .where((entry) => entry.course.weekday == weekday)
                            .toList();
                        final displayCourses = _buildDisplayCourses(
                          dayCourses,
                          rotationTick,
                        );
                        final otherDisplayCourses = _buildDisplayCourses(
                          otherDayCourses,
                          rotationTick,
                        );
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              final session =
                                  (details.localPosition.dy / cellHeight)
                                      .floor() +
                                  1;
                              final hasCurrentHit = dayCourses.any(
                                (entry) =>
                                    _indexedCourseHitsSession(entry, session),
                              );
                              final hasOtherHit = otherDayCourses.any(
                                (entry) =>
                                    _indexedCourseHitsSession(entry, session),
                              );
                              if (!hasCurrentHit &&
                                  !hasOtherHit &&
                                  onEmptyTap != null) {
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
                                            color: theme
                                                .colorScheme
                                                .outlineVariant
                                                .withAlpha(76),
                                            width: 0.5,
                                          ),
                                          right: BorderSide(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant
                                                .withAlpha(76),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                ...otherDisplayCourses.map((display) {
                                  final course = display.course;
                                  final top =
                                      (course.startSession - 1) * cellHeight;
                                  final height =
                                      course.sessionSpan * cellHeight;
                                  return Positioned(
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    child: CourseCard(
                                      key: ValueKey(
                                        '${display.animationKey}:ghost',
                                      ),
                                      course: course,
                                      muted: true,
                                      courseOpacity: nonCurrentCourseOpacity,
                                      courseBorderOpacity:
                                          nonCurrentCourseBorderOpacity,
                                      borderColor: borderColor,
                                      borderWidth: borderWidth,
                                    ),
                                  );
                                }),
                                ...otherDisplayCourses.map((display) {
                                  final top =
                                      (display.tapStartSession - 1) *
                                      cellHeight;
                                  final height =
                                      display.tapSessionSpan * cellHeight;
                                  return Positioned(
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: onCourseTap != null
                                          ? () => onCourseTap!(
                                              display.course,
                                              display.sourceIndex,
                                            )
                                          : null,
                                      child: const SizedBox.expand(),
                                    ),
                                  );
                                }),
                                // Course cards
                                ...displayCourses.map((display) {
                                  final course = display.course;
                                  final top =
                                      (course.startSession - 1) * cellHeight;
                                  final height =
                                      course.sessionSpan * cellHeight;
                                  return AnimatedPositioned(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      child: CourseCard(
                                        key: ValueKey(display.animationKey),
                                        course: course,
                                        countdownAnimation: display.isConflict
                                            ? countdownAnimation
                                            : null,
                                        courseOpacity: courseOpacity,
                                        courseBorderOpacity:
                                            courseBorderOpacity,
                                        borderColor: borderColor,
                                        borderWidth: borderWidth,
                                      ),
                                    ),
                                  );
                                }),
                                ...displayCourses.map((display) {
                                  final top =
                                      (display.tapStartSession - 1) *
                                      cellHeight;
                                  final height =
                                      display.tapSessionSpan * cellHeight;
                                  return Positioned(
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: onCourseTap != null
                                          ? () => onCourseTap!(
                                              display.course,
                                              display.sourceIndex,
                                            )
                                          : null,
                                      child: const SizedBox.expand(),
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

bool _indexedCourseHitsSession(_IndexedCourse entry, int session) {
  return session >= entry.course.startSession &&
      session <= entry.course.endSession;
}

List<_DisplayCourse> _buildDisplayCourses(
  List<_IndexedCourse> dayCourses,
  int rotationTick,
) {
  final sortedCourses = [...dayCourses]
    ..sort((a, b) {
      final startCompare = a.course.startSession.compareTo(
        b.course.startSession,
      );
      if (startCompare != 0) return startCompare;
      final endCompare = a.course.endSession.compareTo(b.course.endSession);
      if (endCompare != 0) return endCompare;
      return a.sourceIndex.compareTo(b.sourceIndex);
    });

  final groups = <List<_IndexedCourse>>[];
  var currentGroup = <_IndexedCourse>[];
  var currentGroupEnd = 0;

  for (final entry in sortedCourses) {
    if (currentGroup.isEmpty) {
      currentGroup = [entry];
      currentGroupEnd = entry.course.endSession;
      continue;
    }

    if (entry.course.startSession <= currentGroupEnd) {
      currentGroup.add(entry);
      if (entry.course.endSession > currentGroupEnd) {
        currentGroupEnd = entry.course.endSession;
      }
      continue;
    }

    groups.add(currentGroup);
    currentGroup = [entry];
    currentGroupEnd = entry.course.endSession;
  }

  if (currentGroup.isNotEmpty) {
    groups.add(currentGroup);
  }

  final displayCourses = <_DisplayCourse>[];
  for (final group in groups) {
    if (group.length == 1) {
      final entry = group.first;
      displayCourses.add(
        _DisplayCourse(
          course: entry.course,
          sourceIndex: entry.sourceIndex,
          tapStartSession: entry.course.startSession,
          tapSessionSpan: entry.course.sessionSpan,
          animationKey: '${entry.sourceIndex}:solo',
        ),
      );
      continue;
    }

    final variants = _buildConflictVariants(group);
    final selectedVariantIndex = rotationTick % variants.length;
    final selectedVariant = variants[selectedVariantIndex];

    for (final entry in selectedVariant) {
      displayCourses.add(
        _DisplayCourse(
          course: entry.course,
          sourceIndex: entry.sourceIndex,
          tapStartSession: entry.course.startSession,
          tapSessionSpan: entry.course.sessionSpan,
          isConflict: variants.length > 1,
          animationKey: '${entry.sourceIndex}:variant:$selectedVariantIndex',
        ),
      );
    }
  }

  displayCourses.sort((a, b) {
    final startCompare = a.course.startSession.compareTo(b.course.startSession);
    if (startCompare != 0) return startCompare;
    return a.sourceIndex.compareTo(b.sourceIndex);
  });

  return displayCourses;
}

List<List<_IndexedCourse>> _buildConflictVariants(List<_IndexedCourse> group) {
  final variants = <List<_IndexedCourse>>[];

  void backtrack(int startIndex, List<_IndexedCourse> current) {
    var hasExtension = false;

    for (int i = startIndex; i < group.length; i++) {
      final candidate = group[i];
      final overlapsCurrent = current.any(
        (entry) => _coursesOverlap(entry.course, candidate.course),
      );
      if (overlapsCurrent) continue;

      hasExtension = true;
      current.add(candidate);
      backtrack(i + 1, current);
      current.removeLast();
    }

    if (!hasExtension && current.isNotEmpty) {
      variants.add(List<_IndexedCourse>.from(current));
    }
  }

  backtrack(0, <_IndexedCourse>[]);

  final deduped = <String, List<_IndexedCourse>>{};
  for (final variant in variants) {
    final sortedVariant = [...variant]
      ..sort((a, b) => a.sourceIndex.compareTo(b.sourceIndex));
    final key = sortedVariant
        .map((entry) => entry.sourceIndex.toString())
        .join(':');
    deduped.putIfAbsent(key, () => sortedVariant);
  }

  final result = deduped.values.toList()
    ..sort((a, b) {
      final lengthCompare = b.length.compareTo(a.length);
      if (lengthCompare != 0) return lengthCompare;
      final sharedLength = a.length < b.length ? a.length : b.length;
      for (int i = 0; i < sharedLength; i++) {
        final compare = a[i].sourceIndex.compareTo(b[i].sourceIndex);
        if (compare != 0) return compare;
      }
      return a.length.compareTo(b.length);
    });

  return result.isEmpty ? [group.take(1).toList()] : result;
}

bool _coursesOverlap(Course a, Course b) {
  return a.startSession <= b.endSession && b.startSession <= a.endSession;
}

class _IndexedCourse {
  final int sourceIndex;
  final Course course;

  const _IndexedCourse({required this.sourceIndex, required this.course});
}

class _DisplayCourse {
  final Course course;
  final int sourceIndex;
  final int tapStartSession;
  final int tapSessionSpan;
  final bool isConflict;
  final String animationKey;

  const _DisplayCourse({
    required this.course,
    required this.sourceIndex,
    required this.tapStartSession,
    required this.tapSessionSpan,
    this.isConflict = false,
    required this.animationKey,
  });
}
