import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../models/school_calendar.dart';
import '../ui/app_components.dart';

/// 课表顶部周信息：显示当前日期与第 N 周。
class WeekHeader extends StatelessWidget {
  final SemesterCalendar calendar;
  final int selectedWeek;
  final VoidCallback? onJumpToCurrentWeek;
  final int? currentWeek;
  final VoidCallback? onToggleSchedule;
  final bool showingSecondarySchedule;
  final String secondaryScheduleTitle;

  /// 未登录时不显示「第 N 周 / 未开学」，仅保留日期。
  final bool showWeekNumber;

  const WeekHeader({
    super.key,
    required this.calendar,
    required this.selectedWeek,
    this.onJumpToCurrentWeek,
    this.currentWeek,
    this.onToggleSchedule,
    this.showingSecondarySchedule = false,
    this.secondaryScheduleTitle = '正在预览第二课表',
    this.showWeekNumber = true,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final theme = context.theme;
    final cw = calendar.weekOf(today);
    final beforeStart = cw <= 0;

    return AppContentFrame(
      safeArea: false,
      topPadding: AppSpacing.xs,
      bottomPadding: AppSpacing.xs,
      child: ConstrainedBox(
        // Keep the header height stable whether or not the optional week
        // buttons are visible; the timetable height depends on it.
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              child: showingSecondarySchedule
                  ? Text(
                      secondaryScheduleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.tileTitle.copyWith(
                        color: theme.colors.foreground,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${today.year}/${today.month}/${today.day}',
                          style: theme.typography.pageTitle.copyWith(
                            color: theme.colors.foreground,
                          ),
                        ),
                        if (showWeekNumber) ...[
                          const SizedBox(height: AppSpacing.micro),
                          Text(
                            beforeStart ? '未开学' : '第$selectedWeek周',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (currentWeek != null &&
                currentWeek != selectedWeek &&
                onJumpToCurrentWeek != null)
              AppIconButton(
                icon: selectedWeek < currentWeek!
                    ? FLucideIcons.arrowRight
                    : FLucideIcons.arrowLeft,
                onPress: onJumpToCurrentWeek,
                tooltip: '回到当前周',
              ),
            if (onToggleSchedule != null)
              AppIconButton(
                icon: FLucideIcons.arrowLeftRight,
                onPress: onToggleSchedule,
                tooltip: showingSecondarySchedule ? '切换到主课表' : '切换到第二课表',
              ),
          ],
        ),
      ),
    );
  }
}
