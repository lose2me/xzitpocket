import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/course_upload.dart';

void main() {
  // 2025-08-31 is a Sunday; the semester's week 1 starts on the Monday before.
  final fall2025 = DateTime(2025, 8, 31);
  final spring2026 = DateTime(2026, 3, 1);
  final fall2026 = DateTime(2026, 8, 31);

  test('term code follows the academic year and term', () {
    expect(currentTermCode(semesterStart: fall2025), '2025-2026-1');
    expect(currentTermCode(semesterStart: spring2026), '2025-2026-2');
    expect(currentTermCode(semesterStart: fall2026), '2026-2027-1');
  });

  test('grade label derives from the enrollment year', () {
    expect(gradeLabelFor('25070100246', semesterStart: fall2025), '大一上');
    expect(gradeLabelFor('25070100246', semesterStart: spring2026), '大一下');
    expect(gradeLabelFor('25070100246', semesterStart: fall2026), '大二上');
    expect(gradeLabelFor('23010300238', semesterStart: fall2026), '大四上');
  });

  test('grade label handles unusable student ids', () {
    expect(gradeLabelFor(null, semesterStart: fall2025), '');
    expect(gradeLabelFor('', semesterStart: fall2025), '');
    expect(gradeLabelFor('x', semesterStart: fall2025), '');
    expect(gradeLabelFor('99', semesterStart: fall2025), '');
  });
}
