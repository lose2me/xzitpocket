import 'dart:convert';

import '../models/course.dart';

/// A snapshot of the effective timetable, including all applied changes.
Map<String, dynamic> courseBackup({required List<Course> courses}) => {
  'type': 'xzitpocket_courses',
  'version': 1,
  'courses': courses.map((course) => course.toJson()).toList(),
};

List<Course> parseCourseBackup(String source) {
  final decoded = jsonDecode(source);
  final dynamic raw;
  if (decoded is List) {
    raw = decoded;
  } else if (decoded is Map &&
      decoded['type'] == 'xzitpocket_courses' &&
      decoded['version'] == 1) {
    raw = decoded['courses'];
  } else {
    throw const FormatException('请选择当前课表 JSON 文件');
  }
  if (raw is! List) throw const FormatException('找不到 courses 数组');
  return [
    for (final value in raw)
      if (value is Map)
        Course.fromJson(Map<String, dynamic>.from(value))
      else
        throw const FormatException('课程数据格式无效'),
  ];
}
