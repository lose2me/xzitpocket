import 'package:flutter/material.dart';

import '../../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;
  final double courseOpacity;
  final double courseBorderOpacity;
  final Color borderColor;
  final double borderWidth;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.courseOpacity = 1.0,
    this.courseBorderOpacity = 1.0,
    this.borderColor = Colors.grey,
    this.borderWidth = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = course.color.withAlpha((255 * courseOpacity).round());
    const textColor = Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: courseBorderOpacity > 0
              ? Border.all(
                  color: borderColor
                      .withAlpha((255 * courseBorderOpacity).round()),
                  width: borderWidth,
                )
              : null,
        ),
        clipBehavior: Clip.hardEdge,
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
                  fontSize: 13,
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
                    fontSize: 12,
                    color: textColor.withAlpha(200),
                    height: 1.2,
                  ),
                ),
              if (course.campus.isNotEmpty)
                Text(
                  course.campus,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(200),
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
