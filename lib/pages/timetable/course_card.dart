import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../ui/app_components.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final Animation<double>? countdownAnimation;
  final bool muted;
  final double courseOpacity;
  final double courseBorderOpacity;
  final Color borderColor;
  final double borderWidth;

  const CourseCard({
    super.key,
    required this.course,
    this.countdownAnimation,
    this.muted = false,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
    required this.borderColor,
    this.borderWidth = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = course.color.withAlpha((255 * courseOpacity).round());
    final borderRadius = BorderRadius.circular(6);
    final textColor = muted
        ? context.theme.colors.mutedForeground
        : context.theme.colors.semantic.timetableForeground;
    final secondaryTextColor = muted
        ? context.theme.colors.mutedForeground
        : context.theme.colors.semantic.timetableMutedForeground;
    final effectiveBorderColor = borderColor.withAlpha(
      (255 * courseBorderOpacity).round(),
    );

    return Container(
      margin: const EdgeInsets.all(1.8),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: courseBorderOpacity > 0
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: double.infinity,
              child: Padding(
                padding: EdgeInsets.only(
                  top: countdownAnimation == null ? 0 : 7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      course.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 4 / 3,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (course.place.isNotEmpty)
                      Text(
                        '@${course.place}',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                          height: 14 / 11,
                          letterSpacing: 0,
                        ),
                      ),
                    if (course.campus.isNotEmpty)
                      Text(
                        course.campus,
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                          height: 14 / 11,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (countdownAnimation != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                child: SizedBox(
                  width: 48,
                  height: 3,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: countdownAnimation!,
                      builder: (context, child) {
                        final remaining = (1 - countdownAnimation!.value)
                            .clamp(0.0, 1.0)
                            .toDouble();
                        return CustomPaint(
                          painter: _CountdownBarPainter(
                            progress: remaining,
                            backgroundColor:
                                context.theme.colors.semantic.warningContainer,
                            progressColor: context.theme.colors.destructive,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownBarPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  const _CountdownBarPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final radius = size.height / 2;
    final startX = radius;
    final endX = size.width - radius;
    if (endX <= startX) return;

    final backgroundPaint = Paint()
      ..color = backgroundColor
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
      ..color = progressColor
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
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}
