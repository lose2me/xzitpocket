import 'dart:ui' show Brightness, Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/course_text_template.dart';

void main() {
  const values = {
    '课程': '高等数学',
    '教师': '张老师',
    '教室': '教101',
    '校区': '中心校区',
    '地点': '教101\n中心校区',
    '时间': '8:00',
  };

  String plain(CourseTemplateLine line) =>
      line.spans.map((span) => span.text).join();

  group('parseCourseTemplate', () {
    test('default template renders bold title and @location lines', () {
      final lines = parseCourseTemplate(
        kDefaultCourseTextTemplate,
        values,
      ).where((line) => !line.skip).toList();

      expect(lines, hasLength(2));
      expect(plain(lines[0]), '高等数学');
      expect(lines[0].spans.single.bold, isTrue);
      expect(plain(lines[1]), '@教101\n中心校区');
      expect(lines[1].spans.any((span) => span.bold), isFalse);
    });

    test('splits lines on the literal \\n escape from single-line input', () {
      final lines = parseCourseTemplate(r'{课程}\n{时间}\n{教师}', values);
      expect(lines.map(plain).toList(), ['高等数学', '8:00', '张老师']);
    });

    test('supports font size tags in px', () {
      final lines = parseCourseTemplate(r'[s14]{课程}[/]', values);
      expect(lines.single.spans.single.fontSize, 14);
    });

    test('supports light/dark color tags', () {
      final lines = parseCourseTemplate(r'[c#111827|#f9fafb]{课程}[/]', values);
      final span = lines.single.spans.single;
      expect(span.lightColor, const Color(0xFF111827));
      expect(span.darkColor, const Color(0xFFf9fafb));
      expect(span.colorFor(Brightness.light), const Color(0xFF111827));
      expect(span.colorFor(Brightness.dark), const Color(0xFFf9fafb));
    });

    test('single color tag applies to both brightnesses', () {
      final lines = parseCourseTemplate(r'[c#123456]{课程}[/]', values);
      final span = lines.single.spans.single;
      expect(span.lightColor, const Color(0xFF123456));
      expect(span.darkColor, const Color(0xFF123456));
    });

    test('supports alignment tags and records line alignment', () {
      final left = parseCourseTemplate(r'[左]{课程}[/]', values).single;
      final center = parseCourseTemplate(r'[中]{课程}[/]', values).single;
      final right = parseCourseTemplate(r'[右]{课程}[/]', values).single;
      expect(left.align, CourseTemplateAlign.left);
      expect(center.align, CourseTemplateAlign.center);
      expect(right.align, CourseTemplateAlign.right);
    });

    test('nested styles combine until [/] closes the latest', () {
      final lines = parseCourseTemplate(r'[b][s10]{课程}[/]{教师}[/]', values);
      final spans = lines.single.spans;
      expect(spans[0].text, '高等数学');
      expect(spans[0].bold, isTrue);
      expect(spans[0].fontSize, 10);
      expect(spans[1].text, '张老师');
      expect(spans[1].bold, isTrue);
      expect(spans[1].fontSize, isNull);
    });

    test('explicit close tags close the matching style', () {
      final lines = parseCourseTemplate(r'[b][s10]{课程}[/s10][/b]{教师}', values);
      final spans = lines.single.spans;
      expect(spans[0].text, '高等数学');
      expect(spans[0].bold, isTrue);
      expect(spans[0].fontSize, 10);
      expect(spans[1].text, '张老师');
      expect(spans[1].bold, isFalse);
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

    test('# and @ are ordinary characters', () {
      final lines = parseCourseTemplate(r'#1 @教 {教室}', values);
      expect(plain(lines.single), '#1 @教 教101');
      expect(lines.single.spans.every((span) => !span.bold), isTrue);
    });

    test('supports italic tags', () {
      final english = parseCourseTemplate(
        r'[i]{课程}[/i]',
        values,
      ).single.spans.single;
      final chinese = parseCourseTemplate(
        r'[斜]{教师}[/斜]',
        values,
      ).single.spans.single;
      expect(english.italic, isTrue);
      expect(chinese.italic, isTrue);
    });

    test('exposes classroom and campus separately', () {
      final lines = parseCourseTemplate(r'{教室}\n{校区}', values);
      expect(lines.map(plain).toList(), ['教101', '中心校区']);
    });

    test('unknown tags render as literal text', () {
      final lines = parseCourseTemplate(r'[x]{课程}[/]', values);
      expect(plain(lines.single), '[x]高等数学');
    });

    test('unknown variables render as literal text', () {
      final lines = parseCourseTemplate('{未知}', values);
      expect(plain(lines.single), '{未知}');
      expect(lines.single.hasVariable, isFalse);
    });

    test('lines whose variables are all empty are skipped', () {
      final lines = parseCourseTemplate(r'[b]{课程}[/]\n@{地点}', {
        ...values,
        '地点': '',
      });
      expect(lines, hasLength(2));
      expect(lines[0].skip, isFalse);
      expect(lines[1].skip, isTrue);
    });

    test('lines with at least one non-empty variable are kept', () {
      final lines = parseCourseTemplate(r'{课程} {地点}', {...values, '地点': ''});
      expect(lines.single.skip, isFalse);
    });

    test('blank template lines are preserved for spacing', () {
      final lines = parseCourseTemplate(r'{课程}\n\n{时间}', values);
      expect(lines, hasLength(3));
      expect(lines[1].spans, isEmpty);
      expect(lines[1].skip, isFalse);
    });

    test('unbalanced close tags never throw', () {
      expect(() => parseCourseTemplate(r'[/][b]{课程}', values), returnsNormally);
    });
  });

  group('buildCourseTemplateAiPrompt', () {
    test('contains the syntax table, current template and the instruction', () {
      final prompt = buildCourseTemplateAiPrompt(r'[b]{课程}[/]');
      expect(prompt, contains('{课程}'));
      expect(prompt, contains('[b]'));
      expect(prompt, contains('[i]'));
      expect(prompt, contains('{教室}'));
      expect(prompt, contains('{校区}'));
      expect(prompt, contains(r'[s12]'));
      expect(prompt, contains(r'[c#111827|#f9fafb]'));
      expect(prompt, contains('[左]'));
      expect(prompt, contains('[中]'));
      expect(prompt, contains('[右]'));
      expect(prompt, contains('[/b]'));
      expect(prompt, contains(r'[b]{课程}[/]'));
      expect(prompt, contains('请按此语法返回新模板'));
    });
  });

  group('composeLegacyTemplate', () {
    test('reproduces the default look with legacy defaults', () {
      expect(
        composeLegacyTemplate(
          showStartTime: false,
          hideLocation: false,
          hideTeacher: true,
          hideTeacherBrackets: true,
          removeLocationAt: false,
          addBlankLineAfterTitle: false,
        ),
        kDefaultCourseTextTemplate,
      );
    });

    test('maps every legacy switch to template fragments', () {
      final template = composeLegacyTemplate(
        showStartTime: true,
        hideLocation: false,
        hideTeacher: false,
        hideTeacherBrackets: false,
        removeLocationAt: true,
        addBlankLineAfterTitle: true,
      );
      expect(template, r'[b]{课程}[/b]\n\n{时间}\n{地点}\n【{教师}】');
    });
  });
}
