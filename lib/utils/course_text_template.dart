/// 课程块文字模板语法（单行输入，渲染允许多行）：
///
/// | 用途 | 写法 | 说明 |
/// |---|---|---|
/// | 变量 | `{课程}` `{教师}` `{教室}` `{校区}` `{时间}` | 花括号 |
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

/// 默认模板：等价 2.1.0 默认展示（课程名加粗 12px + @教室/校区 11px 明细行）。
const kDefaultCourseTextTemplate =
    r'[b][s12]{课程}[/s12][/b]\n[s11]@{教室}[/s11]\n[s11]{校区}[/s11]';

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

const _knownVariables = {'课程', '教师', '校区', '教室', '时间'};

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

/// 校验用户输入的模板。返回 null 表示格式正确，否则返回给用户看的错误。
///
/// 只校验花括号变量与方括号标签；普通文字不限制。未知标签按错误处理，
/// 避免 `[bb]`、`[s0]` 这类拼写问题静默渲染成普通文本。
String? validateCourseTemplate(String template) {
  final text = template.replaceAll('\\n', '\n');
  final stack = <({String tag, _TemplateStyleKind kind})>[];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char == '{') {
      final end = text.indexOf('}', index + 1);
      if (end < 0) return '变量缺少右花括号 }';
      final name = text.substring(index + 1, end);
      if (!_knownVariables.contains(name)) return '未知变量 {$name}';
      index = end + 1;
      continue;
    }
    if (char == '[') {
      final end = text.indexOf(']', index + 1);
      if (end < 0) return '标签缺少右方括号 ]';
      final tag = text.substring(index + 1, end);
      if (tag == '/') return '请使用与开标签对应的闭合标签';
      final closing = _parseClosingTag(tag);
      if (closing != null) {
        final at = stack.lastIndexWhere((entry) => entry.kind == closing);
        if (at < 0) return '闭合标签 [$tag] 没有对应的开标签';
        stack.removeAt(at);
        index = end + 1;
        continue;
      }
      final style = _parseStyleTag(tag);
      if (style != null) {
        stack.add((tag: tag, kind: style.kind!));
        index = end + 1;
        continue;
      }
      if (tag.startsWith('s')) {
        return '字号标签 [$tag] 无效，应为 [s12]…[/s12]（1–72）';
      }
      if (tag.startsWith('c')) {
        return '颜色标签 [$tag] 无效，应为 [c#111827|#f9fafb]…[/c]';
      }
      return '无法识别的标签 [$tag]';
    }
    index++;
  }
  if (stack.isNotEmpty) {
    return '标签 [${stack.last.tag}] 没有闭合';
  }
  return null;
}

/// 「复制 AI 提示词」输出：语法表 + 当前模板 + 指令。
String buildCourseTemplateAiPrompt(String currentTemplate) {
  const syntax = '''
课程块文字模板语法（单行输入，渲染允许多行，\\n 表示换行，闭合标签与开标签同名）：
- 变量：{课程} {教师} {教室} {校区} {时间}
- 加粗：[b]文字[/b]
- 斜体：[i]文字[/i]（也可写 [斜]文字[/斜]）
- 字号：[s12]文字[/s12]（数字为 px）
- 颜色：[c#111827|#f9fafb]文字[/c]（| 前亮色、后暗色）
- 靠左：[左]文字[/左]
- 居中：[中]文字[/中]
- 靠右：[右]文字[/右]
- # 和 @ 均为普通字符，可直接书写''';
  return '$syntax\n\n当前模板：\n$currentTemplate\n\n'
      '请询问我要更改什么方面的样式，协助我进行修改，返回时只输出模板。';
}
