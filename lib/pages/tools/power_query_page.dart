import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../services/power_service.dart';
import '../../services/preferences_storage.dart';
import '../../services/talker.dart';
import '../../services/tools_data_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';

class PowerQueryPage extends StatefulWidget {
  final PowerQueryData result;
  final String? roomId;
  final PreferencesStorage preferencesStorage;

  const PowerQueryPage({
    super.key,
    required this.result,
    required this.preferencesStorage,
    this.roomId,
  });

  @override
  State<PowerQueryPage> createState() => _PowerQueryPageState();
}

class _PowerQueryPageState extends State<PowerQueryPage> {
  final _manager = ToolsDataManager.instance;
  static const _pageSize = 7;
  int _currentPage = 0;
  bool _isRefreshing = false;
  late DateTime _selectedMonth;

  late PowerQueryData _baseResult;
  late List<PowerDailyUsage> _displayUsage;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onCampusNetworkChanged);
    _baseResult = widget.result;
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _updateDisplayUsage(widget.result.dailyUsage, isCurrentMonth: true);
  }

  @override
  void dispose() {
    _manager.removeListener(_onCampusNetworkChanged);
    super.dispose();
  }

  void _onCampusNetworkChanged() {
    if (mounted) setState(() {});
  }

  bool get _canRefresh => _manager.isCampusNetworkAvailable;

  void _updateDisplayUsage(
    List<PowerDailyUsage> usage, {
    required bool isCurrentMonth,
  }) {
    if (isCurrentMonth) {
      _displayUsage = usage.reversed.toList();
    } else {
      _displayUsage = List.of(usage);
    }
  }

  Future<void> _refresh({String? startDate}) async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.isEmpty) return;
    if (!_canRefresh) {
      showAppSnackBar(context, '请连接校园网', severity: ToastSeverity.warning);
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      final PowerQueryData? result;
      if (startDate == null) {
        result = await _manager.refreshPower(roomId, widget.preferencesStorage);
      } else {
        result = await PowerService().queryRoom(roomId, startDate: startDate);
      }
      if (!mounted) return;
      if (result == null) {
        showAppSnackBar(
          context,
          _manager.powerError ?? '刷新失败',
          severity: ToastSeverity.error,
        );
        return;
      }
      final loadedResult = result;
      final isCurrent = startDate == null;
      setState(() {
        if (isCurrent) _baseResult = loadedResult;
        _updateDisplayUsage(
          loadedResult.dailyUsage,
          isCurrentMonth: _isCurrentMonth,
        );
        _currentPage = 0;
      });
    } on PowerQueryException catch (e, stackTrace) {
      talker.error('电费详情刷新失败', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, e.message, severity: ToastSeverity.error);
      }
    } catch (e, stackTrace) {
      talker.error('电费详情刷新异常', e, stackTrace);
      if (mounted) {
        showAppSnackBar(context, '刷新失败', severity: ToastSeverity.error);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    if (_isCurrentMonth) {
      unawaited(_refresh());
    } else {
      final formatted =
          '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      unawaited(_refresh(startDate: formatted));
    }
  }

  int get _totalPages =>
      (_displayUsage.length / _pageSize).ceil().clamp(1, 999);

  List<PowerDailyUsage> _pageItems(int page) {
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, _displayUsage.length);
    return _displayUsage.sublist(start, end);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final metrics = <_MetricItem>[
      _MetricItem('剩余电量', '${_baseResult.available} 度'),
      _MetricItem('电价', '${_baseResult.price} 元/度'),
      if (_baseResult.monthUsage != null)
        _MetricItem('本月用电', '${_baseResult.monthUsage} 度'),
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
        ),
      ],
      child: AppPageListView(
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
              Row(
                children: [
                  AppIconButton(
                    icon: FLucideIcons.chevronLeft,
                    onPress: _isRefreshing || !_canRefresh
                        ? null
                        : () => _changeMonth(-1),
                    tooltip: '上个月',
                    size: FButtonSizeVariant.xs,
                  ),
                  Text(
                    '${_selectedMonth.year}年${_selectedMonth.month}月',
                    style: theme.typography.tileTitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppIconButton(
                    icon: FLucideIcons.chevronRight,
                    onPress: _isRefreshing || _isCurrentMonth || !_canRefresh
                        ? null
                        : () => _changeMonth(1),
                    tooltip: '下个月',
                    size: FButtonSizeVariant.xs,
                  ),
                  const Spacer(),
                  if (_displayUsage.length > _pageSize) ...[
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
                      style: theme.typography.body.md,
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
                ],
              ),
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: FCircularProgress()),
                )
              else if (_displayUsage.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ..._pageItems(_currentPage)
                    .map((item) => _buildUsageRow(theme, item)),
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

  Widget _buildMetricCell(FThemeData theme, _MetricItem item) {
    return AppCard(
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
              '${item.usage} 度',
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

  const _MetricItem(this.label, this.value);
}
