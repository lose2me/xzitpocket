import 'package:flutter/material.dart';

import '../utils/week_calculator.dart';

class WeekHeader extends StatelessWidget {
  final DateTime semesterStart;
  final int selectedWeek;
  final int totalWeeks;
  final VoidCallback? onSync;

  const WeekHeader({
    super.key,
    required this.semesterStart,
    required this.selectedWeek,
    required this.totalWeeks,
    this.onSync,
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
                  isBeforeStart
                      ? '第$selectedWeek周 · 未开学'
                      : '第$selectedWeek周',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Right: action button
          IconButton(
            icon: const Icon(Icons.sync, size: 22),
            onPressed: onSync,
            tooltip: '同步课表',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
