import 'package:flutter/material.dart';

import '../utils/week_calculator.dart';

class WeekHeader extends StatelessWidget {
  final DateTime semesterStart;
  final int selectedWeek;
  final bool showNonCurrentWeekCourses;
  final VoidCallback? onToggleShowNonCurrentWeekCourses;
  final VoidCallback? onSync;
  final VoidCallback? onOpenSettings;

  const WeekHeader({
    super.key,
    required this.semesterStart,
    required this.selectedWeek,
    required this.showNonCurrentWeekCourses,
    this.onToggleShowNonCurrentWeekCourses,
    this.onSync,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final theme = Theme.of(context);

    final cw = currentWeek(semesterStart);
    final isBeforeStart = cw <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Left: date and week info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${today.year}/${today.month}/${today.day}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBeforeStart ? '第$selectedWeek周 · 未开学' : '第$selectedWeek周',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              showNonCurrentWeekCourses ? Icons.layers : Icons.layers_outlined,
              size: 22,
              color: showNonCurrentWeekCourses
                  ? theme.colorScheme.primary
                  : null,
            ),
            onPressed: onToggleShowNonCurrentWeekCourses,
            tooltip: showNonCurrentWeekCourses ? '隐藏非本周课表' : '显示非本周课表',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.sync, size: 22),
            onPressed: onSync,
            tooltip: '同步课表',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 22),
            onPressed: onOpenSettings,
            tooltip: '课表设置',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
