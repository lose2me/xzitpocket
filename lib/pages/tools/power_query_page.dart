import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/power_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../../ui/date_range_calendar_sheet.dart';
import '../../widgets/power_usage_chart.dart';

class PowerQueryPage extends StatefulWidget {
  final PowerQueryData result;
  final String? roomId;
  final String? studentId;
  final PreferencesStorage preferencesStorage;

  const PowerQueryPage({
    super.key,
    required this.result,
    required this.preferencesStorage,
    this.roomId,
    this.studentId,
  });

  @override
  State<PowerQueryPage> createState() => _PowerQueryPageState();
}

class _PowerQueryPageState extends State<PowerQueryPage> {
  final _manager = ToolsDataManager.instance;
  static const _loadBatchSize = 14;
  final _scrollController = ScrollController();
  int _visibleCount = _loadBatchSize;
  bool _isRefreshing = false;
  bool _refreshSucceeded = false;
  bool _showMoney = false;
  late DateTime _startDate;
  late DateTime _endDate;
  late final TextEditingController _rangeCtrl;

  late PowerQueryData _baseResult;
  late List<PowerDailyUsage> _displayUsage;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onCampusNetworkChanged);
    _baseResult = widget.result;
    final today = _today;
    _endDate = today;
    _startDate = today.subtract(const Duration(days: 30));
    _rangeCtrl = TextEditingController(text: _rangeText());
    _scrollController.addListener(_onScroll);
    _updateDisplayUsage(widget.result.dailyUsage);
    if (!PreferencesStorage.isCacheValid(
      widget.preferencesStorage.getPowerCacheTime(),
      const Duration(minutes: 5),
    )) {
      unawaited(_refresh(showError: false));
    }
  }

  @override
  void dispose() {
    _manager.removeListener(_onCampusNetworkChanged);
    _scrollController.dispose();
    _rangeCtrl.dispose();
    super.dispose();
  }

  void _onCampusNetworkChanged() {
    if (mounted) setState(() {});
  }

  bool get _canRefresh => _manager.isCampusNetworkAvailable;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _historyStart {
    return studentHistoryStartDate(widget.studentId, today: _today);
  }

  void _updateDisplayUsage(List<PowerDailyUsage> usage) {
    _displayUsage = List.of(usage)
      ..sort((a, b) => b.dateValue.compareTo(a.dateValue));
    _visibleCount = _loadBatchSize.clamp(0, _displayUsage.length);
  }

  void _onScroll() {
    if (!mounted || _visibleCount >= _displayUsage.length) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      setState(() {
        _visibleCount = (_visibleCount + _loadBatchSize)
            .clamp(0, _displayUsage.length)
            .toInt();
      });
    }
  }

  String _fmtDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _rangeText() => '${_fmtDate(_startDate)} ~ ${_fmtDate(_endDate)}';

  Future<void> _refresh({
    DateTime? startDate,
    DateTime? endDate,
    bool showError = true,
  }) async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.isEmpty) return;
    if (!_canRefresh) {
      if (showError) {
        showAppSnackBar(context, '请连接校园网', severity: ToastSeverity.warning);
      }
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      final PowerQueryData? result;
      final isDefault = startDate == null && endDate == null;
      if (isDefault) {
        result = await _manager.refreshPower(roomId, widget.preferencesStorage);
      } else {
        result = await PowerService().queryRoom(
          roomId,
          startDate: _fmtDate(startDate ?? _startDate),
          endDate: _fmtDate(endDate ?? _endDate),
        );
      }
      if (!mounted) return;
      if (result == null) {
        if (showError) {
          showAppSnackBar(
            context,
            _manager.powerError ?? '刷新失败',
            severity: ToastSeverity.error,
          );
        }
        return;
      }
      final loadedResult = result;
      final changed = !identical(loadedResult, _baseResult);
      setState(() {
        if (isDefault && changed) {
          _baseResult = loadedResult;
        }
        if (isDefault) {
          _endDate = _today;
          _startDate = _endDate.subtract(const Duration(days: 30));
          _rangeCtrl.text = _rangeText();
        }
        if (!isDefault || changed) {
          _updateDisplayUsage(loadedResult.dailyUsage);
        }
        _refreshSucceeded = true;
      });
    } on PowerQueryException catch (e, stackTrace) {
      talker.error('电费详情刷新失败', e, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('电费详情刷新异常', e, stackTrace);
      if (mounted && showError) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showAppSheet<(DateTime, DateTime)>(
      context: context,
      maxHeightRatio: 0.9,
      builder: (_) => AppDateRangeCalendarSheet(
        initial: (_startDate, _endDate),
        minDate: _historyStart,
      ),
    );
    if (picked == null || !mounted) return;
    final (start, end) = picked;
    setState(() {
      _startDate = start;
      _endDate = end;
      _rangeCtrl.text = _rangeText();
    });
    await _refresh(startDate: start, endDate: end);
  }

  Widget _buildRangeField(FThemeData theme) => AppTextField(
    controller: _rangeCtrl,
    hint: '请选择日期范围',
    readOnly: true,
    enabled: !_isRefreshing,
    onTap: _pickRange,
    suffix: _isRefreshing
        ? const FCircularProgress(size: FCircularProgressSizeVariant.sm)
        : const Icon(FLucideIcons.chevronDown),
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final metrics = <_MetricItem>[
      _MetricItem(
        _showMoney ? '剩余金额' : '剩余电量',
        '${_formatAmount(_baseResult.available)} ${_showMoney ? '元' : '度'}',
      ),
      _MetricItem('电价', '${_baseResult.price} 元/度', interactive: true),
      if (_baseResult.monthUsage != null)
        _MetricItem(
          _showMoney ? '本月电费' : '本月用电',
          '${_formatAmount(_baseResult.monthUsage!)} ${_showMoney ? '元' : '度'}',
        ),
      if (_baseResult.estDays != null)
        _MetricItem('预计可用', _formatEstDays(_baseResult.estDays!)),
    ];

    return AppPage(
      title: '电费查询',
      actions: [
        AppIconButton(
          icon: FLucideIcons.refreshCw,
          onPress: _isRefreshing || !_canRefresh ? null : () => _refresh(),
          tooltip: '刷新电费',
          loading: _isRefreshing,
          completed: _refreshSucceeded,
        ),
      ],
      child: AppPageListView(
        controller: _scrollController,
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        children: [
          if (!_canRefresh) ...[
            Row(
              children: [
                Icon(
                  FLucideIcons.wifiOff,
                  size: 18,
                  color: theme.colors.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _manager.campusNetworkStatus == CampusNetworkStatus.checking
                        ? '正在检测校园网，当前显示缓存数据'
                        : '未连接校园网，当前显示缓存数据',
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.roomId ?? '电费查询',
                style: theme.typography.pageTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppAdaptiveGrid(
                children: [
                  for (final metric in metrics) _buildMetricCell(theme, metric),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildRangeField(theme),
              const SizedBox(height: AppSpacing.lg),
              PowerUsageChart(
                usage: _displayUsage,
                showMoney: _showMoney,
                price: _baseResult.price,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Text(
                    '每日用电明细',
                    style: theme.typography.tileTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: FCircularProgress()),
                )
              else if (_displayUsage.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ..._displayUsage
                    .take(_visibleCount)
                    .map((item) => _buildUsageRow(theme, item)),
                if (_visibleCount < _displayUsage.length)
                  const Center(
                    child: FCircularProgress(
                      size: FCircularProgressSizeVariant.sm,
                    ),
                  ),
              ] else ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '该月暂无用电明细',
                  style: theme.typography.body.md.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatEstDays(String value) {
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return '$value 天';
    }
    return value;
  }

  String _formatAmount(String value) {
    if (!_showMoney) return value;
    final amount = double.tryParse(value);
    final price = double.tryParse(_baseResult.price);
    if (amount == null || price == null) return '-';
    return (amount * price).toStringAsFixed(2);
  }

  Widget _buildMetricCell(FThemeData theme, _MetricItem item) {
    Widget card = AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(item.value, style: theme.typography.metric),
        ],
      ),
    );
    if (item.interactive) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colors.primary, width: 1.5),
          color: theme.colors.secondary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FTappable(
          onPress: () => setState(() => _showMoney = !_showMoney),
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildUsageRow(FThemeData theme, PowerDailyUsage item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(child: Text(item.date, style: theme.typography.body.md)),
            Text(
              '${_formatAmount(item.usage)} ${_showMoney ? '元' : '度'}',
              style: theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final bool interactive;

  const _MetricItem(this.label, this.value, {this.interactive = false});
}
