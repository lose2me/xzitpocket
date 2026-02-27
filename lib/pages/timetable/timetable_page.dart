import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
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
  bool _isPageAnimating = false;

  @override
  void initState() {
    super.initState();
    final initialWeek = currentWeek(semesterStartDate).clamp(1, semesterTotalWeeks);
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

  void _onWeekChanged(int week) {
    ref.read(selectedWeekProvider.notifier).state = week;
    final target = week - 1;
    if (_pageController.hasClients && _pageController.page?.round() != target) {
      _isPageAnimating = true;
      _pageController
          .animateToPage(target,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut)
          .then((_) => _isPageAnimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(scheduleProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          WeekHeader(
            semesterStart: semesterStartDate,
            selectedWeek: selectedWeek,
            totalWeeks: semesterTotalWeeks,
            onWeekChanged: _onWeekChanged,
          ),
          Expanded(
            child: coursesAsync.when(
              data: (courses) {
                if (courses.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('暂无课程', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('请在"我的"页面登录后同步课表',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return PageView.builder(
                  controller: _pageController,
                  itemCount: semesterTotalWeeks,
                  onPageChanged: (page) {
                    if (!_isPageAnimating) {
                      ref.read(selectedWeekProvider.notifier).state = page + 1;
                    }
                  },
                  itemBuilder: (context, index) {
                    final week = index + 1;
                    return TimetableGrid(
                      courses: courses,
                      week: week,
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
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('加载失败: $e',
                        style: const TextStyle(color: Colors.red)),
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
                _detailRow(Icons.location_on_outlined, '教室', course.place),
                _detailRow(Icons.domain_outlined, '校区', course.campus),
                _detailRow(Icons.access_time, '节次',
                    '第${course.startSession}-${course.endSession}节'),
                _detailRow(Icons.date_range, '周次',
                    _formatWeeks(course.weeks)),
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CourseFormPage(
        weekday: weekday,
        session: session,
        onSave: (course) {
          ref.read(scheduleProvider.notifier).addCourse(course);
        },
      ),
    ));
  }

  void _editCourse(BuildContext context, Course course, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CourseFormPage(
        weekday: course.weekday,
        session: course.startSession,
        existingCourse: course,
        onSave: (updated) {
          ref.read(scheduleProvider.notifier).updateCourse(index, updated);
        },
      ),
    ));
  }
}

class _CourseFormPage extends StatefulWidget {
  final int weekday;
  final int session;
  final Course? existingCourse;
  final ValueChanged<Course> onSave;

  const _CourseFormPage({
    required this.weekday,
    required this.session,
    this.existingCourse,
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
  final _weeksCtrl = TextEditingController(text: '1-16');
  late int _weekday;
  late int _startSession;
  late int _endSession;
  int _colorIndex = 0;

  static const _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _weekday = widget.weekday;
    final c = widget.existingCourse;
    if (c != null) {
      _titleCtrl.text = c.title;
      _teacherCtrl.text = c.teacher;
      _placeCtrl.text = c.place;
      _weeksCtrl.text = _formatWeeksForEdit(c.weeks);
      _startSession = c.startSession;
      _endSession = c.endSession;
      _colorIndex = c.colorIndex;
    } else {
      _startSession = widget.session;
      _endSession = (widget.session + 1).clamp(1, 14);
    }
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
    _weeksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑课程' : '添加课程'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                labelText: '教室',
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
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(
                labelText: '星期',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                  7,
                  (i) => DropdownMenuItem(
                      value: i + 1, child: Text(_weekdayLabels[i]))),
              onChanged: (v) => setState(() => _weekday = v ?? 1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _startSession,
                    decoration: const InputDecoration(
                      labelText: '开始节次',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                        14,
                        (i) => DropdownMenuItem(
                            value: i + 1, child: Text('第${i + 1}节'))),
                    onChanged: (v) => setState(() => _startSession = v ?? 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _endSession,
                    decoration: const InputDecoration(
                      labelText: '结束节次',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                        14,
                        (i) => DropdownMenuItem(
                            value: i + 1, child: Text('第${i + 1}节'))),
                    onChanged: (v) => setState(() => _endSession = v ?? 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('颜色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(Course.colors.length, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Course.colors[i],
                      borderRadius: BorderRadius.circular(8),
                      border: _colorIndex == i
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final sessions =
        List.generate(_endSession - _startSession + 1, (i) => _startSession + i);
    final weeks = _parseWeeks(_weeksCtrl.text);
    final existing = widget.existingCourse;

    widget.onSave(Course(
      title: _titleCtrl.text,
      teacher: _teacherCtrl.text,
      weekday: _weekday,
      sessions: sessions,
      weeks: weeks,
      campus: existing?.campus ?? '',
      place: _placeCtrl.text,
      colorIndex: _colorIndex,
    ));
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
