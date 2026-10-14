import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../models/app_settings.dart';
import '../../models/school_calendar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/secondary_schedule_provider.dart';
import '../../ui/app_components.dart';
import '../../ui/home_layout.dart';
import '../../widgets/week_header.dart';
import 'timetable_grid.dart';
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

/// 设置页在全屏 Offstage 中复用主页布局，测量课表真实可用高度。
/// 不依赖被其他路由覆盖后暂停布局的主页，也不使用固定 chrome 常量。
class TimetableLayoutProbe extends ConsumerWidget {
  const TimetableLayoutProbe({super.key});

  static void _noop() {}
  static void _ignoreNavigation(int _) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    // 与真实课表一致：探针也用按本机比例缩放后的尺寸，测量才准确。
    final scaled = settings.scaledForViewport(MediaQuery.sizeOf(context));
    final background = settings.timetableBackgroundFor(
      Theme.of(context).brightness,
    );
    final showServices = !AppServiceFeature.values.every(
      settings.hiddenServiceFeatures.contains,
    );
    final query = normalizeHomeMediaQuery(MediaQuery.of(context))
        .copyWith(viewInsets: EdgeInsets.zero);
    final timetable = ListenableBuilder(
      listenable: semesterCalendar,
      builder: (context, _) => AppPage(
        root: true,
        child: SafeArea(
          child: Column(
            children: [
              TimetableWeekHeader(
                onSync: _noop,
                onJumpToCurrentWeek: _noop,
                onToggleSchedule: _noop,
              ),
              Expanded(
                child: TimetableGrid(
                  courses: const [],
                  week: 1,
                  calendar: semesterCalendar,
                  borderColor: context.theme.colors.border,
                  visibleSlots: kAdaptiveSectionCount,
                  sectionHeight: 0,
                  timeColumnWidth: scaled.timetableTimeColumnWidth,
                  dayHeaderHeight: scaled.timetableDayHeaderHeight,
                  dateTextSize: scaled.timetableDateTextSize,
                  hideDateUnderDay: settings.timetableHideDateUnderDay,
                  showHeaderDivider: background == null || background.isEmpty,
                  layoutOnly: true,
                  onAdaptiveSectionHeightChanged: (height) {
                    measuredAdaptiveSectionHeight.value = height;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return MediaQuery(
      data: query,
      child: Builder(
        builder: (context) => FScaffold(
          scaffoldStyle: const FScaffoldStyleDelta.delta(
            footerDecoration: DecorationDelta.value(BoxDecoration()),
          ),
          resizeToAvoidBottomInset: false,
          childPad: false,
          footer: buildHomeNavigationBar(
            showServices: showServices,
            transparent: background != null && background.isNotEmpty,
            index: 0,
            onChange: _ignoreNavigation,
          ),
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: timetable,
          ),
        ),
      ),
    );
  }
}
