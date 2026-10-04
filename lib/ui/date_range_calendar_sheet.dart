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
/// Months are displayed vertically so the complete history can be browsed on
/// one full-screen page. Tap once for the start, then again for the end.
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

/// Full-screen date-range picker used by detail pages with longer histories.
class AppDateRangeCalendarPage extends StatelessWidget {
  final (DateTime, DateTime) initial;
  final DateTime minDate;

  const AppDateRangeCalendarPage({
    super.key,
    required this.initial,
    required this.minDate,
  });

  @override
  Widget build(BuildContext context) => AppPage(
    title: '选择日期范围',
    child: AppDateRangeCalendarSheet(initial: initial, minDate: minDate),
  );
}

class _AppDateRangeCalendarSheetState extends State<AppDateRangeCalendarSheet> {
  late final DateTime _today;
  late final DateTime _calendarStart;
  late final List<DateTime> _months;
  late final List<FGridSplitCalendarController> _calendarControllers;
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
    _months = [
      for (
        var month = DateTime.utc(_calendarStart.year, _calendarStart.month);
        !month.isAfter(DateTime.utc(_today.year, _today.month));
        month = DateTime.utc(month.year, month.month + 1)
      )
        month,
    ];
    _calendarControllers = [
      for (final month in _months)
        FGridSplitCalendarController(
          start: _calendarStart,
          today: _today,
          initial: month,
          end: _today,
        ),
    ];
  }

  @override
  void dispose() {
    for (final controller in _calendarControllers) {
      controller.dispose();
    }
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
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${_fmt(_range.$1)} ~ ${_fmt(_range.$2)}',
                textAlign: TextAlign.center,
                style: theme.typography.label.copyWith(
                  color: theme.colors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                itemCount: _months.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) => _buildMonth(
                  context,
                  _months[index],
                  _calendarControllers[index],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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

  Widget _buildMonth(
    BuildContext context,
    DateTime month,
    FGridSplitCalendarController controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 2.0;
        final calendarPadding = context.theme.calendarStyle.padding.resolve(
          Directionality.of(context),
        );
        final size =
            ((constraints.maxWidth - calendarPadding.horizontal - spacing * 6) /
                    7)
                .clamp(32.0, 44.0)
                .toDouble();
        return FCalendar.splitGrid(
          control: FGridSplitCalendarControl(controller: controller),
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
          headerBuilder: (context, _, _, _) => Center(
            child: Text(
              '${month.year}年${month.month}月',
              style: context.theme.typography.tileTitle.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          onDayPress: (date) => _selectDay(date, controller),
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
    );
  }

  void _selectDay(DateTime date, FGridSplitCalendarController controller) {
    final currentMonth = controller.currentMonth;
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

  void _selectAll() {
    setState(() {
      _pendingStart = null;
      _range = (_calendarStart, _today);
    });
  }
}
