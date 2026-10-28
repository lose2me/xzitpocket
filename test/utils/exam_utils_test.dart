import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/exam_utils.dart';

void main() {
  test('returns the end time when the range is present', () {
    expect(
      parseExamDate('2026-01-02 09:00-11:30'),
      DateTime(2026, 1, 2, 11, 30),
    );
    expect(
      parseExamDate('考试 2026-01-02 14:00 — 16:05 实验楼'),
      DateTime(2026, 1, 2, 16, 5),
    );
  });

  test('falls back to the end of the exam day without a range', () {
    expect(
      parseExamDate('2026-06-30 待定'),
      DateTime(2026, 6, 30, 23, 59, 59),
    );
    expect(parseExamDate('2026-06-30'), DateTime(2026, 6, 30, 23, 59, 59));
  });

  test('returns null when there is no date', () {
    expect(parseExamDate('尚未安排'), isNull);
    expect(parseExamDate(''), isNull);
    expect(parseExamDate('2026-6-30'), isNull);
  });
}
