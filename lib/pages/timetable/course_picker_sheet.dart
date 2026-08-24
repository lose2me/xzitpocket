import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';

class CoursePickerColumn {
  final String label;
  final List<String> options;
  final int flex;

  const CoursePickerColumn({
    required this.label,
    required this.options,
    this.flex = 1,
  });
}

class CourseWheelPickerSheet extends StatefulWidget {
  final String title;
  final List<CoursePickerColumn> columns;
  final List<int> initialIndexes;
  final bool Function(List<int> indexes)? isValid;
  final String invalidMessage;

  const CourseWheelPickerSheet({
    super.key,
    required this.title,
    required this.columns,
    required this.initialIndexes,
    this.isValid,
    this.invalidMessage = '请选择有效范围',
  }) : assert(columns.length == initialIndexes.length);

  @override
  State<CourseWheelPickerSheet> createState() => _CourseWheelPickerSheetState();
}

class _CourseWheelPickerSheetState extends State<CourseWheelPickerSheet> {
  late List<int> _indexes;

  @override
  void initState() {
    super.initState();
    _indexes = [...widget.initialIndexes];
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.isValid?.call(_indexes) ?? true;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: context.theme.typography.tileTitle),
            const SizedBox(height: AppSpacing.lg),
            _PickerColumnLabels(columns: widget.columns),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 180,
              child: FPicker(
                control: FPickerControl.lifted(
                  indexes: _indexes,
                  onChange: (indexes) => setState(() => _indexes = indexes),
                ),
                children: [
                  for (final column in widget.columns)
                    FPickerWheel(
                      flex: column.flex,
                      semanticsLabel: column.label,
                      children: [
                        for (final option in column.options) Text(option),
                      ],
                    ),
                ],
              ),
            ),
            if (!valid) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.invalidMessage,
                style: context.theme.typography.caption.copyWith(
                  color: context.theme.colors.destructive,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: valid
                    ? () => Navigator.pop(context, List<int>.from(_indexes))
                    : null,
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseWeekPickerSheet extends StatefulWidget {
  final List<int> initialWeeks;
  final int maxWeek;

  const CourseWeekPickerSheet({
    super.key,
    required this.initialWeeks,
    required this.maxWeek,
  });

  @override
  State<CourseWeekPickerSheet> createState() => _CourseWeekPickerSheetState();
}

class _CourseWeekPickerSheetState extends State<CourseWeekPickerSheet> {
  static const _patterns = ['每周', '单周', '双周', '自定义'];

  late List<int> _indexes;
  late Set<int> _customWeeks;

  @override
  void initState() {
    super.initState();
    final weeks = _sortedUnique(widget.initialWeeks);
    final start = weeks.isEmpty ? 1 : weeks.first;
    final end = weeks.isEmpty ? widget.maxWeek : weeks.last;
    _indexes = [start - 1, end - 1, _inferPattern(weeks)];
    _customWeeks = weeks.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      CoursePickerColumn(
        label: '开始周',
        options: [for (var week = 1; week <= widget.maxWeek; week++) '第$week周'],
      ),
      CoursePickerColumn(
        label: '结束周',
        options: [for (var week = 1; week <= widget.maxWeek; week++) '第$week周'],
      ),
      const CoursePickerColumn(label: '重复', options: _patterns),
    ];
    final custom = _indexes[2] == 3;
    final selectedWeeks = _selection;
    final valid = selectedWeeks.isNotEmpty;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择周次', style: context.theme.typography.tileTitle),
            const SizedBox(height: AppSpacing.lg),
            _PickerColumnLabels(columns: columns),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 180,
              child: FPicker(
                control: FPickerControl.lifted(
                  indexes: _indexes,
                  onChange: (indexes) => setState(() => _indexes = indexes),
                ),
                children: [
                  for (final column in columns)
                    FPickerWheel(
                      flex: column.flex,
                      semanticsLabel: column.label,
                      children: [
                        for (final option in column.options) Text(option),
                      ],
                    ),
                ],
              ),
            ),
            if (custom) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: (() {
                  final rows = (widget.maxWeek / 5).ceil();
                  return (rows * 36.0 + (rows - 1) * AppSpacing.sm)
                      .clamp(44.0, 220.0)
                      .toDouble();
                })(),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisExtent: 36,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  ),
                  itemCount: widget.maxWeek,
                  itemBuilder: (context, index) {
                    final week = index + 1;
                    final selected = _customWeeks.contains(week);
                    return FButton(
                      size: FButtonSizeVariant.xs,
                      variant: selected
                          ? FButtonVariant.primary
                          : FButtonVariant.outline,
                      onPress: () => setState(() {
                        if (selected) {
                          _customWeeks.remove(week);
                        } else {
                          _customWeeks.add(week);
                        }
                      }),
                      child: Text('$week'),
                    );
                  },
                ),
              ),
            ],
            if (!valid) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '请至少选择一个周次',
                style: context.theme.typography.caption.copyWith(
                  color: context.theme.colors.destructive,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: valid
                    ? () => Navigator.pop(context, selectedWeeks)
                    : null,
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> get _selection {
    if (_indexes[2] == 3) return _sortedUnique(_customWeeks);

    final start = _indexes[0] + 1;
    final end = _indexes[1] + 1;
    if (start > end) return const [];

    final weeks = [for (var week = start; week <= end; week++) week];
    return switch (_indexes[2]) {
      1 => weeks.where((week) => week.isOdd).toList(),
      2 => weeks.where((week) => week.isEven).toList(),
      _ => weeks,
    };
  }

  static int _inferPattern(List<int> weeks) {
    if (weeks.length < 2) return 0;
    final contiguous = _hasStep(weeks, 1);
    if (contiguous) return 0;
    if (_hasStep(weeks, 2) && weeks.every((week) => week.isOdd)) return 1;
    if (_hasStep(weeks, 2) && weeks.every((week) => week.isEven)) return 2;
    return 3;
  }

  static bool _hasStep(List<int> values, int step) {
    for (var index = 1; index < values.length; index++) {
      if (values[index] != values[index - 1] + step) return false;
    }
    return true;
  }
}

class _PickerColumnLabels extends StatelessWidget {
  final List<CoursePickerColumn> columns;

  const _PickerColumnLabels({required this.columns});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final column in columns)
        Expanded(
          flex: column.flex,
          child: Text(
            column.label,
            textAlign: TextAlign.center,
            style: context.theme.typography.caption.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ),
    ],
  );
}

List<int> _sortedUnique(Iterable<int> values) =>
    values.toSet().toList()..sort();
