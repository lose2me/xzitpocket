import 'dart:async';

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
import 'repair_detail_page.dart';

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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _records = widget.initialResult.records;
    _userInfo = widget.initialResult.userInfo;
    _loading = _records.isEmpty;
    unawaited(_load(markLoading: false));
  }

  Future<bool> _load({
    bool forceRefresh = false,
    bool showError = true,
    bool markLoading = true,
  }) async {
    if (markLoading && _records.isEmpty && !_loading) {
      setState(() => _loading = true);
    }
    try {
      final manager = ToolsDataManager.instance;
      RepairResult? result;
      if (forceRefresh) {
        result = await manager.refreshRepair(
          widget.studentId,
          widget.password,
          widget.preferencesStorage,
        );
      } else {
        await manager.loadRepair(
          widget.studentId,
          widget.password,
          widget.preferencesStorage,
        );
        result = manager.repair;
      }
      if (!mounted) return false;
      if (result == null) {
        if (showError) {
          showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
        }
        return false;
      }
      final refreshed = result;
      final changed =
          !identical(refreshed.records, _records) ||
          !identical(refreshed.userInfo, _userInfo);
      setState(() {
        if (changed) {
          _records = refreshed.records;
          _userInfo = refreshed.userInfo;
        }
      });
      return true;
    } on AuthException catch (e, stackTrace) {
      talker.error('报修详情刷新失败', e, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
      return false;
    } catch (e, stackTrace) {
      talker.error('报修详情刷新异常', e, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
      return false;
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
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
    if (submitted != true || !mounted) return;
    final refreshed = await _load(forceRefresh: true, showError: false);
    if (!mounted) return;
    showAppSnackBar(
      context,
      refreshed ? '提交成功' : '提交成功，但列表刷新失败',
      severity: refreshed ? ToastSeverity.success : ToastSeverity.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final visible = _records;

    return AppPage(
      title: '极速报修',
      actions: [
        AppIconButton(
          icon: FLucideIcons.plus,
          tooltip: '新建报修',
          onPress: () => unawaited(_openForm()),
        ),
      ],
      child: _records.isEmpty && _loading
          ? _buildSkeleton()
          : visible.isEmpty
          ? AppPageBody(
              maxWidth: AppLayout.resultMaxWidth,
              onRefresh: () => _load(forceRefresh: true),
              child: const AppStateView(
                icon: FLucideIcons.wrench,
                title: '暂无报修记录',
              ),
            )
          : AppPageListView(
              maxWidth: AppLayout.resultMaxWidth,
              topPadding: AppSpacing.lg,
              bottomPadding: AppSpacing.xxl,
              onRefresh: () => _load(forceRefresh: true),
              children: [
                Center(
                  child: Text(
                    '点击可查看处理进度',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final record in visible) _buildRecordCard(theme, record),
              ],
            ),
    );
  }

  Widget _buildSkeleton() {
    return AppPageListView(
      maxWidth: AppLayout.resultMaxWidth,
      topPadding: AppSpacing.lg,
      bottomPadding: AppSpacing.xxl,
      onRefresh: () => _load(forceRefresh: true),
      children: [
        AppSkeleton(
          label: '正在加载报修记录',
          child: Column(
            children: [
              const Center(child: AppSkeletonBox(width: 132, height: 12)),
              const SizedBox(height: AppSpacing.sm),
              for (var index = 0; index < 4; index++) _buildSkeletonCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                AppSkeletonBox(width: 52, height: 16, radius: 2),
                Spacer(),
                AppSkeletonBox(width: 84, height: 12),
              ],
            ),
            SizedBox(height: 6),
            AppSkeletonBox(width: double.infinity, height: 20),
            SizedBox(height: 4),
            AppSkeletonBox(width: 188, height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(FThemeData theme, RepairRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onPress: record.formUuid.isEmpty
            ? null
            : () => Navigator.of(context).push(
                appRoute(
                  name: AppRouteNames.repairDetail,
                  builder: (_) => RepairDetailPage(
                    record: record,
                    studentId: widget.studentId,
                    password: widget.password,
                    preferencesStorage: widget.preferencesStorage,
                  ),
                ),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppStatusChip(status: record.status),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              record.address.isNotEmpty
                  ? '${record.areaName}(${record.address})  ${record.itemName}'
                  : '${record.areaName}  ${record.itemName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }


}
