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
  bool _isQuerying = false;

  late YktDetailResult _result;
  late List<YktTransaction> _txns;
  late DateTime _startDate;
  late DateTime _endDate;
  final _rangeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _txns = _result.transactions.reversed.toList();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _rangeCtrl.text = _rangeText();
  }

  @override
  void dispose() {
    _rangeCtrl.dispose();
    super.dispose();
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
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
        return;
      }
      setState(() {
        _result = result;
        _txns = result.transactions.reversed.toList();
        _currentPage = 0;
      });
    } on AuthException catch (e, stackTrace) {
      talker.error('一卡通详情刷新失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('一卡通详情刷新异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _rangeLabel {
    if (_startDate == _endDate) {
      return '交易明细（${_fmt(_startDate)}）';
    }
    return '交易明细（${_fmt(_startDate)} ~ ${_fmt(_endDate)}）';
  }

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
        _txns = result.transactions.reversed.toList();
        _currentPage = 0;
      });
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
      onTap: _pickRange,
      suffix: _isQuerying
          ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
          : const Icon(FLucideIcons.chevronDown),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showAppSheet<(DateTime, DateTime)>(
      context: context,
      maxHeightRatio: 0.9,
      builder: (ctx) => _YktRangeCalendarSheet(initial: (_startDate, _endDate)),
    );
    if (picked == null || !mounted) return;
    final (start, end) = picked;
    setState(() {
      _startDate = start;
      _endDate = end;
      _currentPage = 0;
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
          const SizedBox(height: AppSpacing.xl),
          Text('交易明细', style: theme.typography.tileTitle),
          const SizedBox(height: AppSpacing.md),
          _buildRangeField(theme),
          const SizedBox(height: AppSpacing.lg),
          if (_txns.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(_rangeLabel, style: theme.typography.tileTitle),
                ),
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

/// 一个控件内选择「起止」一段日期的范围日历弹层。
class _YktRangeCalendarSheet extends StatefulWidget {
  final (DateTime, DateTime) initial;

  const _YktRangeCalendarSheet({required this.initial});

  @override
  State<_YktRangeCalendarSheet> createState() => _YktRangeCalendarSheetState();
}

class _YktRangeCalendarSheetState extends State<_YktRangeCalendarSheet> {
  late (DateTime, DateTime) _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initial;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${_fmt(_range.$1)} ~ ${_fmt(_range.$2)}',
                style: theme.typography.label.copyWith(
                  color: theme.colors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // 用 LayoutBuilder 让每个日期格随可用宽度自适应（7 列刚好铺满，不再挤压）。
            // 不固定 6 行：按当月实际行数布局，出现空行的问题就不会有。
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 2.0;
                final size = ((constraints.maxWidth - spacing * 6) / 7).clamp(
                  32.0,
                  44.0,
                );
                return FCalendar.splitGrid(
                  selectionControl: FDateSelectionControl.managedRange(
                    initial: widget.initial,
                    onChange: (range) {
                      if (range != null) setState(() => _range = range);
                    },
                  ),
                  style: FCalendarStyleDelta.delta(
                    dayPickerStyle: FCalendarDayPickerStyleDelta.delta(
                      daySize: Size.square(size),
                      daySpacing: spacing,
                    ),
                  ),
                  dayBuilder: (context, styles, localizations, date, variants) {
                    if (variants.any(
                      (v) => v == FCalendarDayVariant.adjacent,
                    )) {
                      return const SizedBox.shrink();
                    }
                    return FCalendar.defaultDayBuilder(
                      context,
                      styles,
                      localizations,
                      date,
                      variants,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: () => Navigator.pop(context, _range),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
