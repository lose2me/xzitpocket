import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/text_search.dart';

void main() {
  group('matchesSearch', () {
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
  });
}
