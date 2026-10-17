import '../models/book_list.dart';
import '../models/course.dart';
import 'control_service.dart';
import 'preferences_storage.dart';

/// Uploads the timetable courses together with the book list, deduped by a
/// content hash stored in [storage]. Textbooks are matched to courses by course
/// name and associated by course number. Failures are logged inside the
/// service and never affect the caller.
Future<void> uploadCoursesAndBooks({
  required PreferencesStorage storage,
  required List<Course> courses,
  required BookListResult? books,
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
  await ControlService.instance.uploadCourses(items: items);
}
