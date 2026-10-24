import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/resource_center.dart';

void main() {
  test('course JSON keeps the control version for cache invalidation', () {
    final course = ResourceCourse.fromJson({
      'code': 'C1',
      'name': '高等数学',
      'question_bank_count': 1,
      'resource_count': 2,
      'textbook_count': 3,
      'cover_url': 'https://dl.xuda.live/books/1/cover.webp?sign=x&t=1',
      'cover_version': '1700000000003',
      'version': 'r2.1700000000000:t3.1700000000001:c1700000000002',
    });

    expect(course.questionBankCount, 1);
    expect(course.resourceCount, 2);
    expect(course.textbookCount, 3);
    expect(course.version, startsWith('r2.'));
    expect(course.coverVersion, '1700000000003');

    final roundtrip = ResourceCourse.fromJson(course.toJson());
    expect(roundtrip.code, course.code);
    expect(roundtrip.name, course.name);
    expect(roundtrip.coverUrl, course.coverUrl);
    expect(roundtrip.coverVersion, course.coverVersion);
    expect(roundtrip.version, course.version);
  });

  test('course rows keep the server update time', () {
    final resource = CourseResourceItem.fromJson({
      'id': 'res-1',
      'name': '期末试卷.pdf',
      'has_pdf': true,
      'format': 'docx',
      'size_bytes': 1024,
      'updated_at': '2026-10-06T00:00:00.001Z',
    });
    final textbook = CourseTextbookItem.fromJson({
      'id': 'tbx-1',
      'name': '高等数学（上）',
      'has_pdf': true,
      'has_cover': true,
      'updated_at': '2026-10-06T00:00:00.002Z',
    });

    expect(resource.format, 'docx');
    expect(resource.updatedAt, '2026-10-06T00:00:00.001Z');
    expect(
      CourseResourceItem.fromJson(resource.toJson()).updatedAt,
      resource.updatedAt,
    );
    expect(textbook.hasCover, isTrue);
    expect(textbook.updatedAt, '2026-10-06T00:00:00.002Z');
    expect(
      CourseTextbookItem.fromJson(textbook.toJson()).updatedAt,
      textbook.updatedAt,
    );
  });
}
