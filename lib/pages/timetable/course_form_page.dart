import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../models/course.dart';
import '../../utils/course_text_parser.dart';
import '../../utils/snackbar_helper.dart';
import '../../ui/app_components.dart';
import '../profile/profile_components.dart';
import 'course_picker_sheet.dart';

class CourseFormPage extends StatefulWidget {
  final int weekday;
  final int session;
  final Course? existingCourse;
  final Color? defaultColor;
  final int? defaultColorIndex;
  final Future<void> Function(Course) onSave;

  const CourseFormPage({
    super.key,
    required this.weekday,
    required this.session,
    this.existingCourse,
    this.defaultColor,
    this.defaultColorIndex,
    required this.onSave,
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
  final _weekdayCtrl = TextEditingController();
  final _sessionCtrl = TextEditingController();
  late List<int> _weeks;
  late int _weekday;
  late int _startSession;
  late int _endSession;
  Color? _defaultColor;
  int? _defaultColorIndex;
  Color? _selectedColor;
  Color? _lastCustomColor;

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
      final isAutomaticColor =
          c.colorIndex >= 0 && c.colorIndex < Course.colors.length;
      _defaultColor = isAutomaticColor ? c.color : widget.defaultColor;
      _defaultColorIndex = isAutomaticColor ? c.colorIndex : null;
      _selectedColor = isAutomaticColor ? null : c.color;
      if (!isAutomaticColor && !_isPresetColor(c.color)) {
        _lastCustomColor = c.color;
      }
    } else {
      _weeks = [for (var week = 1; week <= 20; week++) week];
      _weekday = widget.weekday.clamp(1, 7);
      _startSession = widget.session.clamp(1, 14);
      _endSession = (widget.session + 1).clamp(_startSession, 14);
      _defaultColor = widget.defaultColor;
      _defaultColorIndex = widget.defaultColorIndex;
    }
    _syncPickerText();
  }

  bool _isPresetColor(Color color) =>
      Course.colors.any((preset) => preset.toARGB32() == color.toARGB32());

  Future<void> _pickCustomColor() async {
    final color = await showProfileColorPicker(
      context: context,
      initialColor: _selectedColor ?? _defaultColor ?? Course.colors.first,
    );
    if (color == null || !mounted) return;
    setState(() {
      _selectedColor = color;
      _lastCustomColor = color;
    });
  }

  void _setColor(Color? color) {
    setState(() => _selectedColor = color);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teacherCtrl.dispose();
    _placeCtrl.dispose();
    _campusCtrl.dispose();
    _weeksCtrl.dispose();
    _weekdayCtrl.dispose();
    _sessionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: widget.isEditing ? '编辑课程' : '添加课程',
      footer: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppLayout.pageGutter(context),
            0,
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
                  variant: FButtonVariant.primary,
                  onPress: _save,
                  child: const Text('确定'),
                ),
              ),
            ),
          ),
        ),
      ),
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
            ProfileSettingsColorTile(
              icon: FLucideIcons.palette,
              title: '颜色',
              value: _selectedColor,
              colors: [
                for (final color in Course.colors)
                  if (_defaultColor == null ||
                      color.toARGB32() != _defaultColor!.toARGB32())
                    color,
              ],
              resetLabel: '默认',
              lastCustomColor: _lastCustomColor,
              onChanged: _setColor,
              onCustomColorPressed: _pickCustomColor,
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
    final existing = widget.existingCourse;
    final color = _selectedColor ?? _defaultColor ?? Course.colors.first;
    final colorIndex = _selectedColor == null && _defaultColorIndex != null
        ? _defaultColorIndex!
        : color.toARGB32();

    await widget.onSave(
      Course(
        title: _titleCtrl.text,
        teacher: _teacherCtrl.text,
        weekday: _weekday,
        sessions: sessions,
        weeks: _weeks,
        campus: _campusCtrl.text,
        place: _placeCtrl.text,
        colorIndex: colorIndex,
        courseId: existing?.courseId ?? '',
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }
}
