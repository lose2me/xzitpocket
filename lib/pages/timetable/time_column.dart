import 'package:flutter/material.dart';

import '../../constants/time_slots.dart';

class TimeColumn extends StatelessWidget {
  final double cellHeight;
  final int slotCount;

  const TimeColumn({
    super.key,
    required this.cellHeight,
    this.slotCount = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 36,
      child: Column(
        children: List.generate(slotCount, (i) {
          final slot = kTimeSlots[i];
          return SizedBox(
            height: cellHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${slot.index}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  slot.start,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 8,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                  ),
                ),
                Text(
                  slot.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 8,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
