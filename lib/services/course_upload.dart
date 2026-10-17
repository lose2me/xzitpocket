import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/book_list.dart';
import '../models/course.dart';
import 'control_service.dart';
import 'preferences_storage.dart';

/// Bumped when the upload payload/identity changes, so a previously stored
/// dedup hash is invalidated and the content is pushed once more.
const _signatureVersion = 'v2';

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
      <String, ({String code, String name, List<({String name, String tags})> books})>{};
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
  final signature = [
    _signatureVersion,
    for (final item in items)
      '${item.code}\u001e${item.name}\u001e'
          '${[for (final book in item.books) '${book.name}\u001f${book.tags}'].join('\u001e')}',
  ]..sort();
  final hash = sha256.convert(utf8.encode(signature.join('\u001e'))).toString();
  if (hash == storage.getUploadedCoursesHash()) return;
  final uploaded = await ControlService.instance.uploadCourses(items: items);
  if (uploaded) {
    await storage.setUploadedCoursesHash(hash);
  }
}
