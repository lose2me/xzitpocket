import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/semester_config.dart';
import '../../models/course.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/credential_storage.dart';
import '../../services/tools_data_manager.dart';
import 'timetable_providers.dart';
import '../../services/widget_service.dart';
import '../../utils/course_text_parser.dart';
import '../../utils/snackbar_helper.dart';
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

class TimetablePageState extends ConsumerState<TimetablePage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _conflictCountdownController;
  bool _isSyncing = false;
  int _conflictRotationTick = 0;
  double _lastConflictCountdownValue = 0;
  bool _hasConflict = false;
  bool _isMutedConflict = false;

  @override
  void initState() {
    super.initState();
    final initialWeek = currentWeek(semesterStartDate)
        .clamp(1, _maxDisplayWeek());
    _pageController = PageController(initialPage: initialWeek - 1);
    _conflictCountdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _conflictCountdownController.addListener(() {
      final currentValue = _conflictCountdownController.value;
      if (currentValue < _lastConflictCountdownValue && mounted) {
        setState(() => _conflictRotationTick++);
      }
      _lastConflictCountdownValue = currentValue;
    });
    _conflictCountdownController.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (initialWeek > 0) {
        ref.read(selectedWeekProvider.notifier).set(initialWeek);
      }
    });
  }

  @override
  void dispose() {
    _conflictCountdownController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void jumpToCurrentWeek() {
    final maxWeek = _maxDisplayWeek();
    final week = currentWeek(semesterStartDate).clamp(1, maxWeek);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(week - 1);
    }
    ref.read(selectedWeekProvider.notifier).set(week);
  }

  void refreshForResume() {
    if (mounted) {
      setState(() {});
    }
  }

  int _maxDisplayWeek() {
    final courses = ref.read(scheduleProvider).value ?? [];
    int max = currentWeek(semesterStartDate).clamp(1, 52);
    for (final c in courses) {
      for (final w in c.weeks) {
        if (w > max) max = w;
      }
    }
    return max;
  }

  Future<void> _onSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final prefs = ref.read(preferencesStorageProvider);
      final sid = prefs.getStudentId();
      final pwd = await CredentialStorage.getSavedPassword();
      if (sid == null || pwd == null) {
        if (mounted) {
          showAppSnackBar(context, '请先在"我的"页面登录');
        }
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        if (mounted) {
          showAppSnackBar(context, '无网络连接，请检查网络后重试');
        }
        return;
      }

      final result = await ref.read(authProvider.notifier).login(sid, pwd);
      if (result != null) {
        final (loginResult, examResult) = result;
        try {
          await ref
              .read(scheduleProvider.notifier)
              .updateFromLoginResult(
                courses: loginResult.courses,
                studentId: loginResult.studentId ?? sid,
                studentName: loginResult.studentName ?? '',
              );
        } on WidgetSyncException catch (e) {
          if (mounted) {
            showAppSnackBar(context, '同步成功，但$e');
          }
          return;
        }
        await ToolsDataManager.instance.setExams(
          examResult,
          ref.read(preferencesStorageProvider),
        );
        if (mounted) {
          showAppSnackBar(context, '同步成功');
        }
      } else {
        final authState = ref.read(authProvider);
        if (mounted) {
          showAppSnackBar(context, authState.errorMessage ?? '同步失败');
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _buildEmptyView() {
    final isLoggedIn = ref.watch(configProvider).studentId != null;
    final semesterNotStarted = currentWeek(semesterStartDate) == 0;

    IconData icon;
    String title;
    String subtitle;
    if (!isLoggedIn) {
      icon = Icons.calendar_today_outlined;
      title = '暂无课程';
      subtitle = '请在"我的"页面登录后同步课表';
    } else if (semesterNotStarted) {
      icon = Icons.hourglass_empty;
      title = '未开学';
      subtitle = '教务系统可能还未发布本学期课表\n开学后下拉刷新或点击右上角重新同步';
    } else {
      icon = Icons.event_busy_outlined;
      title = '暂无课程';
      subtitle = '本学期暂无课程，可点击右上角重新同步';
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(scheduleProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final showNonCurrentWeekCourses = ref.watch(
      showNonCurrentWeekCoursesProvider,
    );
    final showWeekendColumns = ref.watch(showWeekendColumnsProvider);
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
              onSync: _isSyncing ? null : _onSync,
            ),
            Expanded(
              child: coursesAsync.when(
                data: (courses) {
                  if (courses.isEmpty) {
                    return _buildEmptyView();
                  }
                  return PageView.builder(
                    controller: _pageController,
                    physics: const _LessSensitivePagePhysics(),
                    itemCount: _maxDisplayWeek(),
                    onPageChanged: (page) {
                      ref.read(selectedWeekProvider.notifier).set(page + 1);
                    },
                    itemBuilder: (context, index) {
                      final week = index + 1;
                      final hide56 = !courses.any(
                        (c) => c.sessions.contains(5) || c.sessions.contains(6),
                      );
                      return TimetableGrid(
                        courses: courses,
                        week: week,
                        rotationTick: _conflictRotationTick,
                        showNonCurrentWeekCourses: showNonCurrentWeekCourses,
                        showWeekendColumns: showWeekendColumns,
                        semesterStart: semesterStartDate,
                        hiddenSlots: hide56 ? const {5, 6} : const {},
                        countdownAnimation: _conflictCountdownController,
                        borderColor: courseBorderColor,
                        borderWidth: 0.5,
                        courseOpacity: courseOpacity,
                        courseBorderOpacity: courseBorderOpacity,
                        onConflictComputed: (hasConflict, isMuted) {
                          if (_hasConflict != hasConflict ||
                              _isMutedConflict != isMuted) {
                            setState(() {
                              _hasConflict = hasConflict;
                              _isMutedConflict = isMuted;
                            });
                          }
                        },
                        onCourseTap: (course, idx) {
                          final key = ref
                              .read(scheduleProvider.notifier)
                              .keyAt(idx);
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
    unawaited(
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
                  _detailRow(
                    Icons.date_range,
                    '周次',
                    '${formatWeekRanges(course.weeks)}周',
                  ),
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
      ),
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

  void _confirmDelete(BuildContext context, int key) {
    unawaited(
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
              onPressed: () async {
                try {
                  await ref.read(scheduleProvider.notifier).deleteCourse(key);
                } on WidgetSyncException catch (e) {
                  if (mounted) {
                    showAppSnackBar(this.context, '课程已删除，但$e');
                  }
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _onEmptySlotTap(BuildContext context, int weekday, int session) {
    final courses = ref.read(scheduleProvider).value ?? [];
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
          onSave: (course) async {
            try {
              await ref.read(scheduleProvider.notifier).addCourse(course);
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(this.context, '课程已保存，但$e');
            }
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
            try {
              await ref
                  .read(scheduleProvider.notifier)
                  .updateCourse(key, updated);
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
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(this.context, '课程已保存，但$e');
            }
          },
          onDelete: () async {
            try {
              await ref.read(scheduleProvider.notifier).deleteCourse(key);
            } on WidgetSyncException catch (e) {
              if (!mounted) return;
              showAppSnackBar(this.context, '课程已删除，但$e');
            }
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
