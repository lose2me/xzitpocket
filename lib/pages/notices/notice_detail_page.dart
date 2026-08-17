import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:forui/forui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/notice_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

class NoticeDetailPage extends StatefulWidget {
  final NoticeItem item;

  const NoticeDetailPage({super.key, required this.item});

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  final _service = NoticeService();
  NoticeDetail? _detail;
  bool _loading = true;
  int? _downloadingIndex;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final detail = await _service.fetchDetail(widget.item.url);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on Exception catch (e, stackTrace) {
      talker.error('公告详情加载失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, '详情加载失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.item.url));
    if (mounted) showAppSnackBar(context, '链接已复制');
  }

  /// 后台下载附件到应用目录，完成后唤起系统应用打开。
  Future<void> _openAttachment(NoticeAttachment attachment, int index) async {
    if (_downloadingIndex != null) return;
    setState(() => _downloadingIndex = index);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final attDir = Directory('${dir.path}/attachments');
      await attDir.create(recursive: true);

      var fileName = attachment.name.trim();
      if (fileName.isEmpty) {
        fileName = attachment.url.split('/').last;
      }
      // 清理文件名中的非法字符
      fileName = fileName.replaceAll(RegExp(r'[/\\:*?"<>|\n\r]'), '_');

      final file = File('${attDir.path}/$fileName');
      if (!await file.exists()) {
        await _service.downloadAttachment(attachment.url, file.path);
      }

      if (!mounted) return;
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        showAppSnackBar(context, '打开附件失败');
      }
    } on Exception catch (e, stackTrace) {
      talker.error('附件下载失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, '附件下载失败');
    } finally {
      if (mounted) setState(() => _downloadingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final detail = _detail;

    return AppPage(
      title: '公告详情',
      actions: [
        AppIconButton(
          icon: FLucideIcons.copy,
          onPress: _copyUrl,
          tooltip: '复制链接',
        ),
      ],
      child: _loading
          ? const AppPageBody(
              child: Center(
                child: FCircularProgress(
                  size: FCircularProgressSizeVariant.md,
                ),
              ),
            )
          : AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              children: [
                if (detail != null) ...[
                  Text(
                    detail.title,
                    style: theme.typography.pageTitle,
                  ),
                  if (detail.date.isNotEmpty || detail.documentNo != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (detail.date.isNotEmpty)
                          Text(
                            detail.date,
                            style: theme.typography.body.sm.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        const Spacer(),
                        if (detail.documentNo case final docNo?)
                          Text(
                            docNo,
                            style: theme.typography.body.sm.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: theme.colors.border,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (detail.content.isEmpty)
                    const AppStateView(
                      icon: FLucideIcons.fileQuestion,
                      title: '暂无正文内容',
                    )
                  else
                    MarkdownBody(
                      data: detail.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.typography.body.md.copyWith(
                          color: theme.colors.foreground,
                          height: 1.7,
                        ),
                        h1: theme.typography.pageTitle.copyWith(
                          color: theme.colors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        h2: theme.typography.tileTitle.copyWith(
                          color: theme.colors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                        h3: theme.typography.sectionTitle.copyWith(
                          color: theme.colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colors.foreground,
                        ),
                        listBullet: theme.typography.body.md.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                        tableBorder: TableBorder.all(
                          color: theme.colors.border,
                        ),
                        tableHead: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colors.foreground,
                        ),
                        tableBody: theme.typography.body.sm.copyWith(
                          color: theme.colors.foreground,
                          height: 1.5,
                        ),
                        tableColumnWidth: const FlexColumnWidth(),
                        blockSpacing: 10,
                      ),
                    ),
                  if (detail.attachments.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: theme.colors.border,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '附件',
                      style: theme.typography.tileTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final (index, attachment)
                        in detail.attachments.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          onPress: _downloadingIndex == null
                              ? () => _openAttachment(attachment, index)
                              : null,
                          child: Row(
                            children: [
                              Icon(
                                FLucideIcons.paperclip,
                                size: 18,
                                color: theme.colors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  attachment.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.body.md,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (_downloadingIndex == index)
                                const FCircularProgress(
                                  size: FCircularProgressSizeVariant.xs,
                                )
                              else
                                Icon(
                                  FLucideIcons.download,
                                  size: 18,
                                  color: theme.colors.mutedForeground,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ] else
                  const AppStateView(
                    icon: FLucideIcons.fileQuestion,
                    title: '无法加载公告内容',
                  ),
              ],
            ),
    );
  }
}
