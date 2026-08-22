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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FBadge(
                  variant: _statusBadgeVariant(record.status),
                  child: Text(record.status),
                ),
                const Spacer(),
                Text(
                  record.createTime,
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record.content,
              style: theme.typography.body.md.copyWith(
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
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  FBadgeVariant _statusBadgeVariant(String status) => switch (status) {
    '已完工' || '已关闭' || '已评价' => FBadgeVariant.primary,
    '已接单' || '已转单' || '处理中' || '维修中' => FBadgeVariant.destructive,
    '已上报' || '已上传照片' => FBadgeVariant.secondary,
    _ => FBadgeVariant.outline,
  };
}
