import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../models/school_calendar.dart';
import '../../ui/app_tokens.dart';
import 'course_card.dart';
import 'time_column.dart';

class TimetableDayDragData {
  final int week;
  final int weekday;

  const TimetableDayDragData({required this.week, required this.weekday});
}

class TimetableDayActionIndicator {
  final int weekday;
  final String label;
  final int seconds;
  final double progress;

  const TimetableDayActionIndicator({
    required this.weekday,
    required this.label,
    required this.seconds,
    required this.progress,
  });
}

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
  final void Function(int weekday)? onDayDoubleTap;
  final void Function(int weekday)? onDayTripleTap;
  final void Function(TimetableDayDragData data, int targetWeekday)? onDayDrop;
  final ValueChanged<Offset>? onDayDragUpdate;
  final VoidCallback? onDayDragStart;
  final VoidCallback? onDayDragEnd;
  final TimetableDayActionIndicator? pendingDayAction;
  final ValueChanged<int>? onPendingDayActionCancel;
  final Set<int> adjustedWeekdays;
  final bool suppressDayDrop;
  final Animation<double>? countdownAnimation;
  final Color borderColor;
  final double borderWidth;
  final double courseOpacity;
  final double courseBorderOpacity;
  final double courseTextSize;
  final double timeTextSize;
  final double dateTextSize;
  final double gridOpacity;
  final bool showTodayGridLines;
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final bool showGridLines;

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
    this.onDayDoubleTap,
    this.onDayTripleTap,
    this.onDayDrop,
    this.onDayDragUpdate,
    this.onDayDragStart,
    this.onDayDragEnd,
    this.pendingDayAction,
    this.onPendingDayActionCancel,
    this.adjustedWeekdays = const {},
    this.suppressDayDrop = false,
    this.countdownAnimation,
    required this.borderColor,
    this.borderWidth = 0.5,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
    this.courseTextSize = 12.0,
    this.timeTextSize = 11.0,
    this.dateTextSize = 12.0,
    this.gridOpacity = 0.5,
    this.showTodayGridLines = false,
    this.backgroundImagePath,
    this.backgroundOpacity = 0.5,
    this.showGridLines = true,
  });

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  _GridLayoutCacheKey? _layoutKey;
  Map<int, List<_DaySlot>>? _daySlots;
  late final ScrollController _scrollController;
  int? _dragSourceWeekday;
  int? _dragHoverWeekday;
  bool _showBelowFoldIndicator = true;
  Timer? _headerTapTimer;
  int _headerTapCount = 0;
  int? _headerTapWeekday;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _headerTapTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final show = !_scrollController.hasClients || _scrollController.offset <= 4;
    if (!mounted || show == _showBelowFoldIndicator) return;
    setState(() => _showBelowFoldIndicator = show);
  }

  void _startColumnDrag(int weekday) {
    if (!mounted) return;
    setState(() {
      _dragSourceWeekday = weekday;
      _dragHoverWeekday = null;
    });
  }

  void _hoverColumnDrag(int weekday, bool accepting) {
    final next = accepting && _dragSourceWeekday != weekday ? weekday : null;
    if (!mounted || next == _dragHoverWeekday) return;
    setState(() => _dragHoverWeekday = next);
  }

  void _acceptColumnDrop(int targetWeekday, TimetableDayDragData data) {
    if (data.week != widget.week || data.weekday != targetWeekday) {
      widget.onDayDrop?.call(data, targetWeekday);
    }
    _finishColumnDrag();
  }

  void _finishColumnDrag() {
    if (!mounted) return;
    setState(() {
      _dragSourceWeekday = null;
      _dragHoverWeekday = null;
    });
  }

  void _handleHeaderTap(int weekday) {
    if (_headerTapWeekday == weekday &&
        _headerTapTimer != null &&
        _headerTapCount > 0) {
      _headerTapCount++;
    } else {
      _headerTapCount = 1;
      _headerTapWeekday = weekday;
    }
    _headerTapTimer?.cancel();
    if (_headerTapCount >= 3) {
      _headerTapCount = 0;
      _headerTapWeekday = null;
      widget.onDayTripleTap?.call(weekday);
      return;
    }
    _headerTapTimer = Timer(const Duration(milliseconds: 360), () {
      if (_headerTapCount == 2 && _headerTapWeekday == weekday) {
        widget.onDayDoubleTap?.call(weekday);
      }
      _headerTapCount = 0;
      _headerTapWeekday = null;
      _headerTapTimer = null;
    });
  }

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

    final content = Column(
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
                    fontSize: widget.dateTextSize,
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
                child: _buildDayHeader(
                  context,
                  weekday: i + 1,
                  date: date,
                  weekdayLabel: weekdays[i],
                  isToday: isToday,
                  canDrag: currentByWeekday[i + 1]?.isNotEmpty == true,
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
                controller: _scrollController,
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    children: [
                      TimeColumn(
                        cellHeight: cellHeight,
                        slotCount: widget.slotCount,
                        hiddenSlots: widget.hiddenSlots,
                        textSize: widget.timeTextSize,
                      ),
                      ...List.generate(dayCount, (dayIndex) {
                        final weekday = dayIndex + 1;
                        final date = dates[dayIndex];
                        final isToday =
                            date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;
                        final allDayCourses = <_IndexedCourse>[
                          ...(currentByWeekday[weekday] ??
                              const <_IndexedCourse>[]),
                          ...(otherByWeekday[weekday] ??
                              const <_IndexedCourse>[]),
                        ];
                        final allDisplayCourses = dayDisplayData[dayIndex];
                        return Expanded(
                          child: _wrapColumnDropTarget(
                            weekday: weekday,
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
                                if (!hasHit && widget.onEmptyTap != null) {
                                  widget.onEmptyTap!(weekday, session);
                                }
                              },
                              child: Stack(
                                children: [
                                  if (widget.showGridLines)
                                    Column(
                                      children: List.generate(
                                        effectiveSlotCount,
                                        (i) {
                                          return Container(
                                            height: cellHeight,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: theme.colors.border
                                                      .withValues(
                                                        alpha:
                                                            widget.gridOpacity,
                                                      ),
                                                  width: 0.5,
                                                ),
                                                right: BorderSide(
                                                  color: theme.colors.border
                                                      .withValues(
                                                        alpha:
                                                            widget.gridOpacity,
                                                      ),
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
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
                                          textSize: widget.courseTextSize,
                                        ),
                                      ),
                                    );
                                  }),
                                  if (_showBelowFoldIndicator &&
                                      sessionToRow.containsKey(11) &&
                                      _hasLaterCourse(
                                        currentByWeekday[weekday],
                                      ) &&
                                      !_hasSession(
                                        currentByWeekday[weekday],
                                        11,
                                      ))
                                    Positioned(
                                      top: sessionToRow[11]! * cellHeight,
                                      left: 0,
                                      right: 0,
                                      height: cellHeight,
                                      child: IgnorePointer(
                                        child: Center(
                                          child: Icon(
                                            FLucideIcons.chevronsDown,
                                            size: 18,
                                            color: theme.colors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isToday && widget.showTodayGridLines)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              width: 1,
                                              child: ColoredBox(
                                                color: theme.colors.primary
                                                    .withValues(
                                                      alpha: widget.gridOpacity,
                                                    ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              bottom: 0,
                                              width: 1,
                                              child: ColoredBox(
                                                color: theme.colors.primary
                                                    .withValues(
                                                      alpha: widget.gridOpacity,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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

    final backgroundPath = widget.backgroundImagePath;
    final result = backgroundPath == null || backgroundPath.isEmpty
        ? content
        : Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: widget.backgroundOpacity.clamp(0.0, 1.0).toDouble(),
                  child: Image.file(
                    File(backgroundPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              ),
              content,
            ],
          );
    return MediaQuery.withNoTextScaling(child: result);
  }

  Widget _buildDayHeader(
    BuildContext context, {
    required int weekday,
    required DateTime date,
    required String weekdayLabel,
    required bool isToday,
    required bool canDrag,
  }) {
    final theme = context.theme;
    final highlighted = !widget.suppressDayDrop && _dragHoverWeekday == weekday;
    final adjusted = widget.adjustedWeekdays.contains(weekday);
    final pending = widget.pendingDayAction?.weekday == weekday
        ? widget.pendingDayAction
        : null;
    final header = GestureDetector(
      onTap: pending == null
          ? () => _handleHeaderTap(weekday)
          : () => widget.onPendingDayActionCancel?.call(weekday),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted
              ? theme.colors.primary.withValues(alpha: 0.14)
              : adjusted
              ? theme.colors.primary.withValues(alpha: 0.10)
              : isToday
              ? theme.colors.secondary.withAlpha(128)
              : null,
        ),
        child: ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              pending == null
                  ? _buildDayHeaderDate(
                      theme,
                      date: date,
                      weekdayLabel: weekdayLabel,
                      isToday: isToday,
                    )
                  : _buildPendingDayAction(theme, pending),
              if (adjusted && pending == null)
                Positioned(
                  top: 2,
                  right: 3,
                  child: Text(
                    '调',
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final dragChild = LongPressDraggable<TimetableDayDragData>(
      data: TimetableDayDragData(week: widget.week, weekday: weekday),
      onDragStarted: () {
        _startColumnDrag(weekday);
        widget.onDayDragStart?.call();
      },
      onDragUpdate: (details) =>
          widget.onDayDragUpdate?.call(details.globalPosition),
      onDragEnd: (_) {
        _finishColumnDrag();
        widget.onDayDragEnd?.call();
      },
      feedback: Transform.translate(
        offset: const Offset(0, -72),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.primary.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '${date.month}/${date.day} 周$weekdayLabel',
                style: TextStyle(
                  color: theme.colors.primaryForeground,
                  fontSize: widget.dateTextSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.42, child: header),
      child: header,
    );
    return DragTarget<TimetableDayDragData>(
      onWillAcceptWithDetails: (details) {
        if (widget.suppressDayDrop) return false;
        final accepting =
            details.data.week != widget.week || details.data.weekday != weekday;
        _hoverColumnDrag(weekday, accepting);
        return accepting;
      },
      onLeave: (_) => _hoverColumnDrag(weekday, false),
      onAcceptWithDetails: (details) =>
          _acceptColumnDrop(weekday, details.data),
      builder: (context, candidateData, rejectedData) =>
          canDrag && pending == null ? dragChild : header,
    );
  }

  Widget _buildDayHeaderDate(
    FThemeData theme, {
    required DateTime date,
    required String weekdayLabel,
    required bool isToday,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        Text(
          '${date.day}',
          style: theme.typography.caption.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
            color: isToday
                ? theme.colors.primary
                : theme.colors.mutedForeground,
            fontSize: widget.dateTextSize,
          ),
        ),
        Text(
          weekdayLabel,
          style: theme.typography.caption.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
            color: isToday
                ? theme.colors.primary
                : theme.colors.mutedForeground,
            fontSize: widget.dateTextSize,
          ),
        ),
      ],
    ),
  );

  Widget _buildPendingDayAction(
    FThemeData theme,
    TimetableDayActionIndicator action,
  ) => Padding(
    padding: EdgeInsets.zero,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 18,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: action.progress,
                strokeWidth: 2,
                color: theme.colors.primary,
                backgroundColor: theme.colors.primary.withValues(alpha: 0.18),
              ),
              Center(
                child: Text(
                  '${action.seconds}s',
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          action.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: theme.typography.caption.copyWith(
            color: theme.colors.primary,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _wrapColumnDropTarget({required int weekday, required Widget child}) {
    return DragTarget<TimetableDayDragData>(
      onWillAcceptWithDetails: (details) {
        if (widget.suppressDayDrop) return false;
        final accepting =
            details.data.week != widget.week || details.data.weekday != weekday;
        _hoverColumnDrag(weekday, accepting);
        return accepting;
      },
      onLeave: (_) => _hoverColumnDrag(weekday, false),
      onAcceptWithDetails: (details) =>
          _acceptColumnDrop(weekday, details.data),
      builder: (context, candidateData, rejectedData) {
        final highlighted =
            !widget.suppressDayDrop && _dragHoverWeekday == weekday;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: _dragSourceWeekday == weekday ? 0.42 : 1,
              child: child,
            ),
            if (highlighted)
              IgnorePointer(
                child: ColoredBox(
                  color: context.theme.colors.primary.withValues(alpha: 0.08),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _hasLaterCourse(List<_IndexedCourse>? entries) =>
      entries?.any(
        (entry) => entry.course.sessions.any((session) => session >= 12),
      ) ??
      false;

  bool _hasSession(List<_IndexedCourse>? entries, int session) =>
      entries?.any((entry) => entry.course.sessions.contains(session)) ?? false;

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

  const _GridLayoutCacheKey(
    this.courses,
    this.week,
    this.showNonCurrentWeekCourses,
  );

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
