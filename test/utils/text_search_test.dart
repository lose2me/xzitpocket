import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/text_search.dart';

void main() {
  group('matchesSearch', () {
    test('an empty query matches everything', () {
      expect(matchesSearch('', ['高等数学']), isTrue);
      expect(matchesSearch('   ', ['高等数学']), isTrue);
    });

    test('matches a direct substring', () {
      expect(matchesSearch('数学', ['高等数学']), isTrue);
      expect(matchesSearch('gd', ['AUTOMATION-101']), isFalse);
    });

    test('ignores case, spaces and punctuation', () {
      expect(matchesSearch('aut 101', ['AUTOMATION-101']), isTrue);
      expect(matchesSearch('高等 数学', ['高等数学']), isTrue);
    });

    test('matches full pinyin', () {
      expect(matchesSearch('gaodengshuxue', ['高等数学']), isTrue);
      expect(matchesSearch('gaodeng', ['高等数学']), isTrue);
    });

    test('matches pinyin initials', () {
      expect(matchesSearch('gdsx', ['高等数学']), isTrue);
      expect(matchesSearch('GDSX', ['高等数学']), isTrue);
    });

    test('resolves polyphonic characters from the phrase', () {
      expect(matchesSearch('chongqing', ['重庆邮电大学']), isTrue);
      expect(matchesSearch('cqyd', ['重庆邮电大学']), isTrue);
    });

    test('matches a split keyword in order', () {
      expect(matchesSearch('高数', ['高等数学']), isTrue);
      expect(matchesSearch('数高', ['高等数学']), isFalse);
    });

    test('matches any of the given fields', () {
      expect(matchesSearch('dxwl', ['大学物理', 'PHY-2024']), isTrue);
      expect(matchesSearch('phy2024', ['大学物理', 'PHY-2024']), isTrue);
      expect(matchesSearch('ydl', ['大学物理', 'PHY-2024']), isFalse);
    });

    test('ignores empty fields', () {
      expect(matchesSearch('gds', ['', '高等数学']), isTrue);
      expect(matchesSearch('gds', ['', '']), isFalse);
    });
  });
}
