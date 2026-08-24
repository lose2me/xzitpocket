import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../services/hqgl_service.dart';
import '../../services/notice_service.dart';
import '../../services/talker.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

/// 后勤处公告详情：正文是「内嵌 PDF」，把它每一页渲染成图片，和页面一起滚动；
/// 其余文件超链接作为附件，样式与「通知公告」一致，可下载并用系统打开。
class HqglDetailPage extends StatefulWidget {
  final NoticeItem item;
  final Future<HqglDetailResult> Function(String url) fetchDetail;
  final Future<void> Function(String url, String path) downloadAttachment;

  HqglDetailPage({
    super.key,
    required this.item,
    Future<HqglDetailResult> Function(String url)? fetchDetail,
    Future<void> Function(String url, String path)? downloadAttachment,
  }) : fetchDetail = fetchDetail ?? HqglService().fetchDetail,
       downloadAttachment =
           downloadAttachment ?? HqglService().downloadAttachment;

  @override
  State<HqglDetailPage> createState() => _HqglDetailPageState();
}

class _HqglDetailPageState extends State<HqglDetailPage> {
  HqglDetailResult? _detail;
  bool _loading = true;
  bool _preparingBodyPdfs = false;
  final List<Uint8List> _bodyPageImages = [];
  final Set<String> _failedBodyPdfUrls = {};
  String? _openingUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _preparingBodyPdfs = false;
      _bodyPageImages.clear();
      _failedBodyPdfUrls.clear();
    });
    try {
      final detail = await widget.fetchDetail(widget.item.url);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _preparingBodyPdfs = detail.bodyPdfs.isNotEmpty;
      });
      await _prepareBodyPdfs(detail);
    } catch (e, stackTrace) {
      talker.error('后勤公告详情加载失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '加载失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _prepareBodyPdfs(HqglDetailResult detail) async {
    if (detail.bodyPdfs.isEmpty) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final attDir = Directory('${dir.path}/hqgl');
      await attDir.create(recursive: true);

      for (final pdf in detail.bodyPdfs) {
        try {
          final path = await _downloadTo(attDir, pdf, requirePdf: true);
          final pages = await _renderPdfPages(path);
          if (pages.isEmpty) {
            throw const FormatException('PDF 没有可渲染页面');
          }
          if (mounted) setState(() => _bodyPageImages.addAll(pages));
        } catch (e, stackTrace) {
          talker.error('后勤公告正文 PDF 处理失败\n${pdf.url}', e, stackTrace);
          if (mounted) setState(() => _failedBodyPdfUrls.add(pdf.url));
        }
      }
    } catch (e, stackTrace) {
      talker.error('后勤公告正文 PDF 初始化失败', e, stackTrace);
      if (mounted) {
        setState(
          () =>
              _failedBodyPdfUrls.addAll(detail.bodyPdfs.map((pdf) => pdf.url)),
        );
      }
    } finally {
      if (mounted) setState(() => _preparingBodyPdfs = false);
    }
  }

  Future<String> _downloadTo(
    Directory dir,
    NoticeAttachment attachment, {
    bool requirePdf = false,
  }) async {
    var name = attachment.name.trim();
    if (name.isEmpty || !name.contains('.')) {
      name = Uri.parse(attachment.url).pathSegments.last;
    }
    name = name.replaceAll(RegExp(r'[/\\:*?"<>|\n\r]'), '_');
    final file = File('${dir.path}/$name');
    if (requirePdf && await file.exists() && !await _isPdf(file)) {
      await file.delete();
    }
    if (!await file.exists()) {
      await widget.downloadAttachment(attachment.url, file.path);
    }
    if (requirePdf && !await _isPdf(file)) {
      if (await file.exists()) await file.delete();
      throw const FormatException('下载结果不是 PDF 文件');
    }
    return file.path;
  }

  Future<bool> _isPdf(File file) async {
    if (!await file.exists() || await file.length() < 5) return false;
    final handle = await file.open();
    try {
      final header = await handle.read(5);
      return header.length == 5 &&
          header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46 &&
          header[4] == 0x2D;
    } finally {
      await handle.close();
    }
  }

  /// 渲染 PDF 每一页为 PNG 图片。
  Future<List<Uint8List>> _renderPdfPages(String path) async {
    final images = <Uint8List>[];
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(path);
      final document = doc;
      // pdfx exposes PDF page numbers as 1-based (the first page is 1).
      for (
        var pageNumber = 1;
        pageNumber <= document.pagesCount;
        pageNumber++
      ) {
        final page = await document.getPage(pageNumber);
        try {
          final image = await page.render(
            width: page.width,
            height: page.height,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (image != null) images.add(image.bytes);
        } finally {
          await page.close();
        }
      }
    } finally {
      await doc?.close();
    }
    return images;
  }

  Future<void> _openAttachment(NoticeAttachment attachment) async {
    if (_openingUrl != null) return;
    setState(() => _openingUrl = attachment.url);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final attDir = Directory('${dir.path}/hqgl');
      await attDir.create(recursive: true);
      final path = await _downloadTo(attDir, attachment);
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        showAppSnackBar(context, '打开附件失败', severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('打开后勤附件失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '打开附件失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _openingUrl = null);
    }
  }

  Widget _buildFileSection(
    FThemeData theme, {
    required String title,
    required List<NoticeAttachment> files,
    required IconData icon,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: double.infinity, height: 1, color: theme.colors.border),
      const SizedBox(height: AppSpacing.lg),
      Text(
        title,
        style: theme.typography.tileTitle.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final file in files)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            onPress: _openingUrl == null ? () => _openAttachment(file) : null,
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.body.md,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (_openingUrl == file.url)
                  const FCircularProgress(size: FCircularProgressSizeVariant.xs)
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
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final detail = _detail;

    return AppPage(
      title: '后勤公告',
      child: _loading
          ? const AppPageBody(
              child: Center(
                child: FCircularProgress(size: FCircularProgressSizeVariant.md),
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
                    style: theme.typography.pageTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail.date.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      detail.date,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (detail.content.isEmpty &&
                      detail.bodyPdfs.isEmpty &&
                      detail.attachments.isEmpty)
                    const AppStateView(
                      icon: FLucideIcons.fileQuestion,
                      title: '该公告暂无可见内容',
                    )
                  else ...[
                    if (detail.content.isNotEmpty) ...[
                      Text(
                        detail.content,
                        style: theme.typography.body.md.copyWith(height: 1.7),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (_bodyPageImages.isNotEmpty) ...[
                      for (final bytes in _bodyPageImages) ...[
                        Image.memory(
                          bytes,
                          fit: BoxFit.fitWidth,
                          width: double.infinity,
                          gaplessPlayback: true,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                    if (_preparingBodyPdfs)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(
                          child: FCircularProgress(
                            size: FCircularProgressSizeVariant.md,
                          ),
                        ),
                      ),
                    if (_failedBodyPdfUrls.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildFileSection(
                        theme,
                        title: '正文文件',
                        files: detail.bodyPdfs
                            .where(
                              (pdf) => _failedBodyPdfUrls.contains(pdf.url),
                            )
                            .toList(),
                        icon: FLucideIcons.fileText,
                      ),
                    ],
                    if (detail.attachments.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildFileSection(
                        theme,
                        title: '附件',
                        files: detail.attachments,
                        icon: FLucideIcons.paperclip,
                      ),
                    ],
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
