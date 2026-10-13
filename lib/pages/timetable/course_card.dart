import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../constants/time_slots.dart';
import '../../models/course.dart';
import '../../utils/course_text_template.dart';

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
  final String textTemplate;
  final double dashedBorderDensity;
  final Color? textColor;
  final bool centerHorizontal;
  final bool centerVertical;
  final String borderType;
  final double countdownBarLengthRatio;
  final bool countdownBarRounded;
  final double countdownBarThickness;
  final double countdownBarPadding;
  final Color? countdownBarColor;

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
    this.outerPadding = 1.5,
    this.textTemplate = kDefaultCourseTextTemplate,
    this.dashedBorderDensity = 1.0,
    this.textColor,
    this.centerHorizontal = false,
    this.centerVertical = false,
    this.borderType = 'solid',
    this.countdownBarLengthRatio = 0.75,
    this.countdownBarRounded = true,
    this.countdownBarThickness = 3.0,
    this.countdownBarPadding = 0.0,
    this.countdownBarColor,
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

    final templateLines = parseCourseTemplate(textTemplate, {
      '课程': course.title,
      '教师': course.teacher,
      '地点': [
        course.place.trim(),
        course.campus.trim(),
      ].where((part) => part.isNotEmpty).join('\n'),
      '时间': _startTime(course.startSession),
    }).where((line) => !line.skip).toList();
    final brightness = context.theme.colors.brightness;
    // 加粗片段使用“标题”观感，普通片段使用旧版明细行观感，
    // 保证默认模板与旧默认展示一致。
    final boldStyle = TextStyle(
      fontSize: textSize,
      fontWeight: FontWeight.w600,
      color: effectiveTextColor,
      height: 4 / 3,
      letterSpacing: 0,
    );
    final detailStyle = TextStyle(
      fontSize: textSize * 11 / 12,
      color: secondaryTextColor,
      height: 14 / 11,
      letterSpacing: 0,
    );

    final card = Container(
      padding: EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: Padding(
              padding: EdgeInsets.only(
                top: countdownAnimation == null
                    ? 0
                    : countdownBarPadding + countdownBarThickness + 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: centerVertical
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  for (
                    var index = 0;
                    index < templateLines.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 2),
                    _buildTemplateLine(
                      templateLines[index],
                      boldStyle,
                      detailStyle,
                      brightness,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (countdownAnimation != null)
            Positioned(
              left: 0,
              right: 0,
              top: countdownBarPadding,
              child: Center(
                // 胶囊长度按卡片宽度比例绘制（默认 3/4）。
                child: FractionallySizedBox(
                  widthFactor: countdownBarLengthRatio.clamp(0.1, 1.0),
                  child: SizedBox(
                    height: countdownBarThickness,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: countdownAnimation!,
                        builder: (context, child) {
                          final remaining = (1 - countdownAnimation!.value)
                              .clamp(0.0, 1.0)
                              .toDouble();
                          // 进度色默认主题色，可自定义；底槽为同色淡化。
                          final effectiveColor =
                              countdownBarColor ?? context.theme.colors.primary;
                          return CustomPaint(
                            painter: _CountdownBarPainter(
                              progress: remaining,
                              rounded: countdownBarRounded,
                              backgroundColor: effectiveColor.withValues(
                                alpha: 0.22,
                              ),
                              progressColor: effectiveColor,
                            ),
                          );
                        },
                      ),
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
              density: dashedBorderDensity,
            ),
            child: card,
          )
        : card;
    return Container(margin: EdgeInsets.all(outerPadding), child: decorated);
  }

  Widget _buildTemplateLine(
    CourseTemplateLine line,
    TextStyle boldStyle,
    TextStyle detailStyle,
    Brightness brightness,
  ) {
    // 模板中的空行（\n\n）渲染为固定高度的空白，等价旧版「课程名称后加空行」。
    if (line.spans.every((span) => span.text.isEmpty)) {
      return SizedBox(width: double.infinity, height: textSize * 4 / 3);
    }
    final align = switch (line.align ??
        (centerHorizontal ? CourseTemplateAlign.center : null)) {
      CourseTemplateAlign.center => TextAlign.center,
      CourseTemplateAlign.right => TextAlign.right,
      _ => TextAlign.start,
    };
    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          children: [
            for (final span in line.spans)
              TextSpan(
                text: span.text,
                style: (span.bold ? boldStyle : detailStyle).copyWith(
                  fontSize: span.fontSize,
                  color: span.colorFor(brightness),
                ),
              ),
          ],
        ),
        textAlign: align,
      ),
    );
  }

  String _startTime(int session) {
    final start = kTimeSlots
        .firstWhere(
          (slot) => slot.index == session,
          orElse: () => kTimeSlots.first,
        )
        .start;
    return start.startsWith('0') ? start.substring(1) : start;
  }
}

class _CourseBorderPainter extends CustomPainter {
  final Color color;
  final double width;
  final double radius;
  final bool dashed;
  final double density;

  const _CourseBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
    required this.dashed,
    required this.density,
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
      final dashLength = (5.0 / density).clamp(1.0, 20.0).toDouble();
      final gapLength = (3.0 / density).clamp(1.0, 20.0).toDouble();
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
      oldDelegate.dashed != dashed ||
      oldDelegate.density != density;
}

class _CountdownBarPainter extends CustomPainter {
  final double progress;
  final bool rounded;
  final Color backgroundColor;
  final Color progressColor;

  const _CountdownBarPainter({
    required this.progress,
    required this.rounded,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final cap = rounded ? StrokeCap.round : StrokeCap.butt;
    // 圆弧端点会向两侧外扩半个线宽，绘制区间需向内收。
    final inset = rounded ? size.height / 2 : 0.0;
    final startX = inset;
    final endX = size.width - inset;
    if (endX <= startX) return;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = size.height
      ..strokeCap = cap
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
      ..strokeCap = cap
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
        oldDelegate.rounded != rounded ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
}
