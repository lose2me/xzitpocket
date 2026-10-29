import '../models/book_list.dart';
import '../models/course.dart';
import '../utils/week_calculator.dart';
import 'control_service.dart';

/// Uploads the timetable courses together with the book list on each sync.
/// Textbooks are matched to courses by course
/// name and associated by course number. Failures are logged inside the
/// service and never affect the caller.
///
/// The upload also carries the current academic term, the grade label derived
/// from the student's enrollment year (e.g. 大一上) and the college. The control
/// console uses them to fit course numbers that describe the same course.
Future<void> uploadCoursesAndBooks({
  required List<Course> courses,
  required BookListResult? books,
  String? studentId,
  String? collegeName,
}) async {
  final booksByCourse = <String, List<({String name, String tags})>>{};
  for (final item in books?.items ?? const <BookListItem>[]) {
    (booksByCourse[item.courseName] ??= []).add((
      name: item.textbookName,
      tags: item.textbookTags.join('/'),
    ));
  }
  final byCode =
      <
        String,
        ({String code, String name, List<({String name, String tags})> books})
      >{};
  for (final course in courses) {
    final code = course.courseId.trim();
    if (code.isEmpty) continue;
    byCode.putIfAbsent(
      code,
      () => (
        code: code,
        name: course.title,
        books: booksByCourse[course.title] ?? const [],
      ),
    );
  }
  if (byCode.isEmpty) return;
  final items = byCode.values.toList();
  // Upload on every login/refresh. The server upserts, and a locally cached
  // hash would otherwise hide courses that were removed server-side.
  await ControlService.instance.uploadCourses(
    items: items,
    term: currentTermCode(),
    grade: gradeLabelFor(studentId),
    college: collegeName,
  );
}

/// The academic year and term of the configured semester, e.g. `2025-2026-1`.
String currentTermCode({DateTime? semesterStart}) {
  final (year, term) = getCurrentSchoolTerm(semesterStart: semesterStart);
  return '$year-${year + 1}-${term == 1 ? 1 : 2}';
}

/// Labels the semester as 大一上/大一下… from the student's enrollment year.
/// Student numbers start with the two-digit enrollment year (e.g. 25070100246
/// enrolled in 2025). Returns an empty string when the input is unusable.
String gradeLabelFor(String? studentId, {DateTime? semesterStart}) {
  final id = (studentId ?? '').trim();
  if (id.length < 2) return '';
  final enrollmentYear = int.tryParse(id.substring(0, 2));
  if (enrollmentYear == null) return '';
  final (year, term) = getCurrentSchoolTerm(semesterStart: semesterStart);
  final offset = (year - (2000 + enrollmentYear)) * 2 + (term == 1 ? 1 : 2);
  const labels = ['大一上', '大一下', '大二上', '大二下', '大三上', '大三下', '大四上', '大四下'];
  if (offset >= 1 && offset <= labels.length) return labels[offset - 1];
  if (offset > labels.length) return '第$offset学期';
  return '';
}
