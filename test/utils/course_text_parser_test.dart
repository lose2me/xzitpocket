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
  });

  test('formatWeekRanges compresses consecutive weeks', () {
    expect(formatWeekRanges([1, 2, 3, 5, 7, 8]), '1-3,5,7-8');
  });
}
