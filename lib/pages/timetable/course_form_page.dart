import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../utils/course_text_parser.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import 'course_picker_sheet.dart';

class CourseFormPage extends StatefulWidget {
  final int weekday;
  final int session;
  final Course? existingCourse;
  final Color? defaultColor;
  final Future<void> Function(Course) onSave;
  final Future<void> Function()? onDelete;

  const CourseFormPage({
    super.key,
    required this.weekday,
    required this.session,
    this.existingCourse,
    this.defaultColor,
    required this.onSave,
    this.onDelete,
  });

  bool get isEditing => existingCourse != null;

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  static const _weekdayLabels = [
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _campusCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _weekdayCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController();
  late List<int> _weeks;
  late int _weekday;
  late int _startSession;
  late int _endSession;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCourse;
    if (c != null) {
      _titleCtrl.text = c.title;
      _teacherCtrl.text = c.teacher;
      _placeCtrl.text = c.place;
      _campusCtrl.text = c.campus;
      _weeks = _sortedUnique(c.weeks.isEmpty ? const [1] : c.weeks);
      _weekday = c.weekday.clamp(1, 7);
      _startSession = c.startSession.clamp(1, 14);
      _endSession = c.endSession.clamp(_startSession, 14);
      _colorCtrl.text = _colorToHex(c.color);
    } else {
      _weeks = [for (var week = 1; week <= 20; week++) week];
      _weekday = widget.weekday.clamp(1, 7);
      _startSession = widget.session.clamp(1, 14);
      _endSession = (widget.session + 1).clamp(_startSession, 14);
      _colorCtrl.text = _colorToHex(widget.defaultColor ?? Course.colors.first);
    }
    _syncPickerText();
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teacherCtrl.dispose();
    _placeCtrl.dispose();
    _campusCtrl.dispose();
    _weeksCtrl.dispose();
    _colorCtrl.dispose();
    _weekdayCtrl.dispose();
    _sessionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: widget.isEditing ? '编辑课程' : '添加课程',
      actions: [
        FHeaderAction(
          icon: const Icon(FLucideIcons.check),
          semanticsLabel: '保存',
          onPress: _save,
        ),
      ],
      footer: widget.onDelete != null
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.pageGutter(context),
                  AppSpacing.sm,
                  AppLayout.pageGutter(context),
                  AppSpacing.md,
                ),
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.formMaxWidth,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FButton(
                        variant: FButtonVariant.destructive,
                        onPress: _confirmDelete,
                        child: const Text('删除课程'),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      child: Form(
        key: _formKey,
        child: AppPageListView(
          maxWidth: AppLayout.formMaxWidth,
          topPadding: AppSpacing.lg,
          bottomPadding: AppSpacing.xxl,
          children: [
            if (widget.existingCourse?.courseId.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '课程编号: ${widget.existingCourse!.courseId}',
                  textAlign: TextAlign.center,
                  style: context.theme.typography.caption.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ),
            AppTextFormField(
              controller: _titleCtrl,
              label: '课程名称',
              validator: (v) => v == null || v.isEmpty ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),
            AppTextFormField(controller: _teacherCtrl, label: '教师'),
            const SizedBox(height: 12),
            AppTextFormField(controller: _placeCtrl, label: '地点'),
            const SizedBox(height: 12),
            AppTextFormField(controller: _campusCtrl, label: '校区'),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('course-weeks-field'),
              controller: _weeksCtrl,
              label: '周次',
              readOnly: true,
              onTap: _openWeekPicker,
              suffix: const Icon(FLucideIcons.chevronDown),
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('course-weekday-field'),
              controller: _weekdayCtrl,
              label: '星期',
              readOnly: true,
              onTap: _openWeekdayPicker,
              suffix: const Icon(FLucideIcons.chevronDown),
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('course-session-field'),
              controller: _sessionCtrl,
              label: '节次',
              readOnly: true,
              onTap: _openSessionPicker,
              suffix: const Icon(FLucideIcons.chevronDown),
            ),
            const SizedBox(height: 12),
            AppTextFormField(
              key: const ValueKey('course-color-field'),
              controller: _colorCtrl,
              label: '颜色 (HEX)',
              hint: '#FF8800',
              inputFormatters: const [_HexColorInputFormatter()],
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) return '请输入颜色值';
                if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
                  return '请输入 #RRGGBB 格式的颜色值';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _syncPickerText() {
    _weeksCtrl.text = _formatWeekSelection(_weeks);
    _weekdayCtrl.text = _weekdayLabels[_weekday - 1];
    _sessionCtrl.text = _formatSessionSelection();
  }

  String _formatSessionSelection() => _startSession == _endSession
      ? '第$_startSession节'
      : '第$_startSession-$_endSession节';

  Future<void> _openWeekPicker() async {
    final maxWeek = math.max(24, _weeks.last);
    final selected = await showAppSheet<List<int>>(
      context: context,
      maxHeightRatio: 0.82,
      builder: (_) =>
          CourseWeekPickerSheet(initialWeeks: _weeks, maxWeek: maxWeek),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _weeks = _sortedUnique(selected);
      _weeksCtrl.text = _formatWeekSelection(_weeks);
    });
  }

  Future<void> _openWeekdayPicker() async {
    final selected = await showAppSheet<List<int>>(
      context: context,
      builder: (_) => CourseWheelPickerSheet(
        title: '选择星期',
        columns: const [
          CoursePickerColumn(label: '星期', options: _weekdayLabels),
        ],
        initialIndexes: [_weekday - 1],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _weekday = selected.first + 1;
      _weekdayCtrl.text = _weekdayLabels[_weekday - 1];
    });
  }

  Future<void> _openSessionPicker() async {
    final options = [
      for (var session = 1; session <= 14; session++) '第$session节',
    ];
    final selected = await showAppSheet<List<int>>(
      context: context,
      builder: (_) => CourseWheelPickerSheet(
        title: '选择节次',
        columns: [
          CoursePickerColumn(label: '开始节次', options: options),
          CoursePickerColumn(label: '结束节次', options: options),
        ],
        initialIndexes: [_startSession - 1, _endSession - 1],
        isValid: (indexes) => indexes[0] <= indexes[1],
        invalidMessage: '开始节次不能大于结束节次',
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _startSession = selected[0] + 1;
      _endSession = selected[1] + 1;
      _sessionCtrl.text = _formatSessionSelection();
    });
  }

  String _formatWeekSelection(List<int> values) {
    final weeks = _sortedUnique(values);
    if (weeks.isEmpty) return '请选择';

    final start = weeks.first;
    final end = weeks.last;
    final range = start == end ? '第$start周' : '第$start-$end周';
    if (_hasStep(weeks, 1)) return range;
    if (_hasStep(weeks, 2) && weeks.every((week) => week.isOdd)) {
      return '$range（单周）';
    }
    if (_hasStep(weeks, 2) && weeks.every((week) => week.isEven)) {
      return '$range（双周）';
    }
    return '${formatWeekRanges(weeks)}周';
  }

  bool _hasStep(List<int> values, int step) {
    for (var index = 1; index < values.length; index++) {
      if (values[index] != values[index - 1] + step) return false;
    }
    return true;
  }

  List<int> _sortedUnique(Iterable<int> values) =>
      values.toSet().toList()..sort();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startSession > _endSession) {
      showAppSnackBar(context, '开始节次不能大于结束节次', severity: ToastSeverity.warning);
      return;
    }

    final sessions = List.generate(
      _endSession - _startSession + 1,
      (i) => _startSession + i,
    );
    if (_weeks.isEmpty) {
      showAppSnackBar(context, '请选择周次', severity: ToastSeverity.warning);
      return;
    }
    final hex = _colorCtrl.text.substring(1);
    final existing = widget.existingCourse;

    await widget.onSave(
      Course(
        title: _titleCtrl.text,
        teacher: _teacherCtrl.text,
        weekday: _weekday,
        sessions: sessions,
        weeks: _weeks,
        campus: _campusCtrl.text,
        place: _placeCtrl.text,
        colorIndex: Color(int.parse('FF$hex', radix: 16)).toARGB32(),
        courseId: existing?.courseId ?? '',
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _confirmDelete() {
    unawaited(_deleteAfterConfirmation());
  }

  Future<void> _deleteAfterConfirmation() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除课程',
      message: '确定要删除这门课程吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    await widget.onDelete!();
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _HexColorInputFormatter extends TextInputFormatter {
  const _HexColorInputFormatter();

  static final _pattern = RegExp(r'^#[0-9A-Fa-f]{0,6}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '#',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    if (!_pattern.hasMatch(newValue.text)) return oldValue;
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      composing: TextRange.empty,
    );
  }
}
