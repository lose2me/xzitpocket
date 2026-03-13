import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/week_calculator.dart';
import '../../widgets/week_header.dart';
import 'course_form_page.dart';
import 'timetable_grid.dart';

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  static final globalKey = GlobalKey<TimetablePageState>();

  @override
  ConsumerState<TimetablePage> createState() => TimetablePageState();
}

class TimetablePageState extends ConsumerState<TimetablePage> {
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

  void jumpToCurrentWeek() {
    final week = currentWeek(semesterStartDate).clamp(1, semesterTotalWeeks);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(week - 1);
    }
    ref.read(selectedWeekProvider.notifier).state = week;
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

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无网络连接，请检查网络后重试')),
          );
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
                        onCourseTap: (course, idx) {
                            final key = ref.read(scheduleProvider.notifier).keyAt(idx);
                            _showCourseDetail(context, course, key);
                          },
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

  void _showCourseDetail(BuildContext context, Course course, int key) {
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
                        _confirmDelete(context, key);
                      },
                      child: const Text('删除'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editCourse(context, course, key);
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

  void _confirmDelete(BuildContext context, int key) {
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
              ref.read(scheduleProvider.notifier).deleteCourse(key);
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
        builder: (_) => CourseFormPage(
          weekday: weekday,
          session: session,
          defaultColor: defaultColor,
          onSave: (course) {
            ref.read(scheduleProvider.notifier).addCourse(course);
          },
        ),
      ),
    );
  }

  void _editCourse(BuildContext context, Course course, int key) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseFormPage(
          weekday: course.weekday,
          session: course.startSession,
          existingCourse: course,
          onSave: (updated) async {
            await ref.read(scheduleProvider.notifier).updateCourse(key, updated);
            if (updated.courseId.isNotEmpty) {
              await ref
                  .read(scheduleProvider.notifier)
                  .syncCourseFields(
                    updated.courseId,
                    excludeKey: key,
                    title: updated.title,
                    teacher: updated.teacher,
                  );
            }
          },
          onDelete: () {
            ref.read(scheduleProvider.notifier).deleteCourse(key);
          },
        ),
      ),
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
