import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../ui/app_components.dart';
import '../utils/week_calculator.dart';

class WeekHeader extends StatelessWidget {
  final DateTime semesterStart;
  final int selectedWeek;
  final VoidCallback? onSync;

  const WeekHeader({
    super.key,
    required this.semesterStart,
    required this.selectedWeek,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final theme = context.theme;

    final cw = currentWeek(semesterStart);
    final isBeforeStart = cw <= 0;

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
                  isBeforeStart ? '未开学' : '第$selectedWeek周',
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
