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

/// Shows the basic and advanced AI analyses generated for one course paper.
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
  static const _modes = ['basic', 'advanced'];

  final Map<String, ResourceAIResult?> _results = {};
  final Map<String, String> _errors = {};
  final Set<String> _opening = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errors.clear();
    });
    await Future.wait(
      _modes.map((mode) async {
        try {
          final result = await ControlService.instance.fetchResourceAI(
            widget.resourceId,
            mode: mode,
          );
          if (mounted) setState(() => _results[mode] = result);
        } catch (error, stackTrace) {
          talker.warning('加载 $mode AI 解析失败', error, stackTrace);
          if (mounted) setState(() => _errors[mode] = describeAIError(error));
        }
      }),
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openPdf(String mode, String url) async {
    if (url.isEmpty || _opening.contains(mode)) return;
    setState(() => _opening.add(mode));
    try {
      final record = await ResourceDownloadService.instance.download(
        '${widget.resourceId}-ai-$mode',
        url,
        fileName:
            '${_safeName(widget.resourceName)}-AI解析-${_modeLabel(mode)}.pdf',
        format: 'pdf',
      );
      if (record == null) throw StateError('save returned no uri');
      await ResourceDownloadService.instance.open(record, format: 'pdf');
    } catch (error, stackTrace) {
      talker.warning('打开 $mode AI 解析 PDF 失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '打开失败，请稍后重试', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _opening.remove(mode));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AI 解析',
      child: _loading
          ? _buildSkeleton()
          : AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      AppSpacing.lg,
                      0,
                      AppSpacing.md,
                    ),
                    child: Text(
                      widget.resourceName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.tileTitle,
                    ),
                  ),
                  Expanded(
                    child: FTabs(
                      expands: true,
                      contentPhysics: const NeverScrollableScrollPhysics(),
                      children: [
                        FTabEntry(
                          label: const Text('基础解析'),
                          child: _buildMode('basic'),
                        ),
                        FTabEntry(
                          label: const Text('高级解析'),
                          child: _buildMode('advanced'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMode(String mode) {
    final error = _errors[mode];
    if (error != null) {
      return _buildState(
        icon: FLucideIcons.circleAlert,
        title: '加载失败',
        description: error,
        destructive: true,
      );
    }
    final result = _results[mode];
    if (result == null) {
      return _buildState(
        icon: FLucideIcons.sparkles,
        title: '暂无 AI 解析',
        description: '管理员尚未为这份试卷生成解析',
      );
    }
    if (!result.available) {
      final processing = result.processing;
      final failed = result.status == 'failed';
      return _buildState(
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
            ? (result.error.isEmpty ? '可稍后重试' : result.error)
            : '管理员尚未为这份试卷生成解析',
        destructive: failed,
      );
    }
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      bottomPadding: AppSpacing.xxl,
      safeArea: false,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
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
                      '${_modeLabel(mode)}解析',
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
            onPress: _opening.contains(mode)
                ? null
                : () => unawaited(_openPdf(mode, result.pdfUrl)),
            prefix: _opening.contains(mode)
                ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
                : const Icon(FLucideIcons.download),
            child: Text('打开${_modeLabel(mode)}解析 PDF'),
          ),
        ],
      ],
    );
  }

  Widget _buildState({
    required IconData icon,
    required String title,
    String? description,
    bool destructive = false,
  }) => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    bottomPadding: AppSpacing.xxl,
    safeArea: false,
    children: [
      const SizedBox(height: AppSpacing.xxl),
      AppStateView(
        icon: icon,
        title: title,
        description: description,
        destructive: destructive,
      ),
    ],
  );

  Widget _buildSkeleton() => AppPageListView(
    maxWidth: AppLayout.resultMaxWidth,
    bottomPadding: AppSpacing.xxl,
    children: [
      AppSkeleton(
        label: '正在加载 AI 解析',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: AppSkeletonBox(width: 180, height: 18)),
            const SizedBox(height: AppSpacing.lg),
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

  String _modeLabel(String mode) => mode == 'advanced' ? '高级' : '基础';

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
}

String describeAIError(Object error) {
  final message = error.toString();
  if (message.contains('404')) return '这份试卷还没有 AI 解析';
  if (message.contains('401') || message.contains('403')) {
    return '登录状态已失效，请重新登录';
  }
  return '网络异常，请稍后重试';
}
