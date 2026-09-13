import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_components.dart';

DateTime studentHistoryStartDate(String? studentId, {DateTime? today}) {
  final current = today ?? DateTime.now();
  final currentDate = DateTime(current.year, current.month, current.day);
  final prefix = RegExp(r'^\s*(\d{2})').firstMatch(studentId ?? '');
  final shortYear = prefix == null ? null : int.tryParse(prefix.group(1)!);
  final year = (shortYear == null ? currentDate.year : 2000 + shortYear)
      .clamp(2000, currentDate.year)
      .toInt();
  final admissionStart = DateTime(year, 6, 1);
  return admissionStart.isAfter(currentDate) ? currentDate : admissionStart;
}

/// Date-range selector shared by detail pages that query a server-side range.
/// The interaction mirrors the campus-card picker: tap once for the start,
/// tap again for the end, or use “选择全部” to select the complete range.
class AppDateRangeCalendarSheet extends StatefulWidget {
  final (DateTime, DateTime) initial;
  final DateTime minDate;

  AppDateRangeCalendarSheet({
    super.key,
    required this.initial,
    DateTime? minDate,
  }) : minDate = minDate ?? DateTime(2000, 1, 1);

  @override
  State<AppDateRangeCalendarSheet> createState() =>
      _AppDateRangeCalendarSheetState();
}

class _AppDateRangeCalendarSheetState extends State<AppDateRangeCalendarSheet> {
  late final DateTime _today;
  late final DateTime _calendarStart;
  late final List<int> _yearOptions;
  late final FGridSplitCalendarController _calendarController;
  late (DateTime, DateTime) _range;
  DateTime? _pendingStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime.utc(now.year, now.month, now.day);
    final minimum = DateTime.utc(
      widget.minDate.year,
      widget.minDate.month,
      widget.minDate.day,
    );
    _calendarStart = minimum.isAfter(_today) ? _today : minimum;
    var start = _normalize(widget.initial.$1);
    var end = _normalize(widget.initial.$2);
    if (end.isBefore(start)) (start, end) = (end, start);
    if (start.isBefore(_calendarStart)) start = _calendarStart;
    if (end.isAfter(_today)) end = _today;
    if (end.isBefore(start)) end = start;
    _range = (start, end);
    _yearOptions = [
      for (var year = _calendarStart.year; year <= _today.year; year++) year,
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

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _normalize(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

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
                    onChange: (_) {},
                  ),
                  style: FCalendarStyleDelta.delta(
                    dayPickerStyle: FCalendarDayPickerStyleDelta.delta(
                      daySize: Size.square(size),
                      daySpacing: spacing,
                    ),
                  ),
                  headerBuilder: _buildCalendarHeader,
                  onDayPress: _selectDay,
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

  void _selectDay(DateTime date) {
    final currentMonth = _calendarController.currentMonth;
    if (date.year != currentMonth.year || date.month != currentMonth.month) {
      return;
    }
    final day = _normalize(date);
    final first = _pendingStart;
    if (first == null) {
      setState(() {
        _pendingStart = day;
        _range = (day, day);
      });
      return;
    }
    final start = day.isBefore(first) ? day : first;
    final end = day.isBefore(first) ? first : day;
    setState(() {
      _pendingStart = null;
      _range = (start, end);
    });
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
          mainAxisSize: MainAxisSize.min,
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
              if (values.isNotEmpty) Navigator.pop(sheetContext, values.first);
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
    final minMonth = selected == _calendarStart.year ? _calendarStart.month : 1;
    final maxMonth = selected == _today.year ? _today.month : 12;
    final month = controller.currentMonth.month.clamp(minMonth, maxMonth);
    controller.jumpToDayPicker(DateTime.utc(selected, month));
  }

  void _selectAll() {
    setState(() {
      _pendingStart = null;
      _range = (_calendarStart, _today);
    });
    _calendarController.jumpToDayPicker(_calendarStart);
  }
}
