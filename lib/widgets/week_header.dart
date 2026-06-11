import 'package:flutter/material.dart';

import '../utils/week_calculator.dart';

class WeekHeader extends StatelessWidget {
  final DateTime semesterStart;
  final int selectedWeek;
  final VoidCallback? onSync;
  final Animation<double>? countdownAnimation;
  final bool hasConflict;
  final bool isMutedConflict;

  const WeekHeader({
    super.key,
    required this.semesterStart,
    required this.selectedWeek,
    this.onSync,
    this.countdownAnimation,
    this.hasConflict = false,
    this.isMutedConflict = false,
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
                Row(
                  children: [
                    Text(
                      '${today.year}/${today.month}/${today.day}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasConflict && countdownAnimation != null) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 48,
                        height: 3,
                        child: AnimatedBuilder(
                          animation: countdownAnimation!,
                          builder: (context, child) {
                            final remaining = (1 - countdownAnimation!.value)
                                .clamp(0.0, 1.0)
                                .toDouble();
                            return CustomPaint(
                              painter: _CountdownBarPainter(
                                progress: remaining,
                                muted: isMutedConflict,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
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

class _CountdownBarPainter extends CustomPainter {
  final double progress;
  final bool muted;

  const _CountdownBarPainter({required this.progress, this.muted = false});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final radius = size.height / 2;
    final startX = radius;
    final endX = size.width - radius;
    if (endX <= startX) return;

    final bgColor = muted ? const Color(0xFFD6D6D6) : const Color(0xFFF6C9C9);
    final fgColor = muted ? const Color(0xFFB0B0B0) : const Color(0xFFE57373);

    final backgroundPaint = Paint()
      ..color = bgColor
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(startX, centerY),
      Offset(endX, centerY),
      backgroundPaint,
    );

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..color = fgColor
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final progressEndX = startX + (endX - startX) * progress;
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(progressEndX, centerY),
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownBarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.muted != muted;
  }
}
