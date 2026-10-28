import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/resource_center.dart';
import 'package:xzitpocket/services/resource_center_cache.dart';

void main() {
  test('course list snapshot roundtrips its version and rows', () {
    final snapshot = ResourceCenterSnapshot(
      version: 'c1.1700000000000:r1.1700000000001:t0.0:q0.0:tc1:qc0',
      courses: const [
        ResourceCourse(
          code: 'C1',
          name: '高等数学',
          questionBankCount: 1,
          resourceCount: 1,
          textbookCount: 1,
          coverUrl: 'https://dl.xuda.live/books/1/cover.webp?sign=x',
          version: 'r1.1700000000001:t0.0:c0',
        ),
      ],
    );

    final decoded = ResourceCenterSnapshot.decode(snapshot.encode())!;
    expect(decoded.version, snapshot.version);
    expect(decoded.courses.single.code, 'C1');
    expect(decoded.courses.single.version, 'r1.1700000000001:t0.0:c0');
  });

  test('course detail snapshot roundtrips rows and version', () {
    final snapshot = ResourceCourseSnapshot(
      version: 'r1.1700000000001:t1.1700000000002:c1700000000000',
      resources: const [
        CourseResourceItem(
          id: 'res-1',
          name: '期末试卷.pdf',
          hasPdf: true,
          sizeBytes: 1024,
          fileVersion: 'paper-content-version',
          updatedAt: '2026-10-06T00:00:00.001Z',
        ),
      ],
      textbooks: const [
        CourseTextbookItem(
          id: 'tbx-1',
          name: '高等数学（上）',
          hasPdf: true,
          hasCover: true,
          fileVersion: 'book-content-version',
          updatedAt: '2026-10-06T00:00:00.002Z',
        ),
      ],
    );

    final decoded = ResourceCourseSnapshot.decode(snapshot.encode())!;
    expect(decoded.version, snapshot.version);
    expect(decoded.resources.single.updatedAt, '2026-10-06T00:00:00.001Z');
    expect(decoded.resources.single.fileVersion, 'paper-content-version');
    expect(decoded.textbooks.single.hasCover, isTrue);
    expect(decoded.textbooks.single.fileVersion, 'book-content-version');
    expect(decoded.textbooks.single.updatedAt, '2026-10-06T00:00:00.002Z');
  });

  test('invalid snapshots decode as null', () {
    expect(ResourceCenterSnapshot.decode(null), isNull);
    expect(ResourceCenterSnapshot.decode('not json'), isNull);
    expect(ResourceCourseSnapshot.decode(jsonEncode([])), isNull);
  });
}
