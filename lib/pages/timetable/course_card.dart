import 'package:flutter/material.dart';

import '../../models/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = course.color;
    // Derive readable text color
    final textColor =
        bgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
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
                    color: textColor.withAlpha(200),
                    height: 1.2,
                  ),
                ),
              if (course.campus.isNotEmpty)
                Text(
                  course.campus,
                  style: TextStyle(
                    fontSize: 11,
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
