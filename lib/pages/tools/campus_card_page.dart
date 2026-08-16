import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../services/ykt_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

class CampusCardPage extends StatefulWidget {
  final YktDetailResult result;
  final String studentId;
  final String password;
  final PreferencesStorage preferencesStorage;

  const CampusCardPage({
    super.key,
    required this.result,
    required this.studentId,
    required this.password,
    required this.preferencesStorage,
  });

  @override
  State<CampusCardPage> createState() => _CampusCardPageState();
}

class _CampusCardPageState extends State<CampusCardPage> {
  static const _pageSize = 7;
  int _currentPage = 0;
  bool _isRefreshing = false;

  late YktDetailResult _result;
  late List<YktTransaction> _txns;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _txns = _result.transactions.reversed.toList();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final result = await ToolsDataManager.instance.refreshYkt(
        widget.studentId,
        widget.password,
        widget.preferencesStorage,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '刷新失败');
        return;
      }
      setState(() {
        _result = result;
        _txns = result.transactions.reversed.toList();
        _currentPage = 0;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('一卡通详情刷新失败', e, stackTrace);
      if (mounted) showAppSnackBar(context, e.message);
    } catch (e, stackTrace) {
      talker.error('一卡通详情刷新异常', e, stackTrace);
      if (mounted) showAppSnackBar(context, '刷新失败');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  int get _totalPages => (_txns.length / _pageSize).ceil().clamp(1, 999);

  List<YktTransaction> _pageItems(int page) {
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, _txns.length);
    return _txns.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final bal = _result.balance;

    return AppPage(
      title: '一卡通查询',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isRefreshing ? null : _refresh,
          tooltip: '刷新一卡通',
          loading: _isRefreshing,
        ),
      ],
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          Text('卡片信息', style: theme.typography.pageTitle),
          const SizedBox(height: AppSpacing.md),
          AppAdaptiveGrid(
            children: [
              _buildMetricCell(theme, '卡号', bal.cardNo),
              _buildMetricCell(theme, '余额', '${bal.balance} 元'),
            ],
          ),
          if (_txns.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Text('交易明细（30天）', style: theme.typography.tileTitle),
                const Spacer(),
                AppIconButton(
                  icon: FLucideIcons.chevronLeft,
                  onPress: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  tooltip: '上一页',
                  size: FButtonSizeVariant.xs,
                ),
                Text(
                  '${_currentPage + 1}/$_totalPages',
                  style: theme.typography.label,
                ),
                AppIconButton(
                  icon: FLucideIcons.chevronRight,
                  onPress: _currentPage < _totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  tooltip: '下一页',
                  size: FButtonSizeVariant.xs,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._pageItems(_currentPage).map((t) => _buildTxnTile(theme, t)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCell(FThemeData theme, String label, String value) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: theme.typography.metric),
        ],
      ),
    );
  }

  Widget _buildTxnTile(FThemeData theme, YktTransaction t) {
    final isNeg = t.amount.startsWith('-');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.location.isNotEmpty ? t.location : t.type,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.time,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isNeg ? '' : '+'}${t.amount}',
                  style: theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNeg
                        ? theme.colors.destructive
                        : theme.colors.primary,
                  ),
                ),
                if (t.balance.isNotEmpty)
                  Text(
                    '余 ${t.balance}',
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
