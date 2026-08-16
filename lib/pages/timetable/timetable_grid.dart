import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../ui/app_tokens.dart';
import '../../utils/week_calculator.dart';
import 'course_card.dart';
import 'time_column.dart';

class TimetableGrid extends StatelessWidget {
  final List<Course> courses;
  final int week;
  final int rotationTick;
  final bool showNonCurrentWeekCourses;
  final bool showWeekendColumns;
  final DateTime semesterStart;
  final int slotCount;
  final int visibleSlots;
  final Set<int> hiddenSlots;
  final void Function(Course course, int index)? onCourseTap;
  final void Function(int weekday, int session)? onEmptyTap;
  final void Function(bool hasConflict, bool isMutedConflict)?
  onConflictComputed;
  final Animation<double>? countdownAnimation;
  final Color borderColor;
  final double borderWidth;
  final double courseOpacity;
  final double courseBorderOpacity;

  const TimetableGrid({
    super.key,
    required this.courses,
    required this.week,
    this.rotationTick = 0,
    this.showNonCurrentWeekCourses = false,
    this.showWeekendColumns = true,
    required this.semesterStart,
    this.slotCount = 14,
    this.visibleSlots = 9,
    this.hiddenSlots = const {},
    this.onCourseTap,
    this.onEmptyTap,
    this.onConflictComputed,
    this.countdownAnimation,
    required this.borderColor,
    this.borderWidth = 0.5,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final indexedCourses = courses
        .asMap()
        .entries
        .map(
          (entry) => _IndexedCourse(
            sourceIndex: entry.key,
            course: entry.value,
            isCurrentWeek: entry.value.isInWeek(week),
          ),
        )
        .toList();
    final currentWeekCourses = indexedCourses
        .where((entry) => entry.isCurrentWeek)
        .toList();
    final otherWeekCourses = showNonCurrentWeekCourses
        ? indexedCourses.where((entry) => !entry.isCurrentWeek).toList()
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

    final dayCount = showWeekendColumns ? 7 : 5;

    // Pre-compute display courses for all days
    final dayDisplayData = List.generate(dayCount, (dayIndex) {
      final weekday = dayIndex + 1;
      final allDayCourses = <_IndexedCourse>[
        ...currentWeekCourses.where((e) => e.course.weekday == weekday),
        ...otherWeekCourses.where((e) => e.course.weekday == weekday),
      ];
      return _buildDisplayCourses(allDayCourses, rotationTick);
    });

    // Compute conflict state
    var anyConflict = false;
    var anyMutedConflict = false;
    for (final displayCourses in dayDisplayData) {
      for (final d in displayCourses) {
        if (d.isConflict) {
          anyConflict = true;
          if (d.isMutedVariant) anyMutedConflict = true;
        }
      }
    }

    if (onConflictComputed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onConflictComputed!(anyConflict, anyMutedConflict);
      });
    }

    return Column(
      children: [
        // Weekday headers row
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: '${dates[0].month}月'
                    .split('')
                    .map(
                      (c) => Text(
                        c,
                        style: theme.typography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            ...List.generate(dayCount, (i) {
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
                          color: theme.colors.secondary.withAlpha(128),
                        )
                      : null,
                  child: Column(
                    children: [
                      Text(
                        weekdays[i],
                        style: theme.typography.caption.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isToday
                              ? theme.colors.primary
                              : theme.colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: theme.typography.caption.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isToday
                              ? theme.colors.primary
                              : theme.colors.mutedForeground,
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
        FDivider(
          style: FDividerStyleDelta.delta(
            color: theme.colors.border,
            padding: const EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
          ),
        ),
        // Timetable grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final visibleSessions = [
                for (int s = 1; s <= slotCount; s++)
                  if (!hiddenSlots.contains(s)) s,
              ];
              final effectiveSlotCount = visibleSessions.length;
              final sessionToRow = <int, int>{};
              for (int i = 0; i < visibleSessions.length; i++) {
                sessionToRow[visibleSessions[i]] = i;
              }

              final cellHeight = constraints.maxHeight / visibleSlots;
              final totalHeight = cellHeight * effectiveSlotCount;

              return SingleChildScrollView(
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    children: [
                      TimeColumn(
                        cellHeight: cellHeight,
                        slotCount: slotCount,
                        hiddenSlots: hiddenSlots,
                      ),
                      ...List.generate(dayCount, (dayIndex) {
                        final weekday = dayIndex + 1;
                        final allDayCourses = <_IndexedCourse>[
                          ...currentWeekCourses.where(
                            (e) => e.course.weekday == weekday,
                          ),
                          ...otherWeekCourses.where(
                            (e) => e.course.weekday == weekday,
                          ),
                        ];
                        final allDisplayCourses = dayDisplayData[dayIndex];
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              final row =
                                  (details.localPosition.dy / cellHeight)
                                      .floor()
                                      .clamp(0, visibleSessions.length - 1);
                              final session = visibleSessions[row];
                              final hasHit = allDayCourses.any(
                                (entry) =>
                                    _indexedCourseHitsSession(entry, session),
                              );
                              if (!hasHit && onEmptyTap != null) {
                                onEmptyTap!(weekday, session);
                              }
                            },
                            child: Stack(
                              children: [
                                // Grid lines
                                Column(
                                  children: List.generate(effectiveSlotCount, (
                                    i,
                                  ) {
                                    return Container(
                                      height: cellHeight,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.colors.border
                                                .withAlpha(76),
                                            width: 0.5,
                                          ),
                                          right: BorderSide(
                                            color: theme.colors.border
                                                .withAlpha(76),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                // Course cards
                                ...allDisplayCourses.map((display) {
                                  final course = display.course;
                                  final isCurrentWeek = course.isInWeek(week);
                                  final startRow =
                                      sessionToRow[course.startSession] ??
                                      (course.startSession - 1);
                                  final endRow =
                                      sessionToRow[course.endSession] ??
                                      (course.endSession - 1);
                                  final top = startRow * cellHeight;
                                  final height =
                                      (endRow - startRow + 1) * cellHeight;
                                  return AnimatedPositioned(
                                    key: ValueKey(display.animationKey),
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 450,
                                      ),
                                      switchInCurve: Curves.easeInOutCubic,
                                      switchOutCurve: Curves.easeInOutCubic,
                                      transitionBuilder: (child, animation) {
                                        final slide = Tween<Offset>(
                                          begin: const Offset(0, 0.15),
                                          end: Offset.zero,
                                        ).animate(animation);
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: slide,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: CourseCard(
                                        key: ValueKey(display.animationKey),
                                        course: course,
                                        countdownAnimation: display.isConflict
                                            ? countdownAnimation
                                            : null,
                                        muted: !isCurrentWeek,
                                        courseOpacity: isCurrentWeek
                                            ? courseOpacity
                                            : nonCurrentCourseOpacity,
                                        courseBorderOpacity: isCurrentWeek
                                            ? courseBorderOpacity
                                            : nonCurrentCourseBorderOpacity,
                                        borderColor: borderColor,
                                        borderWidth: borderWidth,
                                      ),
                                    ),
                                  );
                                }),
                                ...allDisplayCourses.map((display) {
                                  final tapStartRow =
                                      sessionToRow[display.tapStartSession] ??
                                      (display.tapStartSession - 1);
                                  final tapEndRow =
                                      sessionToRow[display.tapStartSession +
                                          display.tapSessionSpan -
                                          1] ??
                                      (display.tapStartSession +
                                          display.tapSessionSpan -
                                          2);
                                  final top = tapStartRow * cellHeight;
                                  final height =
                                      (tapEndRow - tapStartRow + 1) *
                                      cellHeight;
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

    // Split into current-week and other-week entries
    final currentWeekEntries = group.where((e) => e.isCurrentWeek).toList();
    final otherWeekEntries = group.where((e) => !e.isCurrentWeek).toList();

    final currentVariants = currentWeekEntries.isNotEmpty
        ? _buildConflictVariants(currentWeekEntries)
        : <List<_IndexedCourse>>[];
    final otherVariants = otherWeekEntries.isNotEmpty
        ? _buildConflictVariants(otherWeekEntries)
        : <List<_IndexedCourse>>[];

    final variants = [...currentVariants, ...otherVariants];
    if (variants.isEmpty) {
      variants.add(group.take(1).toList());
    }

    final selectedVariantIndex = rotationTick % variants.length;
    final selectedVariant = variants[selectedVariantIndex];
    final isMuted =
        selectedVariantIndex >= currentVariants.length &&
        otherVariants.isNotEmpty;

    for (final entry in selectedVariant) {
      displayCourses.add(
        _DisplayCourse(
          course: entry.course,
          sourceIndex: entry.sourceIndex,
          tapStartSession: entry.course.startSession,
          tapSessionSpan: entry.course.sessionSpan,
          isConflict: variants.length > 1,
          isMutedVariant: isMuted,
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
  const maxVariants = 20;
  final variants = <List<_IndexedCourse>>[];

  void backtrack(int startIndex, List<_IndexedCourse> current) {
    if (variants.length >= maxVariants) return;
    var hasExtension = false;

    for (int i = startIndex; i < group.length; i++) {
      if (variants.length >= maxVariants) return;
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
  final bool isCurrentWeek;

  const _IndexedCourse({
    required this.sourceIndex,
    required this.course,
    required this.isCurrentWeek,
  });
}

class _DisplayCourse {
  final Course course;
  final int sourceIndex;
  final int tapStartSession;
  final int tapSessionSpan;
  final bool isConflict;
  final bool isMutedVariant;
  final String animationKey;

  const _DisplayCourse({
    required this.course,
    required this.sourceIndex,
    required this.tapStartSession,
    required this.tapSessionSpan,
    this.isConflict = false,
    this.isMutedVariant = false,
    required this.animationKey,
  });
}
