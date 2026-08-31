import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../constants/time_slots.dart';
import '../../ui/app_tokens.dart';

class TimeColumn extends StatelessWidget {
  final double cellHeight;
  final int slotCount;
  final Set<int> hiddenSlots;

  const TimeColumn({
    super.key,
    required this.cellHeight,
    this.slotCount = 14,
    this.hiddenSlots = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      width: 40,
      child: Column(
        children: List.generate(slotCount, (i) {
          if (hiddenSlots.contains(i + 1)) return const SizedBox.shrink();
          final slot = kTimeSlots[i];
          return SizedBox(
            height: cellHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${slot.index}',
                    style: theme.typography.caption.copyWith(
                      fontSize: 12,
                      height: 4 / 3,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  Text(
                    slot.start,
                    style: theme.typography.caption.copyWith(
                      fontSize: 11,
                      height: 14 / 11,
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  Text(
                    slot.end,
                    style: theme.typography.caption.copyWith(
                      fontSize: 11,
                      height: 14 / 11,
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
