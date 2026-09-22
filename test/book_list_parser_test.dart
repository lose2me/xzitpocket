import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/auth_service.dart';

void main() {
  test('parses the book list JSON envelope', () {
    final result = parseBookListPayload({
      'items': [
        {'kcmc': '高等数学', 'jcxx': '大学数学（第七版）/高等教育出版社/第7版', 'jcytbj': '已订'},
      ],
    });

    expect(result.items.single.courseName, '高等数学');
    expect(result.items.single.textbookName, '大学数学（第七版）');
    expect(result.items.single.textbookTags, ['高等教育出版社', '第7版']);
  });

  test('parses an HTML table fallback', () {
    final result = parseBookListPayload('''
      <table><thead><tr><th>课程</th><th>教材</th></tr></thead>
      <tbody><tr><td>大学英语</td><td>英语综合教程</td></tr></tbody></table>
    ''');

    expect(result.items.single.courseName, '大学英语');
    expect(result.items.single.textbookName, '英语综合教程');
    expect(result.items.single.textbookTags, isEmpty);
  });

  test('omits a course when textbook information is empty', () {
    final result = parseBookListPayload({
      'items': [
        {'kcmc': '大学体育', 'jcxx': '', 'xksj': '2026-09-01'},
      ],
    });

    expect(result.items, isEmpty);
  });

  test('treats br tags and line breaks as additional textbooks', () {
    final result = parseBookListPayload({
      'items': [
        {'kcmc': '大学英语', 'jcxx': '英语综合教程/外研社<br>英语视听说/外研社/第二版\n英语阅读/高教社'},
      ],
    });

    expect(result.items.map((item) => item.textbookName), [
      '英语综合教程',
      '英语视听说',
      '英语阅读',
    ]);
    expect(result.items[1].courseName, '大学英语');
    expect(result.items[1].textbookTags, ['外研社', '第二版']);
  });

  test('infers the current semester after the latest graded semester', () {
    final catalog = buildBookListSemesterCatalog(
      const GradeResult(
        grades: [],
        years: ['2025-2026', '2024-2025'],
        termsByYear: {
          '2025-2026': ['1'],
          '2024-2025': ['1', '2'],
        },
      ),
      '25070100246',
    );

    expect(catalog.current?.key, '2025|12');
    expect(catalog.options.map((option) => option.key), [
      '2025|12',
      '2025|3',
      '2024|12',
      '2024|3',
    ]);
  });

  test('moves from second semester to the next academic year', () {
    final catalog = buildBookListSemesterCatalog(
      const GradeResult(
        grades: [],
        years: ['2025-2026'],
        termsByYear: {
          '2025-2026': ['1', '2'],
        },
      ),
      '25070100246',
    );

    expect(catalog.current?.key, '2026|3');
    expect(catalog.current?.label, '26学年第1学期');
  });

  test('uses the student number for a freshman without grades', () {
    final catalog = buildBookListSemesterCatalog(
      const GradeResult(grades: [], years: [], termsByYear: {}),
      '25070100246',
    );

    expect(catalog.options.map((option) => option.key), ['2025|3']);
    expect(catalog.current?.label, '25学年第1学期');
  });
}
