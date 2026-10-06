import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../services/cas_service.dart';
import '../../services/repair_service.dart';
import '../../services/talker.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

class RepairDetailPage extends StatefulWidget {
  final RepairRecord record;
  final String studentId;
  final String password;

  const RepairDetailPage({
    super.key,
    required this.record,
    required this.studentId,
    required this.password,
  });

  @override
  State<RepairDetailPage> createState() => _RepairDetailPageState();
}

class _RepairDetailPageState extends State<RepairDetailPage> {
  final _service = RepairService();
  RepairDetail? _detail;
  String? _error;
  CasSession? _session;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isRefreshing) return;
    if (widget.record.formUuid.isEmpty) {
      setState(() => _error = '缺少报修单详情标识');
      return;
    }
    setState(() => _isRefreshing = true);
    CasSession? session;
    try {
      session = await _service.login(widget.studentId, widget.password);
      final detail = await _service.getRepairDetails(
        session,
        widget.record.formUuid,
      );
      if (!mounted) {
        session.close();
        return;
      }
      final previousSession = _session;
      setState(() {
        _session = session;
        _detail = detail;
        _error = null;
      });
      if (previousSession != null) previousSession.close();
    } on AuthException catch (e, stackTrace) {
      session?.close();
      talker.error('报修详情加载失败', e, stackTrace);
      if (mounted) setState(() => _error = e.message);
    } catch (e, stackTrace) {
      session?.close();
      talker.error('报修详情加载异常', e, stackTrace);
      if (mounted) setState(() => _error = '详情加载失败');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '报修进度',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isRefreshing ? null : _load,
          tooltip: '刷新处理进度',
          loading: _isRefreshing,
        ),
      ],
      child: _detail == null
          ? AppPageBody(
              safeArea: false,
              child: _error == null
                  ? const AppStateView(
                      icon: FLucideIcons.hourglass,
                      title: '正在加载详情',
                    )
                  : AppStateView(
                      icon: FLucideIcons.circleAlert,
                      title: _error!,
                      destructive: true,
                    ),
            )
          : _buildContent(_detail!),
    );
  }

  Widget _buildContent(RepairDetail detail) {
    final name = detail.content.trim();
    if (detail.steps.isEmpty) {
      return AppPageBody(
        maxWidth: AppLayout.resultMaxWidth,
        safeArea: false,
        pageGutter: true,
        child: Column(
          children: [
            if (name.isNotEmpty) _buildName(name, topPadding: AppSpacing.lg),
            const Expanded(
              child: AppStateView(
                icon: FLucideIcons.listChecks,
                title: '暂无流程记录',
              ),
            ),
          ],
        ),
      );
    }
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      children: [
        if (name.isNotEmpty) _buildName(name),
        for (var i = 0; i < detail.steps.length; i++)
          _ProcessStepTile(
            step: detail.steps[i],
            isLast: i == detail.steps.length - 1,
          ),
      ],
    );
  }

  Widget _buildName(String name, {double topPadding = 0}) => Padding(
    padding: EdgeInsets.only(top: topPadding, bottom: AppSpacing.xxl),
    child: Text(
      name,
      textAlign: TextAlign.center,
      style: context.theme.typography.body.lg,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final background = switch (status) {
      '已完工' || '已关闭' || '已评价' => const Color(0xFF4CAF50),
      '已接单' || '已转单' || '处理中' || '维修中' => const Color(0xFFFBC02D),
      '已上报' ||
      '已上传照片' ||
      '已上传图片' ||
      '待接单' ||
      '已提交' ||
      '提交报修' ||
      '报修' => const Color(0xFF9E9E9E),
      _ => const Color(0xFFF44336),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: background),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          status,
          style: theme.typography.body.xs.copyWith(
            fontSize: 11,
            height: 1.1,
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProcessStepTile extends StatelessWidget {
  final RepairProcessStep step;
  final bool isLast;

  const _ProcessStepTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = step.current
        ? theme.colors.primary
        : theme.colors.mutedForeground;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: step.current ? color : theme.colors.muted,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: step.current
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: theme.colors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _StatusBadge(status: step.name),
                      const SizedBox(width: 8),
                      if (step.time.isNotEmpty)
                        Expanded(
                          child: Text(
                            step.time,
                            textAlign: TextAlign.end,
                            style: theme.typography.body.xs.copyWith(
                              fontSize: 11,
                              height: 1.1,
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (step.operatorName.isNotEmpty || step.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        [
                          step.operatorName,
                          step.note,
                        ].where((value) => value.trim().isNotEmpty).join(' · '),
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  if (step.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final image in step.attachments)
                            if (image.url.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: _RepairImageThumbnail(url: image.url),
                              ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepairImageThumbnail extends StatelessWidget {
  final String url;

  const _RepairImageThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    return FTappable(
      onPress: () => _showRepairImage(context, url),
      child: Image.network(
        url,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: BoxDecoration(color: context.theme.colors.muted),
          child: const SizedBox(
            width: 96,
            height: 96,
            child: Icon(FLucideIcons.imageOff),
          ),
        ),
      ),
    );
  }
}

const _repairImageBarrierColor = Color(0xF2333333);

Future<void> _showRepairImage(BuildContext context, String url) =>
    showGeneralDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: '关闭图片预览',
      barrierColor: _repairImageBarrierColor,
      transitionDuration: AppMotion.fast,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _RepairImageOverlay(url: url),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

class _RepairImageOverlay extends StatefulWidget {
  final String url;

  const _RepairImageOverlay({required this.url});

  @override
  State<_RepairImageOverlay> createState() => _RepairImageOverlayState();
}

class _RepairImageOverlayState extends State<_RepairImageOverlay> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) throw StateError('图片为空');
      final bytes = Uint8List.fromList(data);
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'xzitpocket_${DateTime.now().millisecondsSinceEpoch}',
      );
      final saved = result is! Map || result['isSuccess'] != false;
      if (!mounted) return;
      showAppSnackBar(
        context,
        saved ? '已保存到相册' : '保存到相册失败',
        severity: saved ? ToastSeverity.success : ToastSeverity.error,
      );
    } catch (error, stackTrace) {
      talker.error('报修图片保存失败', error, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '保存到相册失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.page,
                  ),
                  child: Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const AppStateView(
                      icon: FLucideIcons.imageOff,
                      title: '图片加载失败',
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppIconButton(
                  icon: FLucideIcons.download,
                  tooltip: '保存到相册',
                  iconColor: const Color(0xFFFFFFFF),
                  onPress: _save,
                  loading: _saving,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
