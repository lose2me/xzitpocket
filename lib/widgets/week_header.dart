import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../models/school_calendar.dart';
import '../ui/app_components.dart';

/// 课表顶部周信息：显示当前日期、第 N 周、该周日期范围与节日（数据来自校历）。
class WeekHeader extends StatelessWidget {
  final SemesterCalendar calendar;
  final int selectedWeek;
  final VoidCallback? onSync;

  const WeekHeader({
    super.key,
    required this.calendar,
    required this.selectedWeek,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final theme = context.theme;
    final cw = calendar.weekOf(today);
    final beforeStart = cw <= 0;

    final safeWeek = selectedWeek.clamp(1, calendar.totalWeeks);
    final (monday, sunday) = beforeStart
        ? (today, today)
        : calendar.weekRange(safeWeek);
    final festivals = beforeStart
        ? const <String>[]
        : calendar.festivalNamesInWeek(safeWeek);
    final rangeText = beforeStart
        ? ''
        : '${monday.month}/${monday.day}–${sunday.month}/${sunday.day}';
    final festivalText = festivals.isEmpty ? '' : '  ·  ${festivals.join('、')}';

    return AppContentFrame(
      safeArea: false,
      topPadding: AppSpacing.xs,
      bottomPadding: AppSpacing.xs,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${today.year}/${today.month}/${today.day}',
                  style: theme.typography.pageTitle.copyWith(
                    color: theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  beforeStart
                      ? '未开学'
                      : '第$selectedWeek周 $rangeText$festivalText',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: FLucideIcons.refreshCw,
            onPress: onSync,
            tooltip: '同步课表',
          ),
        ],
      ),
    );
  }
}
