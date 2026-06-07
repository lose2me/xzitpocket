import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/course_text_parser.dart';

void main() {
  group('parseSessionRanges', () {
    test('parses session ranges and sorts them', () {
      expect(
        parseSessionRanges('1-2, 4,6-7节', minSession: 1, maxSession: 14),
        [1, 2, 4, 6, 7],
      );
    });

    test('returns null for invalid session token', () {
      expect(
        parseSessionRanges('1-2, 第三节', minSession: 1, maxSession: 14),
        isNull,
      );
    });

    test('returns null for empty input', () {
      expect(
        parseSessionRanges('', minSession: 1, maxSession: 14),
        isNull,
      );
    });

    test('returns null for whitespace-only input', () {
      expect(
        parseSessionRanges('   ', minSession: 1, maxSession: 14),
        isNull,
      );
    });

    test('parses single session', () {
      expect(
        parseSessionRanges('3', minSession: 1, maxSession: 14),
        [3],
      );
    });

    test('returns null when session exceeds max', () {
      expect(
        parseSessionRanges('1-15', minSession: 1, maxSession: 14),
        isNull,
      );
    });

    test('returns null when session below min', () {
      expect(
        parseSessionRanges('0-3', minSession: 1, maxSession: 14),
        isNull,
      );
    });

    test('handles reversed range (swaps start/end)', () {
      expect(
        parseSessionRanges('5-3', minSession: 1, maxSession: 14),
        [3, 4, 5],
      );
    });

    test('handles Chinese comma separator', () {
      expect(
        parseSessionRanges('1，3，5', minSession: 1, maxSession: 14),
        [1, 3, 5],
      );
    });

    test('deduplicates overlapping ranges', () {
      expect(
        parseSessionRanges('1-3, 2-4', minSession: 1, maxSession: 14),
        [1, 2, 3, 4],
      );
    });
  });

  group('parseWeekRanges', () {
    test('parses ranges with parity markers', () {
      expect(
        parseWeekRanges('1-8(单),10,12-14(双)', maxWeek: 16),
        [1, 3, 5, 7, 10, 12, 14],
      );
    });

    test('supports empty input as all weeks when enabled', () {
      expect(
        parseWeekRanges('', maxWeek: 4, emptyMeansAll: true, allowParity: false),
        [1, 2, 3, 4],
      );
    });

    test('returns null for invalid week token', () {
      expect(
        parseWeekRanges('1-16,abc', maxWeek: 16, allowParity: false),
        isNull,
      );
    });

    test('returns null for empty input when emptyMeansAll is false', () {
      expect(
        parseWeekRanges('', maxWeek: 16),
        isNull,
      );
    });

    test('returns null when exceeding maxWeek', () {
      expect(
        parseWeekRanges('1-20', maxWeek: 16),
        isNull,
      );
    });

    test('returns null when parity not allowed', () {
      expect(
        parseWeekRanges('1-8(单)', maxWeek: 16, allowParity: false),
        isNull,
      );
    });

    test('handles full-width parentheses', () {
      expect(
        parseWeekRanges('1-8（单）', maxWeek: 16),
        [1, 3, 5, 7],
      );
    });

    test('handles even parity', () {
      expect(
        parseWeekRanges('1-8(双)', maxWeek: 16),
        [2, 4, 6, 8],
      );
    });

    test('returns null for unknown parity marker', () {
      expect(
        parseWeekRanges('1-8(奇)', maxWeek: 16),
        isNull,
      );
    });

    test('handles single week', () {
      expect(
        parseWeekRanges('5', maxWeek: 16),
        [5],
      );
    });

    test('strips 周 and 周次 prefixes', () {
      expect(
        parseWeekRanges('周次1-3周', maxWeek: 16),
        [1, 2, 3],
      );
    });
  });

  group('formatWeekRanges', () {
    test('compresses consecutive weeks', () {
      expect(formatWeekRanges([1, 2, 3, 5, 7, 8]), '1-3,5,7-8');
    });

    test('returns empty string for empty list', () {
      expect(formatWeekRanges([]), '');
    });

    test('handles single week', () {
      expect(formatWeekRanges([5]), '5');
    });

    test('handles non-consecutive weeks', () {
      expect(formatWeekRanges([1, 3, 5, 7]), '1,3,5,7');
    });

    test('handles all consecutive weeks', () {
      expect(formatWeekRanges([1, 2, 3, 4, 5]), '1-5');
    });

    test('handles unsorted input', () {
      expect(formatWeekRanges([5, 3, 1, 2, 4]), '1-5');
    });
  });
}
