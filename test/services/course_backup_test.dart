import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/services/course_backup.dart';

void main() {
  Course course({
    String title = '高等数学',
    List<int>? sessions,
    List<int>? weeks,
  }) {
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
}
