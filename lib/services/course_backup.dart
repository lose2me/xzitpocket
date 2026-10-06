import 'dart:convert';

import '../models/course.dart';

/// A snapshot of the effective timetable, including all applied changes.
Map<String, dynamic> courseBackup({required List<Course> courses}) => {
  'type': 'xzitpocket_courses',
  'version': 1,
  'courses': courses.map((course) => course.toJson()).toList(),
};

/// Formats JSON with one object property per line while keeping scalar lists
/// such as `sessions` and `weeks` compact on their property line.
String formatBackupJson(Object? value) {
  String format(Object? value, String indent) {
    final nextIndent = '$indent  ';
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final entries = value.entries.map(
        (entry) =>
            '$nextIndent${jsonEncode(entry.key)}: '
            '${format(entry.value, nextIndent)}',
      );
      return '{\n${entries.join(',\n')}\n$indent}';
    }
    if (value is List) {
      if (value.every((item) => item is! Map && item is! List)) {
        return '[${value.map(jsonEncode).join(', ')}]';
      }
      final entries = value.map(
        (item) => '$nextIndent${format(item, nextIndent)}',
      );
      return '[\n${entries.join(',\n')}\n$indent]';
    }
    return jsonEncode(value);
  }

  return format(value, '');
}

List<Course> parseCourseBackup(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map ||
      decoded['type'] != 'xzitpocket_courses' ||
      decoded['version'] != 1) {
    throw const FormatException('请选择当前课表 JSON 文件');
  }
  final raw = decoded['courses'];
  if (raw is! List) throw const FormatException('找不到 courses 数组');
  return [
    for (final value in raw)
      if (value is Map)
        Course.fromJson(Map<String, dynamic>.from(value))
      else
        throw const FormatException('课程数据格式无效'),
  ];
}
