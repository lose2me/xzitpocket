import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../services/power_service.dart';
import '../ui/app_components.dart';

class PowerUsageChart extends StatelessWidget {
  final List<PowerDailyUsage> usage;
  final bool showMoney;
  final String price;

  const PowerUsageChart({
    super.key,
    required this.usage,
    required this.showMoney,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 30));
    final unitPrice = double.tryParse(price) ?? 1;
    final points =
        usage
            .map((item) => (item, double.tryParse(item.usage)))
            .where((entry) => entry.$2 != null)
            .map(
              (entry) =>
                  (entry.$1, showMoney ? entry.$2! * unitPrice : entry.$2!),
            )
            .where((entry) {
              final date = entry.$1.dateValue;
              return !date.isBefore(cutoff) && !date.isAfter(today);
            })
            .toList()
          ..sort((a, b) => a.$1.dateValue.compareTo(b.$1.dateValue));
    final colors = context.theme.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: points.isEmpty
          ? SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  '暂无可绘制的用电记录',
                  style: context.theme.typography.bodySmall.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            )
          : SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _PowerUsageChartPainter(
                  points: points,
                  lineColor: colors.primary,
                  gridColor: colors.border,
                  labelColor: colors.mutedForeground,
                ),
              ),
            ),
    );
  }
}

class _PowerUsageChartPainter extends CustomPainter {
  final List<(PowerDailyUsage, double)> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  const _PowerUsageChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = points.fold<double>(
      1,
      (max, point) => point.$2 > max ? point.$2 : max,
    );
    final gridPaint = Paint()
      ..color = gridColor.withAlpha(130)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotPaint = Paint()..color = lineColor;

    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawLabel(
        canvas,
        (maxValue * i / 3).toStringAsFixed(1),
        Offset(0, y - 7),
        alignRight: true,
      );
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y = chart.bottom - chart.height * (points[i].$2 / maxValue);
      final point = Offset(x, y);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(point, 3.2, dotPaint);
      final interval = (points.length / 5).ceil().clamp(1, points.length);
      if (i == 0 || i == points.length - 1 || i % interval == 0) {
        final date = points[i].$1.dateValue;
        _drawLabel(
          canvas,
          '${date.month}/${date.day}',
          Offset(x, chart.bottom + 7),
        );
      }
    }
    canvas.drawPath(path, linePaint);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? offset.dx : offset.dx - painter.width / 2;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _PowerUsageChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
