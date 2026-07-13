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
        parseWeekRanges('1-8(单),10,12-14(双)'),
        [1, 3, 5, 7, 10, 12, 14],
      );
    });

    test('returns null for invalid week token', () {
      expect(
        parseWeekRanges('1-16,abc', allowParity: false),
        isNull,
      );
    });

    test('returns null for empty input', () {
      expect(
        parseWeekRanges(''),
        isNull,
      );
    });

    test('accepts weeks beyond 16', () {
      expect(
        parseWeekRanges('1-20'),
        List.generate(20, (i) => i + 1),
      );
    });

    test('returns null when parity not allowed', () {
      expect(
        parseWeekRanges('1-8(单)', allowParity: false),
        isNull,
      );
    });

    test('handles full-width parentheses', () {
      expect(
        parseWeekRanges('1-8（单）'),
        [1, 3, 5, 7],
      );
    });

    test('handles even parity', () {
      expect(
        parseWeekRanges('1-8(双)'),
        [2, 4, 6, 8],
      );
    });

    test('returns null for unknown parity marker', () {
      expect(
        parseWeekRanges('1-8(奇)'),
        isNull,
      );
    });

    test('handles single week', () {
      expect(
        parseWeekRanges('5'),
        [5],
      );
    });

    test('strips 周 and 周次 prefixes', () {
      expect(
        parseWeekRanges('周次1-3周'),
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
