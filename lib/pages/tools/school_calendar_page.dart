import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/school_calendar.dart';
import '../../ui/app_components.dart';

/// 校历展示页：连续网格（不按月分块），每月 1 日用「9.1/10.1」标注。
/// 左侧一整条「周」栏带浅色背景，与右侧日期网格平衡；表头「周」不落在背景上。
class SchoolCalendarPage extends StatelessWidget {
  const SchoolCalendarPage({super.key});

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  static const _weekLabelWidth = 28.0;
  static const _rowHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final calendar = semesterCalendar;
    final days = calendar.days;
    if (days.isEmpty) {
      return AppPage(
        title: '校历',
        child: AppPageBody(
          child: AppStateView(icon: FLucideIcons.calendarOff, title: '校历数据为空'),
        ),
      );
    }

    return AppPage(
      title: '26上学期校历',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: 0,
        bottomPadding: AppSpacing.xxl,
        children: [
          // 图例靠左，右侧提示文字；整体上移。
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(
                    theme,
                    theme.colors.semantic.warningContainer,
                    '周末',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _legendDot(theme, theme.colors.secondary, '节假日'),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '实际安排可能会发生变动，如调休',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildGrid(theme, calendar),
        ],
      ),
    );
  }

  Widget _legendDot(FThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  /// 整体网格：表头「周 + 一二三四五六日」在无背景行；下方是「左栏周列（连续背景）+ 日期网格」。
  Widget _buildGrid(FThemeData theme, SemesterCalendar calendar) {
    final days = calendar.days;
    final offset = days.first.date.weekday - 1; // 1=周一 → 第 0 列
    final rowItems = <SchoolDay?>[...List.filled(offset, null), ...days];
    while (rowItems.length % 7 != 0) {
      rowItems.add(null);
    }
    final rowCount = rowItems.length ~/ 7;

    final headerStyle = theme.typography.caption.copyWith(
      color: theme.colors.mutedForeground,
    );

    // 表头：周 + 一二三四五六日（不落在背景上）
    final headerRow = Row(
      children: [
        SizedBox(
          width: _weekLabelWidth,
          child: Center(child: Text('周', style: headerStyle)),
        ),
        for (final label in _weekdayLabels)
          Expanded(
            child: Center(child: Text(label, style: headerStyle)),
          ),
      ],
    );

    // 周列：连续背景，只在表格下方，数字居中
    final weekCells = <Widget>[];
    for (var i = 0; i < rowCount; i++) {
      final real = rowItems.sublist(i * 7, i * 7 + 7).whereType<SchoolDay>();
      final week = real.isEmpty ? '' : '${calendar.weekOf(real.first.date)}';
      weekCells.add(
        SizedBox(
          height: _rowHeight,
          child: Center(
            child: Text(
              week,
              style: headerStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    final weekColumn = Container(
      width: _weekLabelWidth,
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: weekCells),
    );

    // 日期行
    final dayRows = <Widget>[];
    for (var i = 0; i < rowItems.length; i += 7) {
      final weekRow = rowItems.sublist(i, i + 7);
      dayRows.add(
        SizedBox(
          height: _rowHeight,
          child: Row(
            children: [
              for (final item in weekRow)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: item == null
                        ? const SizedBox.shrink()
                        : _dayCell(theme, item),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerRow,
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            weekColumn,
            const SizedBox(width: 4),
            Expanded(child: Column(children: dayRows)),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(FThemeData theme, SchoolDay day) {
    final isFestival = day.festival != null;
    final isMonthStart = day.date.day == 1;
    final isWeekend = day.weekday == 6 || day.weekday == 7;

    // 节假日/特殊节日（含非周末的放假日）用主题浅粉；周末(周六/日)用之前琥珀色。
    final Color bg;
    final Color fg;
    if (isFestival || (day.holiday && !isWeekend)) {
      bg = theme.colors.secondary;
      fg = theme.colors.secondaryForeground;
    } else if (day.holiday) {
      bg = theme.colors.semantic.warningContainer;
      fg = theme.colors.semantic.onWarningContainer;
    } else {
      bg = theme.colors.card;
      fg = theme.colors.foreground;
    }
    // 每月 1 日用「月.日」标注，其余显示日号。
    final label = isMonthStart
        ? '${day.date.month}.${day.date.day}'
        : '${day.date.day}';

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colors.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.sm.copyWith(
              color: fg,
              fontWeight: isMonthStart || isFestival
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          if (isFestival)
            Text(
              day.festival!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(
                color: fg,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
