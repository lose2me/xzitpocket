import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/repair_service.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'repair_form_page.dart';

class RepairPage extends StatefulWidget {
  final RepairResult initialResult;
  final String studentId;
  final String password;
  final PreferencesStorage preferencesStorage;

  const RepairPage({
    super.key,
    required this.initialResult,
    required this.studentId,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  late List<RepairRecord> _records;
  late RepairUserInfo _userInfo;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _records = widget.initialResult.records;
    _userInfo = widget.initialResult.userInfo;
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await ToolsDataManager.instance.refreshRepair(
        widget.studentId,
        widget.password,
        widget.preferencesStorage,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
        return;
      }
      setState(() {
        _records = result.records;
        _userInfo = result.userInfo;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('报修详情刷新失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('报修详情刷新异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openForm() async {
    final submitted = await Navigator.of(context).push<bool>(
      appRoute(
        name: AppRouteNames.newRepair,
        builder: (_) => RepairFormPage(
          studentId: widget.studentId,
          password: widget.password,
          userInfo: _userInfo,
        ),
      ),
    );
    if (submitted == true) {
      await _refresh();
    }
  }

  static const _knownStatuses = {
    '已完工',
    '已关闭',
    '已评价',
    '已接单',
    '已转单',
    '处理中',
    '维修中',
    '已上报',
    '已上传照片',
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final visible = _records
        .where((r) => _knownStatuses.contains(r.status))
        .toList();

    return AppPage(
      title: '我的报修',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isRefreshing ? null : _refresh,
          tooltip: '刷新报修',
          loading: _isRefreshing,
        ),
        FHeaderAction(
          icon: const Icon(FLucideIcons.plus),
          semanticsLabel: '新建报修',
          onPress: _openForm,
        ),
      ],
      child: visible.isEmpty
          ? const AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              child: AppStateView(icon: FLucideIcons.wrench, title: '暂无报修记录'),
            )
          : AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              children: [
                for (final record in visible) _buildRecordCard(theme, record),
              ],
            ),
    );
  }

  Widget _buildRecordCard(FThemeData theme, RepairRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(color: _statusColor(record.status)),
                  child: Text(
                    record.status,
                    style: theme.typography.body.xs.copyWith(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: _onColor(_statusColor(record.status)),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  record.createTime,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              record.content,
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.address.isNotEmpty
                  ? '${record.areaName}(${record.address})  ${record.itemName}'
                  : '${record.areaName}  ${record.itemName}',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 状态对应颜色：绿=完成，黄=处理中，灰=已提交/早期，红=其他。
  Color _statusColor(String status) {
    return switch (status) {
      '已完工' || '已关闭' || '已评价' => const Color(0xFF4CAF50), // 绿
      '已接单' || '已转单' || '处理中' || '维修中' => const Color(0xFFFBC02D), // 黄
      '已上报' || '已上传照片' => const Color(0xFF9E9E9E), // 灰
      _ => const Color(0xFFF44336), // 红
    };
  }

  /// Choose the foreground with the better WCAG contrast ratio. A fixed
  /// luminance cutoff makes medium green/red badges unreadable in one theme.
  Color _onColor(Color background) {
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    final luminance = background.computeLuminance();
    final blackContrast = (luminance + 0.05) / 0.05;
    final whiteContrast = 1.05 / (luminance + 0.05);
    return blackContrast >= whiteContrast ? black : white;
  }
}
