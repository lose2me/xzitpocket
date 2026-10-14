import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_tokens.dart';

/// 统一的 GitHub Release 风格 Markdown 渲染组件。
///
/// 更新页（发布更新日志）、绑定运营商教程、新建报修教程共用本组件，
/// 保证三处渲染样式一致（需求 20）。
class AppMarkdown extends StatelessWidget {
  final String data;
  final bool selectable;

  const AppMarkdown({super.key, required this.data, this.selectable = true});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final foreground = theme.colors.foreground;
    final muted = theme.colors.mutedForeground;
    return MarkdownBody(
      data: withLatinBreaks(data),
      selectable: selectable,
      onTapLink: (text, href, title) {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri != null && uri.hasScheme) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: theme.typography.bodyText.copyWith(color: foreground),
        h1: theme.typography.pageTitle.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        // GitHub Release 风格：二级标题带下划分隔线。
        h2: theme.typography.tileTitle.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        h2Padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xs,
        ),
        h3: theme.typography.sectionTitle.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        h4: theme.typography.bodyText.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        a: theme.typography.bodyText.copyWith(color: theme.colors.primary),
        listBullet: theme.typography.bodyText.copyWith(color: foreground),
        blockquote: theme.typography.bodySmall.copyWith(color: muted),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colors.border, width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: AppSpacing.md),
        code: theme.typography.body.sm.copyWith(
          color: foreground,
          fontFamily: 'monospace',
          backgroundColor: theme.colors.muted,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colors.muted,
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(AppSpacing.md),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colors.border)),
        ),
        tableBody: theme.typography.bodySmall.copyWith(color: foreground),
        tableHead: theme.typography.bodySmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        tableBorder: TableBorder.all(color: theme.colors.border),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      // GitHub 风格：无序列表按嵌套层级用 实心圆 / 空心圆 / 方块。
      bulletBuilder: (parameters) => _buildBullet(
        parameters,
        theme.typography.bodyText.copyWith(color: foreground),
      ),
    );
  }

  static bool _isLatinLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

  /// Inserts zero-width spaces between adjacent Latin letters so long English
  /// runs can wrap at any character (like CJK) instead of leaving a large
  /// trailing gap whenever a whole word does not fit the line. Link
  /// destinations, autolinks, and code spans/blocks are copied verbatim so
  /// they stay valid.
  @visibleForTesting
  static String withLatinBreaks(String source) {
    final out = StringBuffer();
    var i = 0;
    while (i < source.length) {
      if (source.startsWith('```', i)) {
        final end = source.indexOf('```', i + 3);
        final stop = end == -1 ? source.length : end + 3;
        out.write(source.substring(i, stop));
        i = stop;
        continue;
      }
      final ch = source.codeUnitAt(i);
      if (ch == 0x60) {
        // Inline code span: `...`.
        final end = source.indexOf('`', i + 1);
        final stop = end == -1 ? source.length : end + 1;
        out.write(source.substring(i, stop));
        i = stop;
        continue;
      }
      if (ch == 0x5D &&
          i + 1 < source.length &&
          source.codeUnitAt(i + 1) == 0x28) {
        // Link destination: ](...) with balanced parentheses.
        out.write('](');
        i += 2;
        var depth = 1;
        while (i < source.length && depth > 0) {
          final c = source.codeUnitAt(i);
          if (c == 0x28) {
            depth++;
          } else if (c == 0x29) {
            depth--;
          }
          out.writeCharCode(c);
          i++;
        }
        continue;
      }
      if (ch == 0x3C &&
          (source.startsWith('http', i + 1) ||
              source.startsWith('mailto:', i + 1))) {
        // Autolink: <https://...>.
        final end = source.indexOf('>', i + 1);
        if (end != -1) {
          out.write(source.substring(i, end + 1));
          i = end + 1;
          continue;
        }
      }
      out.writeCharCode(ch);
      if (i + 1 < source.length &&
          _isLatinLetter(ch) &&
          _isLatinLetter(source.codeUnitAt(i + 1))) {
        out.write('\u200B');
      }
      i++;
    }
    return out.toString();
  }

  Widget _buildBullet(MarkdownBulletParameters parameters, TextStyle style) {
    if (parameters.style == BulletStyle.orderedList) {
      return Text(
        '${parameters.index + 1}.',
        textAlign: TextAlign.right,
        style: style,
      );
    }
    final marker = switch (parameters.nestLevel) {
      0 => '•',
      1 => '◦',
      _ => '▪',
    };
    return Text(marker, textAlign: TextAlign.center, style: style);
  }
}
