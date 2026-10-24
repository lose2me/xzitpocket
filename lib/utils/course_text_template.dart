/// 课程块文字模板语法（单行输入，渲染允许多行）：
///
/// | 用途 | 写法 | 说明 |
/// |---|---|---|
/// | 变量 | `{课程}` `{教师}` `{教室}` `{校区}` `{地点}` `{时间}` | 花括号；`{地点}` = 教室 + 换行 + 校区 |
/// | 加粗 | `[b]文字[/b]` | |
/// | 斜体 | `[i]文字[/i]` | |
/// | 字号 | `[s12]文字[/s12]` | 数字为 px |
/// | 颜色 | `[c#111827\|#f9fafb]文字[/c]` | `\|` 前亮色、后暗色 |
/// | 靠左 | `[左]文字[/左]` | |
/// | 居中 | `[中]文字[/中]` | |
/// | 靠右 | `[右]文字[/右]` | |
///
/// `\n`（反斜杠 + n）表示换行。`#`、`@` 均为普通字符。
/// 无法识别的标记按普通文本渲染，保证模板永不崩溃。
library;

import 'dart:ui' show Brightness, Color;

/// 默认模板：等价旧版默认展示（课程名加粗一行 + @地点 明细行）。
const kDefaultCourseTextTemplate = r'[b]{课程}[/b]\n@{地点}';

enum CourseTemplateAlign { left, center, right }

/// 模板渲染的最小单元。未设置的属性由渲染方按“明细行”默认样式补齐。
class CourseTemplateSpan {
  final String text;
  final bool bold;
  final bool italic;
  final double? fontSize;
  final Color? lightColor;
  final Color? darkColor;

  const CourseTemplateSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.fontSize,
    this.lightColor,
    this.darkColor,
  });

  Color? colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;
}

/// 一行模板内容。[hasVariable] 用于空值整行省略：
/// 含变量的行在所有变量都为空时不渲染（保持旧版“无地点不显示地点行”的观感）。
class CourseTemplateLine {
  final List<CourseTemplateSpan> spans;
  final CourseTemplateAlign? align;
  final bool hasVariable;
  final bool allVariablesEmpty;

  const CourseTemplateLine({
    required this.spans,
    this.align,
    this.hasVariable = false,
    this.allVariablesEmpty = false,
  });

  bool get skip => hasVariable && allVariablesEmpty;
}

/// 变量取值表。键为花括号内的名称。
typedef CourseTemplateValues = Map<String, String>;

/// 把模板解析为可渲染的行。[values] 提供变量实际内容。
List<CourseTemplateLine> parseCourseTemplate(
  String template,
  CourseTemplateValues values,
) {
  final rawLines = template
      .replaceAll('\\r\\n', '\\n')
      .replaceAll('\\n', '\n')
      .split('\n');
  return [for (final raw in rawLines) _parseLine(raw, values)];
}

CourseTemplateLine _parseLine(String raw, CourseTemplateValues values) {
  final spans = <CourseTemplateSpan>[];
  // 样式栈：保存每个未闭合的样式标签；[/tag] 关闭最近的同类标签。
  final stack = <_TemplateStyle>[];
  var hasVariable = false;
  var nonEmptyVariable = false;
  CourseTemplateAlign? lineAlign;

  var index = 0;
  final buffer = StringBuffer();

  _TemplateStyle currentStyle() {
    var style = const _TemplateStyle();
    for (final tag in stack) {
      style = style.merge(tag);
    }
    return style;
  }

  void flush() {
    if (buffer.isEmpty) return;
    final style = currentStyle();
    spans.add(
      CourseTemplateSpan(
        text: buffer.toString(),
        bold: style.bold,
        italic: style.italic,
        fontSize: style.fontSize,
        lightColor: style.lightColor,
        darkColor: style.darkColor,
      ),
    );
    buffer.clear();
  }

  void closeStyle(_TemplateStyleKind kind) {
    for (var i = stack.length - 1; i >= 0; i--) {
      if (stack[i].kind == kind) {
        stack.removeAt(i);
        return;
      }
    }
  }

  while (index < raw.length) {
    final char = raw[index];
    if (char == '{') {
      final end = raw.indexOf('}', index + 1);
      if (end > index) {
        final name = raw.substring(index + 1, end);
        if (_knownVariables.contains(name)) {
          flush();
          hasVariable = true;
          final value = values[name] ?? '';
          if (value.trim().isNotEmpty) nonEmptyVariable = true;
          final style = currentStyle();
          spans.add(
            CourseTemplateSpan(
              text: value,
              bold: style.bold,
              italic: style.italic,
              fontSize: style.fontSize,
              lightColor: style.lightColor,
              darkColor: style.darkColor,
            ),
          );
          index = end + 1;
          continue;
        }
      }
    } else if (char == '[') {
      final end = raw.indexOf(']', index + 1);
      if (end > index) {
        final tag = raw.substring(index + 1, end);
        if (tag == '/') {
          // 兼容旧的通用闭合标记：关闭最近一层。
          flush();
          if (stack.isNotEmpty) stack.removeLast();
          index = end + 1;
          continue;
        }
        final closing = _parseClosingTag(tag);
        if (closing != null) {
          flush();
          closeStyle(closing);
          index = end + 1;
          continue;
        }
        final style = _parseStyleTag(tag);
        if (style != null) {
          flush();
          if (style.align != null) lineAlign ??= style.align;
          stack.add(style);
          index = end + 1;
          continue;
        }
      }
    }
    buffer.write(char);
    index++;
  }
  flush();

  return CourseTemplateLine(
    spans: spans,
    align: lineAlign,
    hasVariable: hasVariable,
    allVariablesEmpty: hasVariable && !nonEmptyVariable,
  );
}

const _knownVariables = {'课程', '教师', '地点', '校区', '教室', '时间'};

enum _TemplateStyleKind { bold, italic, size, color, align }

class _TemplateStyle {
  final bool bold;
  final bool italic;
  final double? fontSize;
  final Color? lightColor;
  final Color? darkColor;
  final CourseTemplateAlign? align;

  const _TemplateStyle({
    this.bold = false,
    this.italic = false,
    this.fontSize,
    this.lightColor,
    this.darkColor,
    this.align,
  });

  /// 该标签引入的样式类型（每个开标签只引入一种）。
  _TemplateStyleKind? get kind {
    if (bold) return _TemplateStyleKind.bold;
    if (italic) return _TemplateStyleKind.italic;
    if (fontSize != null) return _TemplateStyleKind.size;
    if (lightColor != null) return _TemplateStyleKind.color;
    if (align != null) return _TemplateStyleKind.align;
    return null;
  }

  _TemplateStyle merge(_TemplateStyle child) => _TemplateStyle(
    bold: child.bold || bold,
    italic: child.italic || italic,
    fontSize: child.fontSize ?? fontSize,
    lightColor: child.lightColor ?? lightColor,
    darkColor: child.darkColor ?? darkColor,
    align: child.align ?? align,
  );
}

/// 解析闭合标签（`/b`、`/s12`、`/s`、`/c`、`/左`…），返回要关闭的样式类型。
_TemplateStyleKind? _parseClosingTag(String tag) {
  if (tag == '/b') return _TemplateStyleKind.bold;
  if (tag == '/i' || tag == '/斜') return _TemplateStyleKind.italic;
  if (tag == '/c') return _TemplateStyleKind.color;
  if (tag == '/左' || tag == '/中' || tag == '/右') {
    return _TemplateStyleKind.align;
  }
  if (tag == '/s' || RegExp(r'^/s\d+(?:\.\d+)?$').hasMatch(tag)) {
    return _TemplateStyleKind.size;
  }
  return null;
}

_TemplateStyle? _parseStyleTag(String tag) {
  if (tag == 'b') return const _TemplateStyle(bold: true);
  if (tag == 'i' || tag == '斜') return const _TemplateStyle(italic: true);
  if (tag == '左') return const _TemplateStyle(align: CourseTemplateAlign.left);
  if (tag == '中') {
    return const _TemplateStyle(align: CourseTemplateAlign.center);
  }
  if (tag == '右') return const _TemplateStyle(align: CourseTemplateAlign.right);
  final sizeMatch = RegExp(r'^s(\d+(?:\.\d+)?)$').firstMatch(tag);
  if (sizeMatch != null) {
    final size = double.tryParse(sizeMatch.group(1)!);
    if (size != null && size > 0 && size <= 72) {
      return _TemplateStyle(fontSize: size);
    }
    return null;
  }
  final colorMatch = RegExp(r'^c(#[0-9a-fA-F]{6,8})(?:\|(#[0-9a-fA-F]{6,8}))?$')
      .firstMatch(tag);
  if (colorMatch != null) {
    final light = _parseHexColor(colorMatch.group(1)!);
    final dark = colorMatch.group(2) == null
        ? light
        : _parseHexColor(colorMatch.group(2)!);
    if (light != null) {
      return _TemplateStyle(lightColor: light, darkColor: dark);
    }
  }
  return null;
}

Color? _parseHexColor(String value) {
  var hex = value.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// 「复制 AI 提示词」输出：语法表 + 当前模板 + 指令。
String buildCourseTemplateAiPrompt(String currentTemplate) {
  const syntax = '''
课程块文字模板语法（单行输入，渲染允许多行，\\n 表示换行，闭合标签与开标签同名）：
- 变量：{课程} {教师} {教室} {校区} {地点} {时间}
- 加粗：[b]文字[/b]
- 斜体：[i]文字[/i]（也可写 [斜]文字[/斜]）
- 字号：[s12]文字[/s12]（数字为 px）
- 颜色：[c#111827|#f9fafb]文字[/c]（| 前亮色、后暗色）
- 靠左：[左]文字[/左]
- 居中：[中]文字[/中]
- 靠右：[右]文字[/右]
- {地点} = 教室 + 换行 + 校区；只想显示其中一项时用 {教室} 或 {校区}
- # 和 @ 均为普通字符，可直接书写''';
  return '$syntax\n\n当前模板：\n$currentTemplate\n\n请按此语法返回新模板。';
}

/// 由旧版布尔开关推导等价模板（用于旧数据的一次性迁移与派生显示）。
String composeLegacyTemplate({
  required bool showStartTime,
  required bool hideLocation,
  required bool hideTeacher,
  required bool hideTeacherBrackets,
  required bool removeLocationAt,
  required bool addBlankLineAfterTitle,
}) {
  final lines = <String>['[b]{课程}[/b]'];
  if (addBlankLineAfterTitle) lines.add('');
  if (showStartTime) lines.add('{时间}');
  if (!hideLocation) lines.add('${removeLocationAt ? '' : '@'}{地点}');
  if (!hideTeacher) {
    lines.add(hideTeacherBrackets ? '{教师}' : '【{教师}】');
  }
  return lines.join('\\n');
}
