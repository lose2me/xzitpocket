import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/cas_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../services/ykt_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../../ui/date_range_calendar_sheet.dart';

/// 未圈存金额 = 卡内余额之后、尚未计入该余额的流水净额（需求 4）。
///
/// 一卡通中心的余额是最后一次结算的快照；之后的新流水（充值/消费/代扣）还没
/// 写回该余额。这里找到余额快照在流水中的位置，把比它更新的流水金额相加。
/// [txns] 需按时间倒序（最新在前）。找不到快照或无流水时返回占位 `--`。
String yktUncommittedAmount(String balance, List<YktTransaction> txns) {
  final balanceValue = double.tryParse(balance.trim());
  if (balanceValue == null || txns.isEmpty) return '--';
  var snapshot = -1;
  for (var index = 0; index < txns.length; index++) {
    final ledger = double.tryParse(txns[index].balance.trim());
    if (ledger != null && (ledger - balanceValue).abs() < 0.005) {
      snapshot = index;
      break;
    }
  }
  if (snapshot < 0) return '--';
  if (snapshot == 0) return '0.00 元';
  var pending = 0.0;
  for (var index = 0; index < snapshot; index++) {
    pending += double.tryParse(txns[index].amount.trim()) ?? 0;
  }
  return '${pending.toStringAsFixed(2)} 元';
}

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
  bool _isQuerying = false;
  final _scrollController = ScrollController();
  int _visibleCount = _pageSize;

  late YktDetailResult _result;
  late List<YktTransaction> _txns;
  late DateTime _startDate;
  late DateTime _endDate;
  final _rangeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _txns = sortYktTransactionsNewestFirst(_result.transactions);
    _endDate = DateTime.now();
    // 后台默认已按「选择全部」范围拉取，页面显示的默认范围与之一致。
    _startDate = studentHistoryStartDate(widget.studentId, today: _endDate);
    _rangeCtrl.text = _rangeText();
    _scrollController.addListener(_onScroll);
    if (!PreferencesStorage.isCacheValid(
      widget.preferencesStorage.getYktCacheTime(),
      const Duration(minutes: 5),
    )) {
      unawaited(_refresh(showError: false));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _rangeCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showError = true}) async {
    try {
      final result = await ToolsDataManager.instance.refreshYkt(
        widget.studentId,
        widget.password,
        widget.preferencesStorage,
      );
      if (!mounted) return;
      if (result == null) {
        if (showError) {
          showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
        }
        return;
      }
      final changed = !identical(result, _result);
      setState(() {
        if (changed) {
          _result = result;
          _txns = sortYktTransactionsNewestFirst(result.transactions);
          _visibleCount = _pageSize;
        }
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('一卡通详情刷新失败', e, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('一卡通详情刷新异常', e, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
    }
  }

  // 滚动接近底部时，自动加载更多交易。
  void _onScroll() {
    if (!mounted || _visibleCount >= _txns.length) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      setState(() {
        _visibleCount = (_visibleCount + _pageSize)
            .clamp(0, _txns.length)
            .toInt();
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _queryRange() async {
    if (_startDate.isAfter(_endDate)) {
      showAppSnackBar(context, '开始日期不能晚于结束日期', severity: ToastSeverity.warning);
      return;
    }
    setState(() => _isQuerying = true);
    try {
      final result = await ToolsDataManager.instance.queryYktRange(
        widget.studentId,
        widget.password,
        start: _startDate,
        end: _endDate,
      );
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(context, '查询失败', severity: ToastSeverity.error);
        return;
      }
      setState(() {
        _result = result;
        _txns = sortYktTransactionsNewestFirst(result.transactions);
        _visibleCount = _pageSize;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('一卡通区间查询失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('一卡通区间查询异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '查询失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _isQuerying = false);
    }
  }

  String _rangeText() {
    if (_startDate == _endDate) return _fmt(_startDate);
    return '${_fmt(_startDate)} ~ ${_fmt(_endDate)}';
  }

  Widget _buildRangeField(FThemeData theme) {
    return AppTextField(
      controller: _rangeCtrl,
      hint: '请选择日期范围',
      readOnly: true,
      enabled: !_isQuerying,
      textAlign: TextAlign.center,
      onTap: _pickRange,
      suffix: _isQuerying
          ? const Padding(
              padding: EdgeInsets.only(right: 5),
              child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
            )
          : null,
    );
  }

  Future<void> _pickRange() async {
    final picked = await Navigator.of(context).push<(DateTime, DateTime)>(
      appRoute(
        name: '/tools/campus-card/date-range',
        fullscreenDialog: true,
        builder: (_) => AppDateRangeCalendarPage(
          initial: (_startDate, _endDate),
          minDate: studentHistoryStartDate(widget.studentId),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final (start, end) = picked;
    setState(() {
      _startDate = start;
      _endDate = end;
      _visibleCount = _pageSize;
      _rangeCtrl.text = _rangeText();
    });
    // 选中日期后自动查询。
    await _queryRange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final bal = _result.balance;

    return AppPage(
      title: '一卡通查询',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        controller: _scrollController,
        onRefresh: () => _refresh(),
        children: [
          Text('卡片信息', style: theme.typography.pageTitle),
          const SizedBox(height: AppSpacing.md),
          AppAdaptiveGrid(
            children: [
              _buildMetricCell(theme, '卡号', bal.cardNo),
              _buildMetricCell(theme, '余额', '${bal.balance} 元'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text('交易明细', style: theme.typography.tileTitle),
              const Spacer(),
              // 未圈存金额放在「交易明细」行右侧，不再单独占一块。
              Text(
                '未圈存金额 ${yktUncommittedAmount(bal.balance, _txns)}',
                style: theme.typography.bodySmall.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRangeField(theme),
          const SizedBox(height: AppSpacing.lg),
          if (_txns.isNotEmpty) ...[
            for (var index = 0; index < _visibleCount; index++)
              _buildTxnTile(
                theme,
                _txns[index],
                // Matches the campus-card website: only the first row shows the
                // card's current balance, the rest have no balance column.
                remainder: index == 0 ? bal.balance : null,
              ),
            if (_visibleCount < _txns.length) ...[
              const SizedBox(height: AppSpacing.md),
              const Center(
                child: FCircularProgress(size: FCircularProgressSizeVariant.sm),
              ),
            ],
          ] else
            const AppStateView(
              icon: FLucideIcons.inbox,
              title: '暂无交易',
              description: '该时间范围内没有交易记录',
            ),
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
          Text(
            value,
            style: theme.typography.body.sm.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTxnTile(
    FThemeData theme,
    YktTransaction t, {
    String? remainder,
  }) {
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
                        : theme.colors.semantic.success,
                  ),
                ),
                if (remainder != null && remainder.trim().isNotEmpty)
                  Text(
                    '余 $remainder',
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
