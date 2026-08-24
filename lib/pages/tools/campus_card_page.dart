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
  bool _isRefreshing = false;
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
    _txns = _result.transactions.reversed.toList();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _rangeCtrl.text = _rangeText();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        _visibleCount = _pageSize;
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
        _txns = result.transactions.reversed.toList();
        _visibleCount = _pageSize;
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
      builder: (ctx) => _YktRangeCalendarSheet(
        initial: (_startDate, _endDate),
        studentId: widget.studentId,
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
        controller: _scrollController,
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
            for (final t in _txns.take(_visibleCount)) _buildTxnTile(theme, t),
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
                        : theme.colors.semantic.success,
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
  final String studentId;

  const _YktRangeCalendarSheet({
    required this.initial,
    required this.studentId,
  });

  @override
  State<_YktRangeCalendarSheet> createState() => _YktRangeCalendarSheetState();
}

class _YktRangeCalendarSheetState extends State<_YktRangeCalendarSheet> {
  late final int _admissionYear;
  late final DateTime _today;
  late final DateTime _calendarStart;
  late final List<int> _yearOptions;
  late final FGridSplitCalendarController _calendarController;
  late (DateTime, DateTime) _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initial;

    final now = DateTime.now();
    _today = DateTime.utc(now.year, now.month, now.day);
    _admissionYear = _parseAdmissionYear(widget.studentId, _today.year);
    final admissionStart = DateTime.utc(_admissionYear, 6, 1);
    _calendarStart = admissionStart.isAfter(_today)
        ? DateTime.utc(_today.year, 1, 1)
        : admissionStart;
    _yearOptions = [
      for (var year = _admissionYear; year <= _today.year; year++) year,
    ];
    _calendarController = FGridSplitCalendarController(
      start: _calendarStart,
      today: _today,
      initial: _today,
      end: _today,
    );
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  static int _parseAdmissionYear(String studentId, int currentYear) {
    final prefix = RegExp(r'^\d{2}').firstMatch(studentId.trim())?.group(0);
    final shortYear = prefix == null ? null : int.tryParse(prefix);
    final year = shortYear == null ? currentYear : 2000 + shortYear;
    return year.clamp(2000, currentYear).toInt();
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
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 2.0;
                final calendarPadding = context.theme.calendarStyle.padding
                    .resolve(Directionality.of(context));
                final size =
                    ((constraints.maxWidth -
                                calendarPadding.horizontal -
                                spacing * 6) /
                            7)
                        .clamp(32.0, 44.0)
                        .toDouble();
                return FCalendar.splitGrid(
                  control: FGridSplitCalendarControl(
                    controller: _calendarController,
                  ),
                  fixedWeeks: false,
                  selectionControl: FDateSelectionControl.liftedRange(
                    value: _range,
                    onChange: (range) {
                      if (range != null && mounted) {
                        setState(() => _range = range);
                      }
                    },
                  ),
                  style: FCalendarStyleDelta.delta(
                    dayPickerStyle: FCalendarDayPickerStyleDelta.delta(
                      daySize: Size.square(size),
                      daySpacing: spacing,
                    ),
                  ),
                  headerBuilder: _buildCalendarHeader,
                  dayBuilder: (context, styles, localizations, date, variants) {
                    if (variants.contains(FCalendarDayVariant.adjacent)) {
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
            Row(
              children: [
                Expanded(
                  child: FButton(
                    variant: .outline,
                    onPress: _selectAll,
                    child: const Text('选择全部'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FButton(
                    onPress: () => Navigator.pop(context, _range),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(
    BuildContext context,
    FGridSplitCalendarController controller,
    FDateSelectionController selection,
    Widget child,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FButton(
          variant: .ghost,
          size: .sm,
          mainAxisSize: .min,
          suffix: const Icon(FLucideIcons.chevronDown),
          onPress: () => _pickYear(controller),
          child: Text('${controller.currentMonth.year}年'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${controller.currentMonth.month}月',
          style: context.theme.typography.tileTitle.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _pickYear(FGridSplitCalendarController controller) async {
    final selected = await showAppSheet<int>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: FSelectTileGroup<int>(
          control: FMultiValueControl.managedRadio(
            initial: controller.currentMonth.year,
            onChange: (values) {
              if (values.isNotEmpty) {
                Navigator.pop(sheetContext, values.first);
              }
            },
          ),
          maxHeight: 360,
          children: [
            for (final year in _yearOptions)
              FSelectTile<int>.suffix(title: Text('$year年'), value: year),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    _jumpToYear(controller, selected);
  }

  void _jumpToYear(FGridSplitCalendarController controller, int year) {
    final minMonth = year == _calendarStart.year ? _calendarStart.month : 1;
    final maxMonth = year == _today.year ? _today.month : 12;
    final month = controller.currentMonth.month.clamp(minMonth, maxMonth);
    controller.jumpToDayPicker(DateTime.utc(year, month));
  }

  void _selectAll() {
    var start = DateTime.utc(_admissionYear, 6, 1);
    if (start.isAfter(_today)) start = _today;
    setState(() => _range = (start, _today));
    _calendarController.jumpToDayPicker(start);
  }
}
