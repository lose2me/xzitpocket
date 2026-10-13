import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:forui/forui.dart';

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
      data: data,
      selectable: selectable,
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
