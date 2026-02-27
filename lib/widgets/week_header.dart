import 'package:flutter/material.dart';

import '../utils/week_calculator.dart';

class WeekHeader extends StatelessWidget {
  final DateTime semesterStart;
  final int selectedWeek;
  final int totalWeeks;
  final ValueChanged<int> onWeekChanged;

  const WeekHeader({
    super.key,
    required this.semesterStart,
    required this.selectedWeek,
    required this.totalWeeks,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dates = weekDates(semesterStart, selectedWeek);
    final today = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final theme = Theme.of(context);

    return Column(
      children: [
        // Week selector row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: selectedWeek > 1
                    ? () => onWeekChanged(selectedWeek - 1)
                    : null,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showWeekPicker(context),
                  child: Text(
                    '第 $selectedWeek 周',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: selectedWeek < totalWeeks
                    ? () => onWeekChanged(selectedWeek + 1)
                    : null,
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        // Weekday headers
        Row(
          children: [
            const SizedBox(width: 36), // space for time column
            ...List.generate(7, (i) {
              final date = dates[i];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: isToday
                      ? BoxDecoration(
                          color:
                              theme.colorScheme.primaryContainer.withAlpha(128),
                        )
                      : null,
                  child: Column(
                    children: [
                      Text(
                        '${weekdays[i]}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.normal,
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
      ],
    );
  }

  void _showWeekPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: totalWeeks,
            itemBuilder: (ctx, index) {
              final week = index + 1;
              final isCurrent = week == selectedWeek;
              return InkWell(
                onTap: () {
                  onWeekChanged(week);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '$week',
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
