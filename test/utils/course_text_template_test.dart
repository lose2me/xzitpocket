import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/course_text_template.dart';

void main() {
  const values = {
    '课程': '高等数学',
    '教师': '张老师',
    '教室': '教101',
    '校区': '中心校区',
    '时间': '8:00',
  };

  String plain(CourseTemplateLine line) =>
      line.spans.map((span) => span.text).join();

  group('parseCourseTemplate', () {
    test('default template renders title, classroom and campus', () {
      final lines = parseCourseTemplate(
        kDefaultCourseTextTemplate,
        values,
      ).where((line) => !line.skip).toList();

      expect(lines, hasLength(3));
      expect(plain(lines[0]), '高等数学');
      expect(lines[0].spans.single.bold, isTrue);
      expect(plain(lines[1]), '@教101');
      expect(plain(lines[2]), '中心校区');
      expect(lines[1].spans.any((span) => span.bold), isFalse);
    });

    test('nested styles combine until their closing tags', () {
      final lines = parseCourseTemplate(r'[b][s10]{课程}[/s10]{教师}[/b]', values);
      final spans = lines.single.spans;
      expect(spans[0].text, '高等数学');
      expect(spans[0].bold, isTrue);
      expect(spans[0].fontSize, 10);
      expect(spans[1].text, '张老师');
      expect(spans[1].bold, isTrue);
      expect(spans[1].fontSize, isNull);
    });

    test('explicit close tags disambiguate nested styles', () {
      // [b][s12]x[/b]y —— 只关闭加粗，字号仍生效。
      final lines = parseCourseTemplate(r'[b][s12]{课程}[/b]{教师}[/s12]', values);
      final spans = lines.single.spans;
      expect(spans[0].bold, isTrue);
      expect(spans[0].fontSize, 12);
      expect(spans[1].text, '张老师');
      expect(spans[1].bold, isFalse);
      expect(spans[1].fontSize, 12);
    });

    test('lines whose variables are all empty are skipped', () {
      final lines = parseCourseTemplate(r'[b]{课程}[/b]\n@{教室}', {
        ...values,
        '教室': '',
      });
      expect(lines, hasLength(2));
      expect(lines[0].skip, isFalse);
      expect(lines[1].skip, isTrue);
    });
  });

  group('validateCourseTemplate', () {
    test('rejects unknown variables and unclosed tags', () {
      expect(validateCourseTemplate('{科目}'), contains('未知变量'));
      expect(validateCourseTemplate('{课程'), contains('右花括号'));
      expect(validateCourseTemplate('[b]{课程}'), contains('没有闭合'));
      expect(validateCourseTemplate('{课程}[/b]'), contains('没有对应的开标签'));
      expect(validateCourseTemplate('[/]'), contains('对应的闭合标签'));
    });

    test('rejects invalid sizes, colors and unknown tags', () {
      expect(validateCourseTemplate('[s0]x[/s0]'), contains('字号标签'));
      expect(validateCourseTemplate('[s80]x[/s80]'), contains('字号标签'));
      expect(validateCourseTemplate('[c#12]x[/c]'), contains('颜色标签'));
      expect(validateCourseTemplate('[bb]x[/bb]'), contains('无法识别的标签'));
    });
  });

  group('LegacyCourseTextOptions', () {
    test('builds the 2.1.0 line order with its switches', () {
      const options = LegacyCourseTextOptions(
        showStartTime: true,
        hideTeacher: false,
        hideTeacherBrackets: false,
        removeLocationAt: true,
      );
      const newline = r'\n';
      expect(
        options.toTemplate(),
        '[b][s12]{课程}[/s12][/b]$newline'
        '[s11]{时间}[/s11]$newline'
        '[s11]{教室}[/s11]$newline'
        '[s11]{校区}[/s11]$newline'
        '[s11]【{教师}】[/s11]',
      );
    });
  });
}
