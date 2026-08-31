import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../ui/app_tokens.dart';
import 'course_card.dart';
import 'time_column.dart';

/// A single day's timetable.
///
/// The widget memoizes the expensive part of its layout computation: the
/// sorting, overlap grouping and the conflict-variant backtracking
/// (`_buildConflictVariants`). Those only depend on `courses`, `week` and
/// `showNonCurrentWeekCourses`, so the result is cached in the State and the
/// layout is only re-derived when one of those inputs actually changes. The
/// `rotationTick` (which drives the 3-second conflict rotation) only picks a
/// *variant index*, which is cheap — it no longer re-runs the grouping or the
/// backtracking every time the countdown wraps.
class TimetableGrid extends StatefulWidget {
  final List<Course> courses;
  final int week;
  final int rotationTick;
  final bool showNonCurrentWeekCourses;
  final bool showWeekendColumns;

  final SemesterCalendar calendar;
  final int slotCount;
  final int visibleSlots;
  final Set<int> hiddenSlots;
  final void Function(Course course, int index)? onCourseTap;
  final void Function(int weekday, int session)? onEmptyTap;
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
    required this.calendar,
    this.slotCount = 14,
    this.visibleSlots = 9,
    this.hiddenSlots = const {},
    this.onCourseTap,
    this.onEmptyTap,
    this.countdownAnimation,
    required this.borderColor,
    this.borderWidth = 0.5,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
  });

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  _GridLayoutCacheKey? _layoutKey;
  Map<int, List<_DaySlot>>? _daySlots;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final courses = widget.courses;
    final week = widget.week;
    final showNonCurrentWeekCourses = widget.showNonCurrentWeekCourses;
    final showWeekendColumns = widget.showWeekendColumns;
    final rotationTick = widget.rotationTick;

    _ensureLayout(courses, week, showNonCurrentWeekCourses);

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
    final currentByWeekday = <int, List<_IndexedCourse>>{};
    for (final entry in currentWeekCourses) {
      currentByWeekday.putIfAbsent(entry.course.weekday, () => []).add(entry);
    }
    final otherByWeekday = <int, List<_IndexedCourse>>{};
    for (final entry in otherWeekCourses) {
      otherByWeekday.putIfAbsent(entry.course.weekday, () => []).add(entry);
    }
    final dates = widget.calendar.weekDates(week);
    final today = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final courseOpacity = widget.courseOpacity;
    final courseBorderOpacity = widget.courseBorderOpacity;
    final nonCurrentCourseOpacity = (courseOpacity * 0.38)
        .clamp(0.18, 0.4)
        .toDouble();
    final nonCurrentCourseBorderOpacity = (courseBorderOpacity * 0.32)
        .clamp(0.14, 0.34)
        .toDouble();

    final dayCount = showWeekendColumns ? 7 : 5;

    // Cheap pre-compute: only the variant selection happens here (from the
    // cached day slots), never the grouping/backtracking.
    final dayDisplayData = List.generate(dayCount, (dayIndex) {
      final weekday = dayIndex + 1;
      final slots = _daySlots?[weekday] ?? const <_DaySlot>[];
      return _selectDayDisplays(slots, rotationTick);
    });

    return Column(
      children: [
        // Weekday headers row
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  '${dates[0].month}月',
                  style: theme.typography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colors.mutedForeground,
                  ),
                ),
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
                for (int s = 1; s <= widget.slotCount; s++)
                  if (!widget.hiddenSlots.contains(s)) s,
              ];
              final effectiveSlotCount = visibleSessions.length;
              final sessionToRow = <int, int>{};
              for (int i = 0; i < visibleSessions.length; i++) {
                sessionToRow[visibleSessions[i]] = i;
              }

              final cellHeight = constraints.maxHeight / widget.visibleSlots;
              final totalHeight = cellHeight * effectiveSlotCount;

              return SingleChildScrollView(
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    children: [
                      TimeColumn(
                        cellHeight: cellHeight,
                        slotCount: widget.slotCount,
                        hiddenSlots: widget.hiddenSlots,
                      ),
                      ...List.generate(dayCount, (dayIndex) {
                        final weekday = dayIndex + 1;
                        final allDayCourses = <_IndexedCourse>[
                          ...(currentByWeekday[weekday] ??
                              const <_IndexedCourse>[]),
                          ...(otherByWeekday[weekday] ??
                              const <_IndexedCourse>[]),
                        ];
                        final allDisplayCourses = dayDisplayData[dayIndex];
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) {
                              final row =
                                  (details.localPosition.dy / cellHeight)
                                      .floor()
                                      .clamp(
                                        0,
                                        visibleSessions.length - 1,
                                      );
                              final session = visibleSessions[row];
                              final hasHit = allDayCourses.any(
                                (entry) =>
                                    _indexedCourseHitsSession(entry, session),
                              );
                              if (!hasHit && widget.onEmptyTap != null) {
                                widget.onEmptyTap!(weekday, session);
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
                                  return Positioned(
                                    key: ValueKey(display.animationKey),
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    height: height,
                                    // Each card gets its own compositing layer so
                                    // the continuously-running conflict countdown
                                    // bar only repaints this card instead of the
                                    // whole week grid on every frame.
                                    child: RepaintBoundary(
                                      child: CourseCard(
                                        key: ValueKey(display.animationKey),
                                        course: course,
                                        countdownAnimation: display.isConflict
                                            ? widget.countdownAnimation
                                            : null,
                                        muted: !isCurrentWeek,
                                        courseOpacity: isCurrentWeek
                                            ? courseOpacity
                                            : nonCurrentCourseOpacity,
                                        courseBorderOpacity: isCurrentWeek
                                            ? courseBorderOpacity
                                            : nonCurrentCourseBorderOpacity,
                                        borderColor: widget.borderColor,
                                        borderWidth: widget.borderWidth,
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
                                      onTap: widget.onCourseTap != null
                                          ? () => widget.onCourseTap!(
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

  /// Rebuilds the cached per-weekday slot layout only when the inputs that
  /// determine the grouping change. `rotationTick` is intentionally excluded:
  /// picking a conflict variant from the cache is cheap and done in build.
  void _ensureLayout(
    List<Course> courses,
    int week,
    bool showNonCurrentWeekCourses,
  ) {
    final key = _GridLayoutCacheKey(courses, week, showNonCurrentWeekCourses);
    if (_layoutKey == key && _daySlots != null) return;

    _layoutKey = key;
    final currentByWeekday = <int, List<_IndexedCourse>>{};
    final otherByWeekday = <int, List<_IndexedCourse>>{};
    for (int index = 0; index < courses.length; index++) {
      final course = courses[index];
      final entry = _IndexedCourse(
        sourceIndex: index,
        course: course,
        isCurrentWeek: course.isInWeek(week),
      );
      final map = entry.isCurrentWeek ? currentByWeekday : otherByWeekday;
      map.putIfAbsent(course.weekday, () => []).add(entry);
    }

    final daySlots = <int, List<_DaySlot>>{};
    for (int weekday = 1; weekday <= 7; weekday++) {
      final allDayCourses = <_IndexedCourse>[
        ...(currentByWeekday[weekday] ?? const <_IndexedCourse>[]),
        ...(showNonCurrentWeekCourses
            ? (otherByWeekday[weekday] ?? const <_IndexedCourse>[])
            : const <_IndexedCourse>[]),
      ];
      daySlots[weekday] = _buildDaySlots(allDayCourses);
    }
    _daySlots = daySlots;
  }
}

class _GridLayoutCacheKey {
  final List<Course> courses;
  final int week;
  final bool showNonCurrentWeekCourses;

  const _GridLayoutCacheKey(this.courses, this.week, this.showNonCurrentWeekCourses);

  @override
  bool operator ==(Object other) =>
      other is _GridLayoutCacheKey &&
      identical(courses, other.courses) &&
      week == other.week &&
      showNonCurrentWeekCourses == other.showNonCurrentWeekCourses;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(courses), week, showNonCurrentWeekCourses);
}

bool _indexedCourseHitsSession(_IndexedCourse entry, int session) {
  return session >= entry.course.startSession &&
      session <= entry.course.endSession;
}

/// The EXPENSIVE part: sort, group overlapping courses and precompute the
/// conflict variants (with backtracking). Cached per (courses, week, showNon).
List<_DaySlot> _buildDaySlots(List<_IndexedCourse> dayCourses) {
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

  final slots = <_DaySlot>[];
  for (final group in groups) {
    if (group.length == 1) {
      slots.add(_DaySlot.solo(group.first));
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

    slots.add(_DaySlot.group(group, currentVariants, otherVariants));
  }

  return slots;
}

/// The CHEAP part: pick the variant index from the cached slots and produce the
/// flat list of display courses. Runs on every build (including every countdown
/// wrap) but does no sorting/grouping/backtracking.
List<_DisplayCourse> _selectDayDisplays(
  List<_DaySlot> slots,
  int rotationTick,
) {
  final displayCourses = <_DisplayCourse>[];
  for (final slot in slots) {
    if (slot.solo) {
      final entry = slot.all.first;
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

    final variants = [...slot.currentVariants, ...slot.otherVariants];
    final effectiveVariants = variants.isEmpty
        ? [slot.all.take(1).toList()]
        : variants;
    final selectedVariantIndex = rotationTick % effectiveVariants.length;
    final selectedVariant = effectiveVariants[selectedVariantIndex];
    final isMuted =
        selectedVariantIndex >= slot.currentVariants.length &&
        slot.otherVariants.isNotEmpty;

    for (final entry in selectedVariant) {
      displayCourses.add(
        _DisplayCourse(
          course: entry.course,
          sourceIndex: entry.sourceIndex,
          tapStartSession: entry.course.startSession,
          tapSessionSpan: entry.course.sessionSpan,
          isConflict: effectiveVariants.length > 1,
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

/// A per-day slot: either a single (non-conflicting) course or an overlapping
/// group whose display alternatives have already been computed.
class _DaySlot {
  final List<_IndexedCourse> all;
  final List<List<_IndexedCourse>> currentVariants;
  final List<List<_IndexedCourse>> otherVariants;
  final bool solo;

  _DaySlot.solo(_IndexedCourse entry)
    : all = [entry],
      currentVariants = const [],
      otherVariants = const [],
      solo = true;

  _DaySlot.group(this.all, this.currentVariants, this.otherVariants)
    : solo = false;
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
