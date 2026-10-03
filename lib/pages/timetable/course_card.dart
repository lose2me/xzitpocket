import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../constants/time_slots.dart';
import '../../models/course.dart';
import '../../ui/app_components.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final Animation<double>? countdownAnimation;
  final bool muted;
  final double courseOpacity;
  final double courseBorderOpacity;
  final double textSize;
  final double textOpacity;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;
  final double innerPadding;
  final double outerPadding;
  final Color? textColor;
  final bool showStartTime;
  final bool hideLocation;
  final bool hideTeacher;
  final bool hideTeacherBrackets;
  final bool removeLocationAt;
  final bool centerHorizontal;
  final bool centerVertical;
  final String borderType;

  const CourseCard({
    super.key,
    required this.course,
    this.countdownAnimation,
    this.muted = false,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
    this.textSize = 12.0,
    this.textOpacity = 1.0,
    required this.borderColor,
    this.borderWidth = 0.5,
    this.cornerRadius = 6,
    this.innerPadding = 2,
    this.outerPadding = 1.8,
    this.textColor,
    this.showStartTime = false,
    this.hideLocation = false,
    this.hideTeacher = true,
    this.hideTeacherBrackets = true,
    this.removeLocationAt = false,
    this.centerHorizontal = false,
    this.centerVertical = false,
    this.borderType = 'solid',
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = course.color.withAlpha((255 * courseOpacity).round());
    final borderRadius = BorderRadius.circular(cornerRadius);
    // Course colors are intentionally soft pastels in light mode and may be
    // user-defined. Choose text by the card's own luminance so dark mode does
    // not put light text on a pale course card (or vice versa).
    final useDarkText = course.color.computeLuminance() > 0.45;
    final resolvedTextColor =
        textColor ??
        (useDarkText ? const Color(0xFF172033) : const Color(0xFFF8FAFC));
    final effectiveTextColor = resolvedTextColor.withValues(alpha: textOpacity);
    final secondaryTextColor = textColor == null
        ? (useDarkText ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
              .withValues(alpha: textOpacity)
        : resolvedTextColor.withValues(alpha: 0.72 * textOpacity);
    final effectiveBorderColor = borderColor.withAlpha(
      (255 * courseBorderOpacity).round(),
    );

    final card = Container(
      padding: EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: Padding(
              padding: EdgeInsets.only(top: countdownAnimation == null ? 0 : 7),
              child: Column(
                crossAxisAlignment: centerHorizontal
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                mainAxisAlignment: centerVertical
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: FontWeight.w600,
                      color: effectiveTextColor,
                      height: 4 / 3,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (showStartTime)
                    Text(
                      '${course.startSession} ${_startTime(course.startSession)}',
                      style: TextStyle(
                        fontSize: textSize * 11 / 12,
                        color: secondaryTextColor,
                        height: 14 / 11,
                        letterSpacing: 0,
                      ),
                    ),
                  if (!hideLocation && course.place.isNotEmpty)
                    Text(
                      '${removeLocationAt ? '' : '@'}${course.place}',
                      style: TextStyle(
                        fontSize: textSize * 11 / 12,
                        color: secondaryTextColor,
                        height: 14 / 11,
                        letterSpacing: 0,
                      ),
                    ),
                  if (!hideLocation && course.campus.isNotEmpty)
                    Text(
                      course.campus,
                      style: TextStyle(
                        fontSize: textSize * 11 / 12,
                        color: secondaryTextColor,
                        height: 14 / 11,
                        letterSpacing: 0,
                      ),
                    ),
                  if (!hideTeacher && course.teacher.isNotEmpty)
                    Text(
                      hideTeacherBrackets
                          ? course.teacher
                          : '【${course.teacher}】',
                      style: TextStyle(
                        fontSize: textSize * 11 / 12,
                        color: secondaryTextColor,
                        height: 14 / 11,
                        letterSpacing: 0,
                      ),
                    ),
                ],
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
    final decorated = borderType != 'none' && courseBorderOpacity > 0
        ? CustomPaint(
            foregroundPainter: _CourseBorderPainter(
              color: effectiveBorderColor,
              width: borderWidth,
              radius: cornerRadius,
              dashed: borderType == 'dashed',
            ),
            child: card,
          )
        : card;
    return Container(margin: EdgeInsets.all(outerPadding), child: decorated);
  }

  String _startTime(int session) => kTimeSlots
      .firstWhere(
        (slot) => slot.index == session,
        orElse: () => kTimeSlots.first,
      )
      .start;
}

class _CourseBorderPainter extends CustomPainter {
  final Color color;
  final double width;
  final double radius;
  final bool dashed;

  const _CourseBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
    required this.dashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= width || size.height <= width) return;
    final inset = width / 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset(inset, inset) & Size(size.width - width, size.height - width),
          Radius.circular((radius - inset).clamp(0, double.infinity)),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      const dashLength = 5.0;
      const gapLength = 3.0;
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dashLength + gapLength
      ) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dashLength).clamp(0, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CourseBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.radius != radius ||
      oldDelegate.dashed != dashed;
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
