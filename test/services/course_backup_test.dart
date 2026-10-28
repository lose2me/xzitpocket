import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/services/course_backup.dart';

void main() {
  Course course({String title = '高等数学', List<int>? sessions, List<int>? weeks}) {
    return Course(
      title: title,
      teacher: '张老师',
      weekday: 1,
      sessions: sessions ?? [1, 2],
      weeks: weeks ?? [1, 2, 3],
      campus: '中心校区',
      place: 'A101',
      colorIndex: 3,
      courseId: 'C1',
    );
  }

  test('courseBackup keeps the format version and course fields', () {
    final backup = courseBackup(courses: [course()]);
    expect(backup['type'], 'xzitpocket_courses');
    expect(backup['version'], 1);
    final courses = backup['courses'] as List;
    expect(courses, hasLength(1));
    expect(courses.single, containsPair('title', '高等数学'));
    expect(courses.single, containsPair('sessions', [1, 2]));
    expect(courses.single, containsPair('courseId', 'C1'));
  });

  test('an empty timetable produces an empty course list', () {
    final backup = courseBackup(courses: []);
    expect(backup['courses'], isEmpty);
  });

  test('formatBackupJson keeps scalar lists on one line', () {
    final text = formatBackupJson({
      'type': 'xzitpocket_courses',
      'sessions': [1, 2],
      'weeks': [],
      'mixed': [1, 'a', null, true],
    });
    expect(text, contains('"sessions": [1, 2]'));
    expect(text, contains('"weeks": []'));
    expect(text, contains('"mixed": [1, "a", null, true]'));
    expect(text, startsWith('{\n'));
    expect(text, endsWith('\n}'));
  });

  test('formatBackupJson expands nested objects and object lists', () {
    final text = formatBackupJson({
      'courses': [
        {'title': '课程', 'weeks': [1, 2], 'nested': {'a': 1}, 'empty': <String, Object>{}},
      ],
      'empty': <String, Object>{},
    });
    final decoded = jsonDecode(text);
    expect(decoded, isA<Map<String, dynamic>>());
    expect(decoded['courses'], hasLength(1));
    expect(decoded['courses'][0]['nested'], {'a': 1});
    expect(text, contains('"courses": [\n'));
    expect(text, contains('"nested": {\n'));
    expect(text, contains('"empty": {}'));
  });

  test('formatBackupJson encodes scalars and nulls', () {
    expect(formatBackupJson(1), '1');
    expect(formatBackupJson('x'), '"x"');
    expect(formatBackupJson(null), 'null');
    expect(formatBackupJson(<Object>[]), '[]');
  });
}
