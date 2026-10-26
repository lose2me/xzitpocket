import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../models/resource_center.dart';
import '../../services/control_service.dart';
import '../../services/resource_download_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../ui/app_markdown.dart';
import '../../utils/snackbar_helper.dart';

/// Shows the AI analysis generated for one course paper.
class ResourceAIPage extends StatefulWidget {
  final String resourceId;
  final String resourceName;

  const ResourceAIPage({
    super.key,
    required this.resourceId,
    required this.resourceName,
  });

  @override
  State<ResourceAIPage> createState() => _ResourceAIPageState();
}

class _ResourceAIPageState extends State<ResourceAIPage> {
  ResourceAIResult? _result;
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ControlService.instance.fetchResourceAI(
        widget.resourceId,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error, stackTrace) {
      talker.warning('加载 AI 解析失败', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _error = describeAIError(error);
        _loading = false;
      });
    }
  }

  Future<void> _openPdf() async {
    final url = _result?.pdfUrl ?? '';
    if (url.isEmpty || _opening) return;
    setState(() => _opening = true);
    try {
      final record = await ResourceDownloadService.instance.download(
        '${widget.resourceId}-ai',
        url,
        fileName: '${_safeName(widget.resourceName)}-AI解析.pdf',
        format: 'pdf',
      );
      if (record == null) throw StateError('save returned no uri');
      await ResourceDownloadService.instance.open(record, format: 'pdf');
    } catch (error, stackTrace) {
      talker.warning('打开 AI 解析 PDF 失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '打开失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AppPage(
      title: 'AI 解析',
      child: _loading
          ? _buildSkeleton()
          : _error != null
          ? _buildError(_error!)
          : result == null || !result.available
          ? _buildUnavailable(result)
          : _buildContent(result),
    );
  }

  Widget _buildSkeleton() => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    bottomPadding: AppSpacing.xxl,
    children: [
      AppSkeleton(
        label: '正在加载 AI 解析',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: const [
                  AppSkeletonBox(width: 22, height: 22, circle: true),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: AppSkeletonBox(height: 16)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var index = 0; index < 6; index++) ...[
              AppSkeletonBox(
                width: index.isEven ? double.infinity : 220,
                height: 14,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _buildError(String message) => AppPageBody(
    maxWidth: AppLayout.resultMaxWidth,
    onRefresh: _load,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppStateView(
          icon: FLucideIcons.circleAlert,
          title: '加载失败',
          description: message,
          destructive: true,
        ),
        FButton(
          variant: FButtonVariant.outline,
          onPress: _load,
          prefix: const Icon(FLucideIcons.refreshCw),
          child: const Text('重试'),
        ),
      ],
    ),
  );

  Widget _buildUnavailable(ResourceAIResult? result) {
    final processing = result?.processing ?? false;
    final failed = result?.status == 'failed';
    return AppPageBody(
      maxWidth: AppLayout.resultMaxWidth,
      onRefresh: _load,
      child: AppStateView(
        icon: processing
            ? FLucideIcons.clock3
            : failed
            ? FLucideIcons.circleAlert
            : FLucideIcons.sparkles,
        title: processing
            ? 'AI 正在解析'
            : failed
            ? 'AI 解析失败'
            : '暂无 AI 解析',
        description: processing
            ? '完成后会显示在这里，请稍后再来'
            : failed
            ? (result?.error.isNotEmpty == true ? result!.error : '可稍后重试')
            : '管理员尚未为这份试卷生成解析',
        destructive: failed,
      ),
    );
  }

  Widget _buildContent(ResourceAIResult result) => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    bottomPadding: AppSpacing.xxl,
    children: [
      AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FLucideIcons.sparkles,
              color: context.theme.colors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.resourceName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.tileTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    _meta(result),
                    style: context.theme.typography.bodySmall.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (result.markdown.trim().isNotEmpty)
        AppMarkdown(data: result.markdown)
      else
        Text(
          '解析内容为空',
          style: context.theme.typography.bodySmall.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
      if (result.pdfUrl.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        FButton(
          onPress: _opening ? null : _openPdf,
          prefix: _opening
              ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
              : const Icon(FLucideIcons.download),
          child: const Text('打开 AI 解析 PDF'),
        ),
      ],
    ],
  );

  String _meta(ResourceAIResult result) {
    final parts = <String>[
      if (_dateLabel(result.updatedAt) case final date?) '解析于 $date',
      if (result.totalPages > 0) '共 ${result.totalPages} 页',
    ];
    return parts.isEmpty ? 'AI 解析' : parts.join(' · ');
  }

  String? _dateLabel(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return null;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _safeName(String name) => name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .trim();
}

String describeAIError(Object error) {
  final message = error.toString();
  if (message.contains('404')) return '这份试卷还没有 AI 解析';
  if (message.contains('401') || message.contains('403')) {
    return '登录状态已失效，请重新登录';
  }
  return '网络异常，请稍后重试';
}
