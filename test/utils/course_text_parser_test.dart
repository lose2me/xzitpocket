import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/course_text_parser.dart';

void main() {
  group('parseSessionRanges', () {
    test('parses session ranges and sorts them', () {
      expect(parseSessionRanges('1-2, 4,6-7节', minSession: 1, maxSession: 14), [
        1,
        2,
        4,
        6,
        7,
      ]);
    });

    test('returns null for invalid session token', () {
      expect(
        parseSessionRanges('1-2, 第三节', minSession: 1, maxSession: 14),
        isNull,
      );
    });

    test('handles Chinese comma separator', () {
      expect(parseSessionRanges('1，3，5', minSession: 1, maxSession: 14), [
        1,
        3,
        5,
      ]);
    });
  });

  group('parseWeekRanges', () {
    test('parses ranges with parity markers', () {
      expect(parseWeekRanges('1-8(单),10,12-14(双)'), [1, 3, 5, 7, 10, 12, 14]);
    });

    test('accepts weeks beyond 16', () {
      expect(parseWeekRanges('1-20'), List.generate(20, (i) => i + 1));
    });

    test('returns null for unknown parity marker', () {
      expect(parseWeekRanges('1-8(奇)'), isNull);
    });
  });

  group('formatWeekRanges', () {
    test('compresses consecutive weeks', () {
      expect(formatWeekRanges([1, 2, 3, 5, 7, 8]), '1-3,5,7-8');
    });
  });
}
