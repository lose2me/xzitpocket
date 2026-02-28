import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/week_calculator.dart';
import '../../widgets/week_header.dart';
import 'timetable_grid.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  late final PageController _pageController;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final initialWeek = currentWeek(
      semesterStartDate,
    ).clamp(1, semesterTotalWeeks);
    _pageController = PageController(initialPage: initialWeek - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialWeek > 0 && initialWeek <= semesterTotalWeeks) {
        ref.read(selectedWeekProvider.notifier).state = initialWeek;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final sid = storage.getStudentId();
      final pwd = storage.getSavedPassword();
      if (sid == null || pwd == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请先在"我的"页面登录')));
        }
        return;
      }

      final result = await ref.read(authProvider.notifier).login(sid, pwd);
      if (result != null) {
        await ref
            .read(scheduleProvider.notifier)
            .updateFromLoginResult(
              courses: result.courses,
              studentId: result.studentId ?? sid,
              studentName: result.studentName ?? '',
            );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('同步成功')));
        }
      } else {
        final authState = ref.read(authProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authState.errorMessage ?? '同步失败')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(scheduleProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courseBorderColor = isDark ? Colors.white : Colors.black;
    final courseOpacity = isDark ? 0.95 : 0.85;
    final courseBorderOpacity = isDark ? 1.0 : 0.85;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            WeekHeader(
              semesterStart: semesterStartDate,
              selectedWeek: selectedWeek,
              totalWeeks: semesterTotalWeeks,
              onSync: _isSyncing ? null : _onSync,
            ),
            Expanded(
              child: coursesAsync.when(
                data: (courses) {
                  if (courses.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('暂无课程', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 8),
                          Text(
                            '请在"我的"页面登录后同步课表',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }
                  return PageView.builder(
                    controller: _pageController,
                    physics: const _LessSensitivePagePhysics(),
                    itemCount: semesterTotalWeeks,
                    onPageChanged: (page) {
                      ref.read(selectedWeekProvider.notifier).state = page + 1;
                    },
                    itemBuilder: (context, index) {
                      final week = index + 1;
                      return TimetableGrid(
                        courses: courses,
                        week: week,
                        semesterStart: semesterStartDate,
                        borderColor: courseBorderColor,
                        borderWidth: 0.5,
                        courseOpacity: courseOpacity,
                        courseBorderOpacity: courseBorderOpacity,
                        onCourseTap: (course, idx) =>
                            _showCourseDetail(context, course, idx),
                        onEmptyTap: (weekday, session) =>
                            _onEmptySlotTap(context, weekday, session),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '加载失败: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseDetail(BuildContext context, Course course, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: course.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        course.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(Icons.person_outline, '教师', course.teacher),
                _detailRow(Icons.location_on_outlined, '地点', course.place),
                _detailRow(Icons.domain_outlined, '校区', course.campus),
                _detailRow(
                  Icons.access_time,
                  '节次',
                  '第${course.startSession}-${course.endSession}节',
                ),
                _detailRow(Icons.date_range, '周次', _formatWeeks(course.weeks)),
                _detailRow(Icons.tag, '编号', course.courseId),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(context, index);
                      },
                      child: const Text('删除'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editCourse(context, course, index);
                      },
                      child: const Text('编辑'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = [...weeks]..sort();
    final ranges = <String>[];
    int start = sorted[0];
    int end = sorted[0];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = sorted[i];
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    return '${ranges.join(',')}周';
  }

  void _confirmDelete(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: const Text('确定要删除这门课程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(scheduleProvider.notifier).deleteCourse(index);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onEmptySlotTap(BuildContext context, int weekday, int session) {
    final courses = ref.read(scheduleProvider).valueOrNull ?? [];
    final usedIndices = <int>{};
    for (final c in courses) {
      if (c.colorIndex >= 0 && c.colorIndex < Course.colors.length) {
        usedIndices.add(c.colorIndex);
      }
    }
    int nextIndex = 0;
    while (nextIndex < Course.colors.length &&
        usedIndices.contains(nextIndex)) {
      nextIndex++;
    }
    final defaultColor = Course.colors[nextIndex % Course.colors.length];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CourseFormPage(
          weekday: weekday,
          session: session,
          defaultColor: defaultColor,
          allCourses: courses,
          onSave: (course) {
            ref.read(scheduleProvider.notifier).addCourse(course);
          },
        ),
      ),
    );
  }

  void _editCourse(BuildContext context, Course course, int index) {
    final courses = ref.read(scheduleProvider).valueOrNull ?? [];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CourseFormPage(
          weekday: course.weekday,
          session: course.startSession,
          existingCourse: course,
          editIndex: index,
          allCourses: courses,
          onSave: (updated) {
            ref.read(scheduleProvider.notifier).updateCourse(index, updated);
            if (updated.courseId.isNotEmpty) {
              ref
                  .read(scheduleProvider.notifier)
                  .syncCourseFields(
                    updated.courseId,
                    index,
                    title: updated.title,
                    teacher: updated.teacher,
                    place: updated.place,
                    weeks: updated.weeks,
                  );
            }
          },
        ),
      ),
    );
  }
}

// ── Course Form Page (unchanged) ──

class _CourseFormPage extends StatefulWidget {
  final int weekday;
  final int session;
  final Course? existingCourse;
  final int? editIndex;
  final List<Course> allCourses;
  final Color? defaultColor;
  final ValueChanged<Course> onSave;

  const _CourseFormPage({
    required this.weekday,
    required this.session,
    this.existingCourse,
    this.editIndex,
    this.allCourses = const [],
    this.defaultColor,
    required this.onSave,
  });

  bool get isEditing => existingCourse != null;

  @override
  State<_CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<_CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _campusCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController(text: '1-16');
  final _colorCtrl = TextEditingController();
  final _weekdayCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  Color _currentColor = Course.colors[0];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCourse;
    if (c != null) {
      _titleCtrl.text = c.title;
      _teacherCtrl.text = c.teacher;
      _placeCtrl.text = c.place;
      _campusCtrl.text = c.campus;
      _weeksCtrl.text = _formatWeeksForEdit(c.weeks);
      _weekdayCtrl.text = c.weekday.toString();
      _startCtrl.text = c.startSession.toString();
      _endCtrl.text = c.endSession.toString();
      _currentColor = c.color;
    } else {
      _weekdayCtrl.text = widget.weekday.toString();
      _startCtrl.text = widget.session.toString();
      _endCtrl.text = (widget.session + 1).clamp(1, 14).toString();
      if (widget.defaultColor != null) {
        _currentColor = widget.defaultColor!;
      }
    }
    _colorCtrl.text = _colorToHex(_currentColor);
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).substring(2).toUpperCase();
  }

  String _formatWeeksForEdit(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = [...weeks]..sort();
    final ranges = <String>[];
    int start = sorted[0];
    int end = sorted[0];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        ranges.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = sorted[i];
      }
    }
    ranges.add(start == end ? '$start' : '$start-$end');
    return ranges.join(',');
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
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑课程' : '添加课程'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.existingCourse?.courseId.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '同步编号: ${widget.existingCourse!.courseId}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '课程名称',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _teacherCtrl,
              decoration: const InputDecoration(
                labelText: '教师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _placeCtrl,
              decoration: const InputDecoration(
                labelText: '地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _campusCtrl,
              decoration: const InputDecoration(
                labelText: '校区',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weeksCtrl,
              decoration: const InputDecoration(
                labelText: '周次 (例: 1-16)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weekdayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '星期 (1-7)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 7) return '请输入1-7';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '开始节次 (1-14)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 14) return '请输入1-14';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '结束节次 (1-14)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 14) return '请输入1-14';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _colorCtrl,
                    decoration: const InputDecoration(
                      labelText: '颜色 (HEX)',
                      hintText: 'FF8800',
                      prefixText: '#',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入颜色值';
                      final hex = v.replaceAll('#', '').trim();
                      if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                        return '请输入6位HEX颜色值';
                      }
                      return null;
                    },
                    onChanged: (v) {
                      final hex = v.replaceAll('#', '').trim();
                      if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                        setState(() {
                          _currentColor = Color(int.parse('FF$hex', radix: 16));
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openColorPicker,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ),
      ),
    );
  }

  void _openColorPicker() async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColorPickerSheet(initialColor: _currentColor),
    );
    if (picked != null) {
      setState(() {
        _currentColor = picked;
        _colorCtrl.text = _colorToHex(picked);
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final weekday = int.parse(_weekdayCtrl.text);
    final startSession = int.parse(_startCtrl.text);
    final endSession = int.parse(_endCtrl.text);
    final sessions = List.generate(
      endSession - startSession + 1,
      (i) => startSession + i,
    );
    final weeks = _parseWeeks(_weeksCtrl.text);
    final existing = widget.existingCourse;

    // 冲突检查
    final sessionsSet = sessions.toSet();
    final weeksSet = weeks.toSet();
    for (int i = 0; i < widget.allCourses.length; i++) {
      if (i == widget.editIndex) continue;
      final other = widget.allCourses[i];
      if (other.weekday != weekday) continue;
      final hasSessionOverlap = other.sessions.any(
        (s) => sessionsSet.contains(s),
      );
      if (!hasSessionOverlap) continue;
      final hasWeekOverlap = other.weeks.any((w) => weeksSet.contains(w));
      if (hasWeekOverlap) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('与「${other.title}」时间冲突')));
        return;
      }
    }

    widget.onSave(
      Course(
        title: _titleCtrl.text,
        teacher: _teacherCtrl.text,
        weekday: weekday,
        sessions: sessions,
        weeks: weeks,
        campus: _campusCtrl.text,
        place: _placeCtrl.text,
        colorIndex: _currentColor.toARGB32(),
        courseId: existing?.courseId ?? '',
      ),
    );
    Navigator.pop(context);
  }

  List<int> _parseWeeks(String text) {
    if (text.isEmpty) return List.generate(16, (i) => i + 1);
    final result = <int>[];
    for (final match in RegExp(r'(\d+)\s*-\s*(\d+)|(\d+)').allMatches(text)) {
      if (match.group(1) != null && match.group(2) != null) {
        final start = int.parse(match.group(1)!);
        final end = int.parse(match.group(2)!);
        for (int i = start; i <= end; i++) {
          result.add(i);
        }
      } else {
        result.add(int.parse(match.group(3)!));
      }
    }
    return result;
  }
}

class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerSheet({required this.initialColor});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 20),
            _buildSlider(
              label: '色相',
              value: _hsv.hue,
              max: 360,
              activeColor: color,
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _buildSlider(
              label: '饱和度',
              value: _hsv.saturation,
              max: 1,
              activeColor: color,
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _buildSlider(
              label: '亮度',
              value: _hsv.value,
              max: 1,
              activeColor: color,
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, color),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: max,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _LessSensitivePagePhysics extends PageScrollPhysics {
  const _LessSensitivePagePhysics({super.parent});

  @override
  _LessSensitivePagePhysics applyTo(ScrollPhysics? ancestor) {
    return _LessSensitivePagePhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 24.0;
}
