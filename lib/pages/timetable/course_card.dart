import 'package:flutter/material.dart';

import '../../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final bool muted;
  final double courseOpacity;
  final double courseBorderOpacity;
  final Color borderColor;
  final double borderWidth;

  const CourseCard({
    super.key,
    required this.course,
    this.muted = false,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
    this.borderColor = Colors.grey,
    this.borderWidth = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = course.color.withAlpha((255 * courseOpacity).round());
    final borderRadius = BorderRadius.circular(6);
    final textColor = muted ? Colors.black45 : Colors.black87;
    final secondaryTextColor = muted
        ? Colors.black38
        : textColor.withAlpha(200);
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
      child: ClipRRect(
        borderRadius: borderRadius,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
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
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              if (course.place.isNotEmpty)
                Text(
                  '@${course.place}',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor,
                    height: 1.2,
                  ),
                ),
              if (course.campus.isNotEmpty)
                Text(
                  course.campus,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
