import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../constants/time_slots.dart';
import '../../ui/app_tokens.dart';

class TimeColumn extends StatelessWidget {
  final double cellHeight;
  final int slotCount;
  final Set<int> hiddenSlots;
  final double textSize;
  final double width;
  final bool hideSectionTime;
  final Color? textColor;
  final double textOpacity;

  /// 今日将要/正在上课的节次：文字用 [highlightColor] 标注（同日期标颜色），
  /// 背景用 [highlightBackground]（与今日日期格背景一致）。
  final Set<int> highlightedSlots;
  final Color? highlightColor;
  final Color? highlightBackground;

  const TimeColumn({
    super.key,
    required this.cellHeight,
    this.slotCount = 14,
    this.hiddenSlots = const {},
    this.textSize = 11.0,
    this.width = 40.0,
    this.hideSectionTime = false,
    this.textColor,
    this.textOpacity = 1.0,
    this.highlightedSlots = const {},
    this.highlightColor,
    this.highlightBackground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      width: width,
      child: Column(
        children: List.generate(slotCount, (i) {
          if (hiddenSlots.contains(i + 1)) return const SizedBox.shrink();
          final slot = kTimeSlots[i];
          final highlighted =
              highlightColor != null && highlightedSlots.contains(slot.index);
          final color = highlighted
              ? highlightColor!
              : (textColor ?? theme.colors.mutedForeground).withValues(
                  alpha: textOpacity,
                );
          return DecoratedBox(
            // 高亮节次的背景与今日日期格背景一致。
            decoration: BoxDecoration(
              color: highlighted ? highlightBackground : null,
            ),
            child: SizedBox(
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
                        fontSize: textSize,
                        height: 4 / 3,
                        fontWeight: highlighted
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (!hideSectionTime) ...[
                      Text(
                        slot.start,
                        style: theme.typography.caption.copyWith(
                          fontSize: textSize,
                          height: 14 / 11,
                          color: color,
                        ),
                      ),
                      Text(
                        slot.end,
                        style: theme.typography.caption.copyWith(
                          fontSize: textSize,
                          height: 14 / 11,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
